import Foundation
import Testing
@testable import OneShotLicensing

// 14.1 — activation, invalid/revoked keys, 3-seat management, self-serve
// deactivation. Spec requirements: "Paddle license activation" and "Three-seat
// management with self-serve activate/deactivate".

struct ActivationTests {
    /// Spec scenario: Successful activation — valid key with a seat available
    /// becomes active, receipt cached, no further network needed for normal use.
    @Test func successfulActivation() async throws {
        let (signer, verifier) = Fixtures.keyPair()
        let server = Fixtures.server(signer: signer)
        let clock = FixedClock(Fixtures.day0)
        let store = InMemoryReceiptStore()
        let mgr = Fixtures.manager(server: server, verifier: verifier, clock: clock, receiptStore: store)

        let state = try await mgr.activate(licenseKey: Fixtures.validKey)
        #expect(state == .licensed)
        // Receipt cached locally; subsequent state reads need no network.
        #expect(store.load() != nil)
        #expect(await mgr.currentState() == .licensed)
    }

    /// Spec scenario: Invalid key — activation fails with a human-readable reason
    /// and current trial/license state is unchanged.
    @Test func test_invalidKey() async throws {
        let (signer, verifier) = Fixtures.keyPair()
        let server = Fixtures.server(signer: signer)
        let clock = FixedClock(Fixtures.day0)
        let store = InMemoryReceiptStore()
        let mgr = Fixtures.manager(server: server, verifier: verifier, clock: clock, receiptStore: store)
        await mgr.startTrialIfNeeded()

        await #expect {
            try await mgr.activate(licenseKey: "NOPE-NOT-REAL")
        } throws: { error in
            guard let activationError = error as? ActivationError else { return false }
            return activationError.code == .invalidKey && !activationError.reason.isEmpty
        }
        // State unchanged: still trial, no receipt written on the failure path.
        #expect(store.load() == nil)
        #expect(await mgr.currentState() == .trial(daysRemaining: 14))
    }

    @Test func revokedKeyFailsActivation() async throws {
        let (signer, verifier) = Fixtures.keyPair()
        let server = Fixtures.server(signer: signer)
        let mgr = Fixtures.manager(server: server, verifier: verifier, clock: FixedClock(Fixtures.day0))
        await #expect {
            try await mgr.activate(licenseKey: Fixtures.revokedKey)
        } throws: { error in
            (error as? ActivationError)?.code == .revokedKey
        }
    }

    /// Spec scenario: Activate within seat limit — a key with 1/3 used activated on
    /// a second Mac succeeds and the seat count becomes 2/3.
    @Test func activateWithinSeatLimit() async throws {
        let (signer, _) = Fixtures.keyPair()
        let server = Fixtures.server(signer: signer)
        _ = try await server.activate(licenseKey: Fixtures.validKey, machine: Fixtures.machineA, now: Fixtures.day0)
        // Second Mac:
        let receipt = try await server.activate(
            licenseKey: Fixtures.validKey,
            machine: Fixtures.machineB,
            now: Fixtures.day0
        )
        #expect(receipt.payload.seatsUsed == 2)
        #expect(receipt.payload.seatLimit == 3)
        let activations = await server.activations(forKey: Fixtures.validKey)
        #expect(activations.count == 2)
    }

    /// Spec scenario: Seat limit reached — a fourth Mac is refused with a message
    /// listing existing activations and how to free a seat (incl. inaccessible Mac).
    @Test func test_seatLimitReached() async throws {
        let (signer, _) = Fixtures.keyPair()
        let server = Fixtures.server(signer: signer)
        for machine in [Fixtures.machineA, Fixtures.machineB, Fixtures.machineC] {
            _ = try await server.activate(licenseKey: Fixtures.validKey, machine: machine, now: Fixtures.day0)
        }
        await #expect {
            _ = try await server.activate(licenseKey: Fixtures.validKey, machine: Fixtures.machineD, now: Fixtures.day0)
        } throws: { error in
            guard let activationError = error as? ActivationError else { return false }
            // Refused, and the existing activations are listed for the UI.
            return activationError.code == .seatLimitReached
                && activationError.existingActivations.count == 3
                && activationError.existingActivations.contains { $0.machine == Fixtures.machineA }
        }
    }

    /// Freeing a seat works for an inaccessible machine: deactivation is by machine
    /// id, so the seat can be released without that Mac being present.
    @Test func freeSeatForInaccessibleMachine() async throws {
        let (signer, _) = Fixtures.keyPair()
        let server = Fixtures.server(signer: signer)
        for machine in [Fixtures.machineA, Fixtures.machineB, Fixtures.machineC] {
            _ = try await server.activate(licenseKey: Fixtures.validKey, machine: machine, now: Fixtures.day0)
        }
        // Free machineB remotely (it is not present) then activate the new Mac.
        try await server.deactivate(licenseKey: Fixtures.validKey, machine: Fixtures.machineB, now: Fixtures.day0)
        let receipt = try await server.activate(
            licenseKey: Fixtures.validKey,
            machine: Fixtures.machineD,
            now: Fixtures.day0
        )
        #expect(receipt.payload.seatsUsed == 3)
        let ids = await server.activations(forKey: Fixtures.validKey).map(\.machine.id).sorted()
        #expect(ids == ["MAC-A", "MAC-C", "MAC-D"])
    }

    /// Re-activating the same Mac is idempotent — does not consume a second seat.
    @Test func reactivatingSameMachineIsIdempotent() async throws {
        let (signer, _) = Fixtures.keyPair()
        let server = Fixtures.server(signer: signer)
        _ = try await server.activate(licenseKey: Fixtures.validKey, machine: Fixtures.machineA, now: Fixtures.day0)
        let again = try await server.activate(
            licenseKey: Fixtures.validKey,
            machine: Fixtures.machineA,
            now: Fixtures.day0
        )
        #expect(again.payload.seatsUsed == 1)
    }

    /// Spec scenario: Self-serve deactivation — releases the seat server-side,
    /// removes the local receipt, returns to the appropriate trial/expired state.
    @Test func selfServeDeactivation() async throws {
        let (signer, verifier) = Fixtures.keyPair()
        let server = Fixtures.server(signer: signer)
        let clock = FixedClock(Fixtures.day0)
        let store = InMemoryReceiptStore()
        let mgr = Fixtures.manager(server: server, verifier: verifier, clock: clock, receiptStore: store)
        await mgr.startTrialIfNeeded()
        _ = try await mgr.activate(licenseKey: Fixtures.validKey)
        #expect(await server.activations(forKey: Fixtures.validKey).count == 1)

        let state = try await mgr.deactivate()
        // Seat released server-side, local receipt gone, back to trial.
        #expect(await server.activations(forKey: Fixtures.validKey).isEmpty)
        #expect(store.load() == nil)
        #expect(state == .trial(daysRemaining: 14))
    }

    /// The manager surfaces the recorded activations for the seat-limit UI.
    @Test func managerListsActivationsForActiveKey() async throws {
        let (signer, verifier) = Fixtures.keyPair()
        let server = Fixtures.server(signer: signer)
        _ = try await server.activate(licenseKey: Fixtures.validKey, machine: Fixtures.machineB, now: Fixtures.day0)
        let mgr = Fixtures.manager(server: server, verifier: verifier, clock: FixedClock(Fixtures.day0))
        _ = try await mgr.activate(licenseKey: Fixtures.validKey) // machineA
        let activations = await mgr.activations()
        #expect(Set(activations.map(\.machine.id)) == ["MAC-A", "MAC-B"])
    }
}
