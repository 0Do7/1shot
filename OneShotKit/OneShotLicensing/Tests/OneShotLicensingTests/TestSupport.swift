import CryptoKit
import Foundation
@testable import OneShotLicensing

/// Shared fixtures. We generate a fresh Ed25519 key pair in-test so signing and
/// verification are exercised end to end, and so the tamper test can prove a
/// modified receipt fails against the matching public key.
enum Fixtures {
    /// A deterministic origin instant for trial-clock arithmetic.
    static let day0 = Date(timeIntervalSince1970: 1_700_000_000) // fixed, arbitrary

    static func keyPair() -> (signer: ReceiptSigner, verifier: ReceiptVerifier) {
        let priv = Curve25519.Signing.PrivateKey()
        let signer = ReceiptSigner(privateKey: priv)
        let verifier = ReceiptVerifier(publicKey: priv.publicKey)
        return (signer, verifier)
    }

    static let machineA = MachineIdentity(id: "MAC-A", name: "Cody's MacBook Pro")
    static let machineB = MachineIdentity(id: "MAC-B", name: "Cody's iMac")
    static let machineC = MachineIdentity(id: "MAC-C", name: "Cody's Mac mini")
    static let machineD = MachineIdentity(id: "MAC-D", name: "Cody's MacBook Air")

    static let validKey = "OS-VALID-0001"
    static let revokedKey = "OS-REVOKED-0002"

    /// A mock server preloaded with one valid 3-seat key and one revoked key.
    static func server(signer: ReceiptSigner) -> MockLicenseServer {
        MockLicenseServer(
            signer: signer,
            keys: [
                .init(value: validKey, seatLimit: 3),
                .init(value: revokedKey, seatLimit: 3, isRevoked: true),
            ]
        )
    }

    /// A `LicenseManager` wired with in-memory stores and a fixed clock.
    static func manager(
        server: any LicenseServer,
        verifier: ReceiptVerifier,
        clock: FixedClock,
        machine: MachineIdentity = machineA,
        receiptStore: InMemoryReceiptStore = InMemoryReceiptStore(),
        trialStores: [any TrialOriginStore] = [InMemoryTrialOriginStore()],
        clockGuardStores: [any TrialOriginStore] = [InMemoryTrialOriginStore()]
    ) -> LicenseManager {
        LicenseManager(
            server: server,
            verifier: verifier,
            receiptStore: receiptStore,
            trialResolver: TrialOriginResolver(stores: trialStores),
            clockGuard: TrialClockGuard(stores: clockGuardStores),
            clock: clock,
            machine: machine
        )
    }
}

/// A transport (network) outage we can match against in `catch`. Distinct from
/// `ActivationError`, so the manager's soft-failure branch handles it.
struct SimulatedNetworkError: Error {}

/// Wraps a base server but simulates a connectivity outage on `revalidate()`:
/// it throws a non-`ActivationError`, exercising the manager's soft-failure
/// path (keep the receipt for offline grace) rather than an authoritative
/// negative (clear the receipt).
struct OfflineFailingServer: LicenseServer {
    let base: any LicenseServer

    func activate(licenseKey: String, machine: MachineIdentity, now: Date) async throws -> LicenseReceipt {
        try await base.activate(licenseKey: licenseKey, machine: machine, now: now)
    }

    func deactivate(licenseKey: String, machine: MachineIdentity, now: Date) async throws {
        try await base.deactivate(licenseKey: licenseKey, machine: machine, now: now)
    }

    func revalidate(licenseKey: String, machine: MachineIdentity, now: Date) async throws -> LicenseReceipt {
        throw SimulatedNetworkError()
    }

    func activations(forKey licenseKey: String) async -> [SeatActivation] {
        await base.activations(forKey: licenseKey)
    }
}
