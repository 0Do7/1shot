import Foundation
import Testing
@testable import OneShot

// x-callback-url return building (spec:automation: "Caller receives results" /
// "descriptive error callback"). Pure URL assembly, fully testable.

@Test func successCallback_appendsRecognizedText() {
    let callbacks = AutomationCallbacks(success: URL(string: "caller://done"), error: nil)
    let built = AutomationCallbackBuilder.successURL(for: .text("hello world"), callbacks: callbacks)
    let items = queryItems(built)
    #expect(items["text"] == "hello world")
}

@Test func successCallback_appendsFilePath() {
    let callbacks = AutomationCallbacks(success: URL(string: "caller://done"), error: nil)
    let built = AutomationCallbackBuilder.successURL(for: .file(path: "/tmp/a.png"), callbacks: callbacks)
    #expect(queryItems(built)["filePath"] == "/tmp/a.png")
}

@Test func successCallback_preservesCallersOwnParams() {
    let callbacks = AutomationCallbacks(success: URL(string: "caller://done?token=abc"), error: nil)
    let built = AutomationCallbackBuilder.successURL(for: .text("hi"), callbacks: callbacks)
    let items = queryItems(built)
    #expect(items["token"] == "abc") // caller state threaded through
    #expect(items["text"] == "hi")
}

@Test func successCallback_okResult_returnsBareCallback() {
    let callbacks = AutomationCallbacks(success: URL(string: "caller://done"), error: nil)
    let built = AutomationCallbackBuilder.successURL(for: .ok, callbacks: callbacks)
    #expect(built == URL(string: "caller://done"))
}

@Test func successCallback_nilWhenNoSuccessURL() {
    let built = AutomationCallbackBuilder.successURL(for: .text("x"), callbacks: AutomationCallbacks())
    #expect(built == nil) // fire-and-forget call has no callback to open
}

@Test func errorCallback_carriesCodeAndMessage() {
    let callbacks = AutomationCallbacks(success: nil, error: URL(string: "caller://fail"))
    let built = AutomationCallbackBuilder.errorURL(for: .captureRequiresLicense, callbacks: callbacks)
    let items = queryItems(built)
    #expect(items["errorCode"] == "capture-requires-license")
    #expect(items["errorMessage"]?.contains("license") == true)
}

@Test func errorCallback_nilWhenNoErrorURL() {
    let built = AutomationCallbackBuilder.errorURL(for: .urlSchemeDisabled, callbacks: AutomationCallbacks())
    #expect(built == nil)
}

// MARK: Action classification (the gate + dispatcher derive behavior from these)

@Test func action_sideEffectClassification() {
    #expect(AutomationAction.capture(.fullscreen).hasExternalSideEffect)
    #expect(AutomationAction.ocrRegion.hasExternalSideEffect)
    #expect(AutomationAction.pin(path: nil).hasExternalSideEffect)
    #expect(!AutomationAction.ocrImage(path: "/x").hasExternalSideEffect)
    #expect(!AutomationAction.search(query: "x").hasExternalSideEffect)
    #expect(!AutomationAction.openSettings(pane: .general).hasExternalSideEffect)
    #expect(!AutomationAction.hideShowAllPins.hasExternalSideEffect)
}

@Test func action_licensedCaptureClassification() {
    // Only live capture + interactive region OCR are license-gated captures.
    #expect(AutomationAction.capture(.area).isLicensedCapture)
    #expect(AutomationAction.ocrRegion.isLicensedCapture)
    #expect(!AutomationAction.ocrImage(path: "/x").isLicensedCapture)
    #expect(!AutomationAction.search(query: "x").isLicensedCapture)
    #expect(!AutomationAction.pin(path: nil).isLicensedCapture)
}

@Test func action_screenCaptureRequirement() {
    #expect(AutomationAction.capture(.window).requiresScreenCapture)
    #expect(AutomationAction.ocrRegion.requiresScreenCapture)
    #expect(!AutomationAction.ocrImage(path: "/x").requiresScreenCapture)
    #expect(!AutomationAction.pin(path: "/x").requiresScreenCapture)
}

@Test func error_codesAreStableTokens() {
    #expect(AutomationError.captureRequiresLicense.code == "capture-requires-license")
    #expect(AutomationError.screenRecordingPermissionMissing.code == "screen-recording-permission-missing")
    #expect(AutomationError.urlSchemeDisabled.code == "url-scheme-disabled")
    #expect(AutomationError.fileNotReadable("/x").code == "file-not-readable")
}

// MARK: Helpers

private func queryItems(_ url: URL?) -> [String: String] {
    guard let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return [:] }
    var out: [String: String] = [:]
    for item in components.queryItems ?? [] {
        out[item.name] = item.value
    }
    return out
}
