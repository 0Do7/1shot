import Foundation

/// The in-process boundary that stands in for Paddle (design D10). Activation,
/// deactivation, and revalidation go through this protocol; seat counting is the
/// SERVER's responsibility (spec: "seat counting performed server-side"). The
/// MOCK implementation below is used for all tests — there is NO real network
/// and NO real Paddle here (real Paddle is task 14.3, out of scope).
///
/// Implementations are `Sendable`; methods are `async` so the real one can be a
/// REST client without changing callers (spec: "All licensing functionality
/// SHALL be testable against a mock server").
public protocol LicenseServer: Sendable {
    /// Claim a seat for `machine` under `licenseKey`. On success returns a
    /// signed receipt. Re-activating the same machine is idempotent (re-issues a
    /// receipt without consuming an extra seat).
    func activate(licenseKey: String, machine: MachineIdentity, now: Date) async throws -> LicenseReceipt

    /// Release the seat held by `machine` (spec: "self-serve deactivation ...
    /// frees the seat immediately"). Server-side seat release is the source of
    /// truth; the local receipt removal is the caller's job.
    func deactivate(licenseKey: String, machine: MachineIdentity, now: Date) async throws

    /// Re-issue a receipt for an already-activated machine (background
    /// revalidation). Refreshes `lastValidatedAt`; does not consume a seat.
    func revalidate(licenseKey: String, machine: MachineIdentity, now: Date) async throws -> LicenseReceipt

    /// The activations currently recorded for a key (drives the seat-limit UI).
    func activations(forKey licenseKey: String) async -> [SeatActivation]
}

/// One recorded seat occupancy, surfaced to the seat-limit UI.
public struct SeatActivation: Codable, Hashable, Sendable {
    public var machine: MachineIdentity
    public var activatedAt: Date

    public init(machine: MachineIdentity, activatedAt: Date) {
        self.machine = machine
        self.activatedAt = activatedAt
    }
}

/// Typed activation failures (spec: "activation fails with a human-readable
/// reason"). `existingActivations` is populated for `.seatLimitReached` so the
/// UI can list which Macs hold seats and how to free one — including for an
/// inaccessible machine (the deactivate path works by machine id, not presence).
public struct ActivationError: Error, Equatable, Sendable {
    public enum Code: String, Sendable {
        case invalidKey
        case revokedKey
        case seatLimitReached
        case notActivated
    }

    public var code: Code
    public var reason: String
    public var existingActivations: [SeatActivation]

    public init(code: Code, reason: String, existingActivations: [SeatActivation] = []) {
        self.code = code
        self.reason = reason
        self.existingActivations = existingActivations
    }

    /// An authoritative "this license/seat is no longer valid for this Mac"
    /// response (as opposed to a transport failure). When revalidation returns
    /// one of these, the cached receipt must be dropped rather than coasting on
    /// offline grace: the key was revoked (refund/chargeback) or the seat was
    /// freed/reassigned on another machine.
    public var isAuthoritativeRevocation: Bool {
        switch code {
        case .revokedKey, .notActivated:
            true
        case .invalidKey, .seatLimitReached:
            false
        }
    }
}

// MARK: - Mock server

/// In-process mock of the license server. Holds a fixed catalog of known keys
/// and enforces the 3-seat rule entirely server-side. Signs receipts with a
/// supplied `ReceiptSigner` so tests verify against the matching public key.
///
/// An `actor` so concurrent activate/deactivate calls serialize safely.
public actor MockLicenseServer: LicenseServer {
    /// A key the mock recognizes.
    public struct Key: Sendable {
        public var value: String
        public var seatLimit: Int
        public var isRevoked: Bool

        public init(value: String, seatLimit: Int = 3, isRevoked: Bool = false) {
            self.value = value
            self.seatLimit = seatLimit
            self.isRevoked = isRevoked
        }
    }

    private let signer: ReceiptSigner
    private var keys: [String: Key]
    /// licenseKey -> machineID -> activation
    private var seats: [String: [String: SeatActivation]] = [:]

    public init(signer: ReceiptSigner, keys: [Key]) {
        self.signer = signer
        self.keys = Dictionary(uniqueKeysWithValues: keys.map { ($0.value, $0) })
    }

    public func activations(forKey licenseKey: String) -> [SeatActivation] {
        (seats[licenseKey]?.values).map { Array($0).sorted { $0.activatedAt < $1.activatedAt } } ?? []
    }

    /// Revoke a known key server-side (simulates a refund/chargeback after the
    /// app already activated). Subsequent activate/revalidate calls then throw
    /// `.revokedKey`. No-op for an unknown key.
    public func revoke(_ licenseKey: String) {
        keys[licenseKey]?.isRevoked = true
    }

    public func activate(licenseKey: String, machine: MachineIdentity, now: Date) async throws -> LicenseReceipt {
        let key = try requireUsableKey(licenseKey)
        var keySeats = seats[licenseKey] ?? [:]

        // Idempotent re-activation: same machine already holds a seat.
        if keySeats[machine.id] == nil {
            guard keySeats.count < key.seatLimit else {
                throw ActivationError(
                    code: .seatLimitReached,
                    reason: "All \(key.seatLimit) seats for this license are in use.",
                    existingActivations: sortedActivations(keySeats)
                )
            }
            keySeats[machine.id] = SeatActivation(machine: machine, activatedAt: now)
            seats[licenseKey] = keySeats
        }

        return try issueReceipt(key: key, machine: machine, now: now)
    }

    public func deactivate(licenseKey: String, machine: MachineIdentity, now: Date) async throws {
        // Deactivation tolerates an unknown/already-freed seat (no-op) so the
        // self-serve path is safe to invoke repeatedly.
        guard keys[licenseKey] != nil else {
            throw ActivationError(code: .invalidKey, reason: "Unrecognized license key.")
        }
        seats[licenseKey]?[machine.id] = nil
    }

    public func revalidate(licenseKey: String, machine: MachineIdentity, now: Date) async throws -> LicenseReceipt {
        let key = try requireUsableKey(licenseKey)
        guard seats[licenseKey]?[machine.id] != nil else {
            throw ActivationError(
                code: .notActivated,
                reason: "This Mac is not activated for the license.",
                existingActivations: sortedActivations(seats[licenseKey] ?? [:])
            )
        }
        return try issueReceipt(key: key, machine: machine, now: now)
    }

    // MARK: Helpers

    private func requireUsableKey(_ licenseKey: String) throws -> Key {
        guard let key = keys[licenseKey] else {
            throw ActivationError(code: .invalidKey, reason: "Unrecognized license key.")
        }
        guard !key.isRevoked else {
            throw ActivationError(code: .revokedKey, reason: "This license key has been revoked.")
        }
        return key
    }

    private func issueReceipt(key: Key, machine: MachineIdentity, now: Date) throws -> LicenseReceipt {
        let keySeats = seats[key.value] ?? [:]
        let trialStart = keySeats[machine.id]?.activatedAt ?? now
        let payload = LicenseReceipt.Payload(
            licenseKey: key.value,
            machine: machine,
            trialStartedAt: trialStart,
            lastValidatedAt: now,
            seatsUsed: keySeats.count,
            seatLimit: key.seatLimit
        )
        return try signer.sign(payload)
    }

    private func sortedActivations(_ seats: [String: SeatActivation]) -> [SeatActivation] {
        Array(seats.values).sorted { $0.activatedAt < $1.activatedAt }
    }
}
