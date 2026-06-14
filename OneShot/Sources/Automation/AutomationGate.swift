import Foundation
import OneShotLicensing

/// Per-action confirmation posture for the URL scheme (spec:automation: "the user
/// SHALL be able to choose between always-confirm and silent operation per
/// enabled scheme action"). AppIntents do not use this — Shortcuts/Spotlight are
/// already user-initiated, so the confirmation contract is scoped to the URL API,
/// which any app on the Mac can trigger.
enum ConfirmationMode: String, Codable, CaseIterable {
    /// Ask the user to approve before performing a side-effecting action.
    case alwaysConfirm
    /// Perform side-effecting actions without a prompt.
    case silent
}

/// The decision a gate makes for a request, before any engine is touched.
enum GateDecision: Equatable {
    /// Proceed to dispatch the action.
    case proceed
    /// Ask the user first (URL scheme + always-confirm + a side-effecting action).
    case confirm
    /// Refuse with this typed error (disabled scheme, missing license, …). The
    /// caller surfaces it as an honest failure / x-error callback.
    case reject(AutomationError)
}

/// The two entry points share the same action catalog but DIFFERENT gating: an
/// AppIntent is always an explicit user gesture (Shortcuts/Spotlight), whereas a
/// URL-scheme call can be fired silently by any app, so the scheme is OFF by
/// default and side-effecting scheme actions are confirmable.
enum AutomationSource: Equatable {
    case appIntent
    case urlScheme
}

/// PURE policy unit deciding whether an automation request may run. It encodes
/// three spec laws with no side effects, so every branch is unit-tested:
///   1. URL scheme OFF by default → reject scheme calls unless enabled (§13.5).
///   2. Capture honors trial/license state → reject licensed-capture actions when
///      capture is disabled by expiry, with the contracted error (spec: "Expired
///      trial blocks automated capture honestly"). Search/export are never gated.
///   3. Confirmation: a side-effecting scheme action under always-confirm asks first.
enum AutomationGate {
    /// - Parameters:
    ///   - action: the requested action.
    ///   - source: which surface asked (AppIntent vs URL scheme).
    ///   - urlSchemeEnabled: `AppSettings.urlSchemeEnabled` (the master toggle).
    ///   - confirmationMode: per-scheme confirmation posture (URL scheme only).
    ///   - licenseState: the current honest license state.
    static func decide(
        action: AutomationAction,
        source: AutomationSource,
        urlSchemeEnabled: Bool,
        confirmationMode: ConfirmationMode,
        licenseState: LicenseState
    ) -> GateDecision {
        // 1. URL scheme master switch. AppIntents are exempt (they ARE the user).
        if source == .urlScheme, !urlSchemeEnabled {
            return .reject(.urlSchemeDisabled)
        }

        // 2. Licensing. Only capture-class actions are gated; the data surfaces
        //    (search, OCR-on-file, settings) stay available forever after expiry.
        if action.isLicensedCapture, !licenseState.captureEnabled {
            return .reject(.captureRequiresLicense)
        }

        // 3. Confirmation. Scoped to the URL scheme + side-effecting actions.
        let needsConfirm = source == .urlScheme
            && confirmationMode == .alwaysConfirm
            && action.hasExternalSideEffect
        return needsConfirm ? .confirm : .proceed
    }
}
