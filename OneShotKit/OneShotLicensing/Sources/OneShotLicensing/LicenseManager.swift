import Foundation

/// Where the signed receipt is cached locally. The concrete store (a file in
/// Application Support, plus the Keychain mirror for the trial origin) lives in
/// the app layer; this protocol keeps the manager testable.
public protocol ReceiptStore: Sendable {
    func load() -> LicenseReceipt?
    func save(_ receipt: LicenseReceipt)
    /// Remove the cached receipt (deactivation, or a receipt that failed to verify).
    func clear()
}

/// In-memory `ReceiptStore` for tests / reference. `@unchecked Sendable`: the
/// single optional is lock-guarded.
public final class InMemoryReceiptStore: ReceiptStore, @unchecked Sendable {
    private let lock = NSLock()
    private var receipt: LicenseReceipt?

    public init(_ receipt: LicenseReceipt? = nil) {
        self.receipt = receipt
    }

    public func load() -> LicenseReceipt? {
        lock.lock(); defer { lock.unlock() }
        return receipt
    }

    public func save(_ receipt: LicenseReceipt) {
        lock.lock(); defer { lock.unlock() }
        self.receipt = receipt
    }

    public func clear() {
        lock.lock(); defer { lock.unlock() }
        receipt = nil
    }
}

/// Coordinates the licensing subsystem: activation/deactivation through the
/// (mock) server, offline receipt verification, local caching, and resolving the
/// current `LicenseState`. All time is injected via the `DateProviding` clock.
///
/// An `actor`: activation/deactivation/revalidation mutate the cached receipt
/// and must serialize. The app layer talks only to this type.
public actor LicenseManager {
    private let server: any LicenseServer
    private let verifier: ReceiptVerifier
    private let receiptStore: any ReceiptStore
    private let trialResolver: TrialOriginResolver
    private let evaluator = LicenseEvaluator()
    private let clock: any DateProviding
    private let machine: MachineIdentity

    public init(
        server: any LicenseServer,
        verifier: ReceiptVerifier,
        receiptStore: any ReceiptStore,
        trialResolver: TrialOriginResolver,
        clock: any DateProviding,
        machine: MachineIdentity
    ) {
        self.server = server
        self.verifier = verifier
        self.receiptStore = receiptStore
        self.trialResolver = trialResolver
        self.clock = clock
        self.machine = machine
    }

    /// Establish/restore the trial clock at startup (idempotent). Call once on
    /// first run-up; safe to call again. Returns the established start.
    @discardableResult
    public func startTrialIfNeeded() -> Date {
        trialResolver.establishStart(now: clock.now())
    }

    /// The current honest state. Verifies the cached receipt OFFLINE; a tampered
    /// or unverifiable receipt is treated as absent (spec: "Tampered receipt"),
    /// so this never throws.
    public func currentState() -> LicenseState {
        let verified = verifier.verifiedPayload(receiptStore.load())
        // A cached receipt that fails verification should not linger pretending
        // to be a license; drop it so the user is cleanly prompted to re-activate.
        if receiptStore.load() != nil, verified == nil {
            receiptStore.clear()
        }
        return evaluator.state(
            verifiedReceipt: verified,
            trialStart: trialResolver.resolvedStart(),
            now: clock.now()
        )
    }

    /// Activate a license key on this Mac. On success the signed receipt is
    /// verified and cached; on failure the caller's current state is unchanged
    /// (spec: "Invalid key ... current trial/license state is unchanged" — we
    /// never touch the store on the failure path).
    @discardableResult
    public func activate(licenseKey: String) async throws -> LicenseState {
        let receipt = try await server.activate(licenseKey: licenseKey, machine: machine, now: clock.now())
        // Defensive: only cache a receipt we can verify with our public key.
        _ = try verifier.verify(receipt)
        receiptStore.save(receipt)
        return currentState()
    }

    /// Self-serve deactivation: frees the seat server-side and removes the local
    /// receipt, returning the app to its trial/expired state (spec: "Self-serve
    /// deactivation").
    @discardableResult
    public func deactivate() async throws -> LicenseState {
        guard let payload = verifier.verifiedPayload(receiptStore.load()) else {
            // Nothing valid to deactivate; just ensure the store is clean.
            receiptStore.clear()
            return currentState()
        }
        try await server.deactivate(licenseKey: payload.licenseKey, machine: machine, now: clock.now())
        receiptStore.clear()
        return currentState()
    }

    /// Background revalidation. On success refreshes the receipt (resetting the
    /// 14-day offline-grace clock and clearing any lapse notice). On failure the
    /// cached receipt is left intact so the offline grace can run (spec: "Two
    /// weeks offline" / "Grace exceeded then restored"). Returns the resulting
    /// state. Network failure is reported by the server throwing; we swallow it
    /// and rely on the existing receipt.
    @discardableResult
    public func revalidate() async -> LicenseState {
        guard let payload = verifier.verifiedPayload(receiptStore.load()) else {
            return currentState()
        }
        if let fresh = try? await server.revalidate(
            licenseKey: payload.licenseKey,
            machine: machine,
            now: clock.now()
        ), (try? verifier.verify(fresh)) != nil {
            receiptStore.save(fresh)
        }
        // On failure: keep the old receipt; offline grace governs from
        // `lastValidatedAt`.
        return currentState()
    }

    /// The activations recorded for the active (or a given) key, for the
    /// seat-limit UI. Returns `[]` when there is no verified license.
    public func activations(forKey key: String? = nil) async -> [SeatActivation] {
        let resolvedKey = key ?? verifier.verifiedPayload(receiptStore.load())?.licenseKey
        guard let resolvedKey else { return [] }
        return await server.activations(forKey: resolvedKey)
    }
}
