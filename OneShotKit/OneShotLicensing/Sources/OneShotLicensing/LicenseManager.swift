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
    private let clockGuard: TrialClockGuard
    private let evaluator = LicenseEvaluator()
    private let clock: any DateProviding
    private let machine: MachineIdentity

    public init(
        server: any LicenseServer,
        verifier: ReceiptVerifier,
        receiptStore: any ReceiptStore,
        trialResolver: TrialOriginResolver,
        clockGuard: TrialClockGuard,
        clock: any DateProviding,
        machine: MachineIdentity
    ) {
        self.server = server
        self.verifier = verifier
        self.receiptStore = receiptStore
        self.trialResolver = trialResolver
        self.clockGuard = clockGuard
        self.clock = clock
        self.machine = machine
    }

    /// Establish/restore the trial clock at startup (idempotent). Call once on
    /// first run-up; safe to call again. Returns the established start. Also
    /// seeds the clock-rollback high-water-mark.
    @discardableResult
    public func startTrialIfNeeded() -> Date {
        clockGuard.observe(now: clock.now())
        return trialResolver.establishStart(now: clock.now())
    }

    /// The current honest state. Verifies the cached receipt OFFLINE; a tampered,
    /// unverifiable, or another-Mac's receipt is treated as absent (spec:
    /// "Tampered receipt"), so this never throws.
    public func currentState() -> LicenseState {
        let verified = boundPayload(receiptStore.load())
        // A cached receipt that fails verification (or is bound to a different
        // Mac) should not linger pretending to be a license; drop it so the user
        // is cleanly prompted to re-activate.
        if receiptStore.load() != nil, verified == nil {
            receiptStore.clear()
        }
        let now = clock.now()
        // Advance (never lower) the clock high-water-mark, then evaluate the
        // trial against the rollback-protected instant so winding the system
        // clock backward cannot re-grant an expired trial.
        let trialNow = clockGuard.observe(now: now)
        return evaluator.state(
            verifiedReceipt: verified,
            trialStart: trialResolver.resolvedStart(),
            now: now,
            trialNow: trialNow
        )
    }

    /// Verify a cached receipt's signature AND its seat binding. A signature-valid
    /// receipt issued for a DIFFERENT Mac resolves to `nil` (treated as absent),
    /// because the bundled public key is identical in every copy of the app, so a
    /// receipt copied to another machine would otherwise verify and silently
    /// license unlimited Macs — bypassing the server-side seat cap. The machine
    /// binding in the signed payload is the only thing that ties a receipt to one
    /// Mac, so we enforce it here.
    private func boundPayload(_ receipt: LicenseReceipt?) -> LicenseReceipt.Payload? {
        guard let payload = verifier.verifiedPayload(receipt) else { return nil }
        guard payload.machine.id == machine.id else { return nil }
        return payload
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
        guard let payload = boundPayload(receiptStore.load()) else {
            // Nothing valid to deactivate; just ensure the store is clean.
            receiptStore.clear()
            return currentState()
        }
        try await server.deactivate(licenseKey: payload.licenseKey, machine: machine, now: clock.now())
        receiptStore.clear()
        return currentState()
    }

    /// Background revalidation. On success refreshes the receipt (resetting the
    /// 14-day offline-grace clock and clearing any lapse notice). Returns the
    /// resulting state.
    ///
    /// Failure handling distinguishes two cases:
    ///   * Authoritative negative — the server is reachable and reports that the
    ///     license is no longer valid for this Mac (`.revokedKey` after a
    ///     refund/chargeback, or `.notActivated` after the seat was freed/given
    ///     away). We must NOT keep granting offline grace on a license the server
    ///     just told us is dead, so the cached receipt is cleared and the app
    ///     drops to its trial/expired state immediately.
    ///   * Soft/transport failure — network outage, timeout, or any other error.
    ///     The cached receipt is left intact so the 14-day offline grace can run
    ///     from `lastValidatedAt` (spec: "Two weeks offline" / "Grace exceeded
    ///     then restored").
    @discardableResult
    public func revalidate() async -> LicenseState {
        guard let payload = boundPayload(receiptStore.load()) else {
            return currentState()
        }
        do {
            let fresh = try await server.revalidate(
                licenseKey: payload.licenseKey,
                machine: machine,
                now: clock.now()
            )
            if (try? verifier.verify(fresh)) != nil {
                receiptStore.save(fresh)
            }
        } catch let error as ActivationError where error.isAuthoritativeRevocation {
            // The server has spoken: this license/seat is no longer ours.
            receiptStore.clear()
        } catch {
            // Soft failure (network/timeout): keep the old receipt; offline grace
            // governs from `lastValidatedAt`.
        }
        return currentState()
    }

    /// The activations recorded for the active (or a given) key, for the
    /// seat-limit UI. Returns `[]` when there is no verified license.
    public func activations(forKey key: String? = nil) async -> [SeatActivation] {
        let resolvedKey = key ?? boundPayload(receiptStore.load())?.licenseKey
        guard let resolvedKey else { return [] }
        return await server.activations(forKey: resolvedKey)
    }
}
