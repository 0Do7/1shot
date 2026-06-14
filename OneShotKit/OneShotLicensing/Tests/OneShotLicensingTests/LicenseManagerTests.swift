import Foundation
import Testing
@testable import OneShotLicensing

// 14.1 — manager-level integration of receipt verification with state. Spec
// scenario: "Tampered receipt ... behaves as unlicensed ... prompted to
// re-activate rather than shown an error crash".

struct LicenseManagerTests {
    /// Spec scenario: Tampered receipt (manager behavior). A modified cached
    /// receipt verifies as absent, so currentState() falls back to trial/expired
    /// WITHOUT throwing, and the bad receipt is dropped (clean re-activate path).
    @Test func tamperedReceiptBehavesAsUnlicensed() async throws {
        let (signer, verifier) = Fixtures.keyPair()
        let server = Fixtures.server(signer: signer)
        let clock = FixedClock(Fixtures.day0)
        let store = InMemoryReceiptStore()
        let mgr = Fixtures.manager(server: server, verifier: verifier, clock: clock, receiptStore: store)
        await mgr.startTrialIfNeeded()

        // Activate, then tamper with the on-disk receipt.
        _ = try await mgr.activate(licenseKey: Fixtures.validKey)
        var bad = try #require(store.load())
        bad.payload.seatLimit = 99 // invalidates the signature
        store.save(bad)

        // No crash; behaves as unlicensed (back to trial) and clears the bad receipt.
        let state = await mgr.currentState()
        #expect(state == .trial(daysRemaining: 14))
        #expect(store.load() == nil) // dropped → user is cleanly prompted to re-activate
    }

    /// A SOFT (transport/network) revalidation failure keeps the cached receipt so
    /// the 14-day offline grace can run. We simulate a connectivity outage with a
    /// server that throws a non-authoritative error on revalidate().
    @Test func softRevalidationFailureKeepsExistingReceipt() async throws {
        let (signer, verifier) = Fixtures.keyPair()
        let realServer = Fixtures.server(signer: signer)
        let clock = FixedClock(Fixtures.day0)
        let store = InMemoryReceiptStore()
        // Activate against the real mock first, then swap in an offline server that
        // only fails (with a transport error) on revalidate().
        let activateMgr = Fixtures.manager(server: realServer, verifier: verifier, clock: clock, receiptStore: store)
        _ = try await activateMgr.activate(licenseKey: Fixtures.validKey)

        let offlineServer = OfflineFailingServer(base: realServer)
        let mgr = Fixtures.manager(server: offlineServer, verifier: verifier, clock: clock, receiptStore: store)
        clock.advance(by: 5 * LicensingDuration.day)
        let state = await mgr.revalidate()
        #expect(state == .licensed) // within offline grace
        #expect(store.load() != nil) // receipt retained despite the network failure
    }

    /// An AUTHORITATIVE negative (server reachable, seat freed elsewhere →
    /// `.notActivated`) must NOT coast on offline grace: the cached receipt is
    /// dropped and the app returns to its trial/expired state immediately.
    @Test func authoritativeRevocationClearsReceipt() async throws {
        let (signer, verifier) = Fixtures.keyPair()
        let server = Fixtures.server(signer: signer)
        let clock = FixedClock(Fixtures.day0)
        let store = InMemoryReceiptStore()
        let mgr = Fixtures.manager(server: server, verifier: verifier, clock: clock, receiptStore: store)
        await mgr.startTrialIfNeeded()
        _ = try await mgr.activate(licenseKey: Fixtures.validKey)

        // The seat is freed on another Mac → revalidate() gets `.notActivated`.
        try await server.deactivate(licenseKey: Fixtures.validKey, machine: Fixtures.machineA, now: clock.now())
        let state = await mgr.revalidate()
        #expect(state == .trial(daysRemaining: 14)) // dropped to trial, not still licensed
        #expect(store.load() == nil) // receipt cleared on the authoritative negative
    }

