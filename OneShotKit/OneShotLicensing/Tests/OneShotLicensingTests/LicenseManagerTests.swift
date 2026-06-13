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

    /// A licensed app that goes far offline then revalidation keeps failing stays
    /// usable (offline grace), and recovers once revalidation succeeds.
    @Test func revalidationFailureKeepsExistingReceipt() async throws {
        let (signer, verifier) = Fixtures.keyPair()
        let server = Fixtures.server(signer: signer)
        let clock = FixedClock(Fixtures.day0)
        let store = InMemoryReceiptStore()
        let mgr = Fixtures.manager(server: server, verifier: verifier, clock: clock, receiptStore: store)
        _ = try await mgr.activate(licenseKey: Fixtures.validKey)

        // Deactivate server-side so revalidate() will fail (not activated), but the
        // local receipt must remain for the offline grace.
        try await server.deactivate(licenseKey: Fixtures.validKey, machine: Fixtures.machineA, now: clock.now())
        clock.advance(by: 5 * LicensingDuration.day)
        let state = await mgr.revalidate()
        #expect(state == .licensed) // within offline grace
        #expect(store.load() != nil) // receipt retained despite failed revalidation
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
