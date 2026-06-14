import OneShotLicensing
import Testing
@testable import OneShot

// Pure gate-policy coverage (spec:automation: URL scheme OFF by default,
// trial/license enforcement, per-scheme confirmation). The gate is the single
// place these three laws live, so every spec scenario maps to a branch here.

// MARK: URL scheme disabled by default (spec: "Scheme call while disabled")

@Test func gate_schemeDisabled_rejectsWithDisabledError() {
    let decision = AutomationGate.decide(
        action: .capture(.fullscreen),
        source: .urlScheme,
        urlSchemeEnabled: false,
        confirmationMode: .silent,
        licenseState: .licensed
    )
    #expect(decision == .reject(.urlSchemeDisabled))
}

@Test func gate_schemeDisabled_blocksEvenNonCaptureActions() {
    // A disabled API ignores ALL scheme calls, not just captures.
    let decision = AutomationGate.decide(
        action: .search(query: "x"),
        source: .urlScheme,
        urlSchemeEnabled: false,
        confirmationMode: .silent,
        licenseState: .licensed
    )
    #expect(decision == .reject(.urlSchemeDisabled))
}

@Test func gate_appIntent_isExemptFromSchemeSwitch() {
    // AppIntents are user-initiated; the URL master switch never applies to them.
    let decision = AutomationGate.decide(
        action: .capture(.fullscreen),
        source: .appIntent,
        urlSchemeEnabled: false,
        confirmationMode: .silent,
        licenseState: .licensed
    )
    #expect(decision == .proceed)
}

// MARK: Explicit enable (spec: "Explicit enable" — valid calls then perform)

@Test func gate_schemeEnabled_silentNonSideEffect_proceeds() {
    let decision = AutomationGate.decide(
        action: .search(query: "logs"),
        source: .urlScheme,
        urlSchemeEnabled: true,
        confirmationMode: .silent,
        licenseState: .licensed
    )
    #expect(decision == .proceed)
}

// MARK: Trial / license enforcement (spec: "Expired trial blocks automated capture honestly")

@Test func gate_expiredTrial_blocksCaptureWithLicenseError() {
    let decision = AutomationGate.decide(
        action: .capture(.fullscreen),
        source: .appIntent,
        urlSchemeEnabled: true,
        confirmationMode: .silent,
        licenseState: .expired
    )
    #expect(decision == .reject(.captureRequiresLicense))
}

@Test func gate_expiredTrial_blocksRegionOCR_asCapture() {
    let decision = AutomationGate.decide(
        action: .ocrRegion,
        source: .appIntent,
        urlSchemeEnabled: true,
        confirmationMode: .silent,
        licenseState: .expired
    )
    #expect(decision == .reject(.captureRequiresLicense))
}

@Test func gate_expiredTrial_searchStillProceeds() {
    // Search and the data surfaces are NEVER gated (data is never held hostage).
    let decision = AutomationGate.decide(
        action: .search(query: "stripe"),
        source: .appIntent,
        urlSchemeEnabled: true,
        confirmationMode: .silent,
        licenseState: .expired
    )
    #expect(decision == .proceed)
}

@Test func gate_expiredTrial_ocrOnFileStillProceeds() {
    // OCR of an existing file is not a capture, so expiry never blocks it.
    let decision = AutomationGate.decide(
        action: .ocrImage(path: "/tmp/x.png"),
        source: .appIntent,
        urlSchemeEnabled: true,
        confirmationMode: .silent,
        licenseState: .expired
    )
    #expect(decision == .proceed)
}

@Test func gate_trialGrace_stillAllowsCapture() {
    let decision = AutomationGate.decide(
        action: .capture(.area),
        source: .appIntent,
        urlSchemeEnabled: true,
        confirmationMode: .silent,
        licenseState: .trialGrace(hoursRemaining: 3)
    )
    #expect(decision == .proceed)
}

// MARK: Confirmation mode (spec: "Confirmation mode")

@Test func gate_alwaysConfirm_sideEffectingScheme_asksFirst() {
    let decision = AutomationGate.decide(
        action: .capture(.fullscreen),
        source: .urlScheme,
        urlSchemeEnabled: true,
        confirmationMode: .alwaysConfirm,
        licenseState: .licensed
    )
    #expect(decision == .confirm)
}

@Test func gate_alwaysConfirm_nonSideEffectingScheme_proceeds() {
    // Opening search has no side effect beyond the app — no prompt.
    let decision = AutomationGate.decide(
        action: .search(query: "x"),
        source: .urlScheme,
        urlSchemeEnabled: true,
        confirmationMode: .alwaysConfirm,
        licenseState: .licensed
    )
    #expect(decision == .proceed)
}

@Test func gate_appIntent_neverConfirms_evenForSideEffects() {
    // Confirmation is scoped to the URL scheme; AppIntents are already explicit.
    let decision = AutomationGate.decide(
        action: .capture(.fullscreen),
        source: .appIntent,
        urlSchemeEnabled: true,
        confirmationMode: .alwaysConfirm,
        licenseState: .licensed
    )
    #expect(decision == .proceed)
}

@Test func gate_licensingTakesPrecedenceOverConfirmation() {
    // An expired-trial capture is rejected for licensing before any prompt.
    let decision = AutomationGate.decide(
        action: .capture(.fullscreen),
        source: .urlScheme,
        urlSchemeEnabled: true,
        confirmationMode: .alwaysConfirm,
        licenseState: .expired
    )
    #expect(decision == .reject(.captureRequiresLicense))
}