    /// A revoked key (refund/chargeback) discovered at revalidation is likewise
    /// authoritative: the cached receipt is dropped immediately.
    @Test func revokedKeyAtRevalidationClearsReceipt() async throws {
        let (signer, verifier) = Fixtures.keyPair()
        let server = MockLicenseServer(signer: signer, keys: [.init(value: Fixtures.validKey, seatLimit: 3)])
        let clock = FixedClock(Fixtures.day0)
        let store = InMemoryReceiptStore()
        let mgr = Fixtures.manager(server: server, verifier: verifier, clock: clock, receiptStore: store)
        await mgr.startTrialIfNeeded()
        _ = try await mgr.activate(licenseKey: Fixtures.validKey)

        await server.revoke(Fixtures.validKey)
        let state = await mgr.revalidate()
        #expect(state == .trial(daysRemaining: 14))
        #expect(store.load() == nil)
    }

    /// Seat-binding enforcement: a signature-VALID receipt issued for another Mac
    /// must NOT license this Mac. (Concrete attack: activate on Mac A, copy the
    /// receipt file to Mac B. The bundled public key is identical, so the
    /// signature still verifies — but the payload.machine is Mac A, so this Mac
    /// must treat it as absent and the cloned activation cannot bypass the
    /// server-side seat cap.)
    @Test func receiptBoundToAnotherMachineIsUnlicensed() async throws {
        let (signer, verifier) = Fixtures.keyPair()
        let server = Fixtures.server(signer: signer)
        let clock = FixedClock(Fixtures.day0)

        // Mac A activates legitimately and produces a real signed receipt.
        let storeA = InMemoryReceiptStore()
        let mgrA = Fixtures.manager(
            server: server, verifier: verifier, clock: clock,
            machine: Fixtures.machineA, receiptStore: storeA
        )
        await mgrA.startTrialIfNeeded()
        _ = try await mgrA.activate(licenseKey: Fixtures.validKey)
        let aReceipt = try #require(storeA.load())

        // The receipt is COPIED verbatim onto Mac B's store (its signature is
        // intact — same key in every app copy).
        let storeB = InMemoryReceiptStore(aReceipt)
        #expect(verifier.verifiedPayload(aReceipt) != nil) // signature genuinely valid
        let mgrB = Fixtures.manager(
            server: server, verifier: verifier, clock: clock,
            machine: Fixtures.machineB, receiptStore: storeB
        )
        await mgrB.startTrialIfNeeded()

        // Mac B must NOT be licensed by Mac A's receipt; the bad copy is dropped.
        #expect(await mgrB.currentState() == .trial(daysRemaining: 14))
        #expect(storeB.load() == nil)
        // Server seat count is untouched: only Mac A holds a seat.
        let ids = await server.activations(forKey: Fixtures.validKey).map(\.machine.id)
        #expect(ids == ["MAC-A"])
    }

    /// A machine-mismatched receipt persisting past the offline grace likewise
    /// resolves to unlicensed — the clone never reaches `.licensedOfflineGraceExceeded`
    /// (whose capture would otherwise stay enabled).
    @Test func clonedReceiptDoesNotSurviveOfflineGrace() async throws {
        let (signer, verifier) = Fixtures.keyPair()
        let server = Fixtures.server(signer: signer)
        let clock = FixedClock(Fixtures.day0)
        let storeA = InMemoryReceiptStore()
        let mgrA = Fixtures.manager(
            server: server, verifier: verifier, clock: clock,
            machine: Fixtures.machineA, receiptStore: storeA
        )
        _ = try await mgrA.activate(licenseKey: Fixtures.validKey)
        let aReceipt = try #require(storeA.load())
        let storeB = InMemoryReceiptStore(aReceipt)
        let mgrB = Fixtures.manager(
            server: server, verifier: verifier, clock: clock,
            machine: Fixtures.machineB, receiptStore: storeB
        )
        await mgrB.startTrialIfNeeded()
        clock.advance(by: 30 * LicensingDuration.day) // well past 14-day grace
        let state = await mgrB.currentState()
        #expect(!state.isLicensed)
        #expect(state == .expired) // trial also long gone → capture disabled
    }

    /// Deactivating when nothing valid is cached is a safe no-op returning the
    /// trial/expired state.
    @Test func deactivateWithNoLicenseIsSafe() async throws {
        let (signer, verifier) = Fixtures.keyPair()
        let server = Fixtures.server(signer: signer)
        let mgr = Fixtures.manager(server: server, verifier: verifier, clock: FixedClock(Fixtures.day0))
        await mgr.startTrialIfNeeded()
        let state = try await mgr.deactivate()
        #expect(state == .trial(daysRemaining: 14))
    }
}
