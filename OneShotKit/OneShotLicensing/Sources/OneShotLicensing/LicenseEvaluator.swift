import Foundation

/// The pure decision function for the whole subsystem. Given the inputs that
/// already exist at a moment in time, it returns the one honest `LicenseState`.
/// It performs NO I/O, NO signature checks, NO `Date()` — callers pass `now`
/// explicitly (design D10) and a *already-verified* receipt payload (the
/// `LicenseManager` does verification first; a tampered receipt arrives here as
/// `nil`, i.e. unlicensed). Keeping this pure is what makes every trial/grace
/// boundary deterministically testable.
public struct LicenseEvaluator: Sendable {
    public init() {}

    /// - Parameters:
    ///   - verifiedReceipt: a receipt whose signature already verified, or `nil`
    ///     (no receipt, or one that failed verification — treated as absent).
    ///   - trialStart: the established trial start (see `TrialOriginResolver`),
    ///     or `nil` if the trial has not begun.
    ///   - now: injected current instant.
    public func state(
        verifiedReceipt: LicenseReceipt.Payload?,
        trialStart: Date?,
        now: Date
    ) -> LicenseState {
        // A valid license dominates the trial entirely.
        if let receipt = verifiedReceipt {
            let offlineFor = now.timeIntervalSince(receipt.lastValidatedAt)
            if offlineFor > LicensingDuration.offlineGrace {
                return .licensedOfflineGraceExceeded
            }
            return .licensed
        }

        // No license → derive from the trial clock.
        guard let trialStart else {
            // Defensive: an unstarted trial is treated as a fresh full trial.
            return .trial(daysRemaining: trialDays())
        }

        let elapsed = now.timeIntervalSince(trialStart)

        if elapsed < LicensingDuration.trial {
            let remaining = LicensingDuration.trial - elapsed
            return .trial(daysRemaining: ceilDays(remaining))
        }

        let pastTrial = elapsed - LicensingDuration.trial
        if pastTrial < LicensingDuration.captureGrace {
            let remaining = LicensingDuration.captureGrace - pastTrial
            return .trialGrace(hoursRemaining: ceilHours(remaining))
        }

        return .expired
    }

    // MARK: Rounding — display values round UP so "1 day left" never reads 0

    // while time genuinely remains.

    private func trialDays() -> Int {
        Int((LicensingDuration.trial / LicensingDuration.day).rounded())
    }

    private func ceilDays(_ interval: TimeInterval) -> Int {
        max(0, Int((interval / LicensingDuration.day).rounded(.up)))
    }

    private func ceilHours(_ interval: TimeInterval) -> Int {
        max(0, Int((interval / 3600).rounded(.up)))
    }
}
