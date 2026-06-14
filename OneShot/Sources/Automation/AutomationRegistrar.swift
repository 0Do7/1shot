import AppKit
import CoreGraphics
import Foundation
import OneShotCapture
import OneShotCore
import OneShotLibrary
import OneShotLicensing
import OneShotOCR

/// Wires the automation surface into the running app WITHOUT bloating
/// `AppDelegate` (another lane edits that file). `AppDelegate` makes one additive
/// call — `AutomationRegistrar.shared.install(...)` — and everything else lives
/// here: the live `AutomationEnvironment`, the shared dispatcher AppIntents reach
/// through, and the URL Apple Event handler.
///
/// `shared` exists because AppIntents are instantiated by the system outside our
/// object graph, so they need a process-wide hook back to the live app (the
/// documented AppIntents pattern). It is `@MainActor`, set once at launch.
@MainActor
final class AutomationRegistrar {
    static let shared = AutomationRegistrar()

    private var environment: (any AutomationEnvironment)?
    private var urlHandler: AutomationURLHandler?

    private init() {}

    /// The dispatcher AppIntents and the URL handler share. Nil until `install`.
    var dispatcher: AutomationDispatcher? {
        guard let environment else { return nil }
        return AutomationDispatcher(environment: environment)
    }

    /// Structured Library search for the AppIntents search entity (§13.4 /
    /// §13.6 launcher support). Returns `[]` when the Library is disabled — search
    /// is never license-gated (data is never held hostage), so this runs even
    /// after trial expiry. Pure search wiring; the engine lives in OneShotLibrary.
    func searchLibrary(_ query: String, limit: Int = 50) async throws -> [SearchHit] {
        guard let search = environment?.librarySearch() else { return [] }
        return try await search.search(query, limit: limit)
    }

    /// Called once from `AppDelegate.applicationDidFinishLaunching` (additive).
    /// The caller builds the live environment (a struct whose memberwise init
    /// carries the seams) and hands it in, so this entry point stays narrow and
    /// the registrar owns no construction policy.
    func install(environment: any AutomationEnvironment) {
        self.environment = environment
        urlHandler = AutomationURLHandler(dispatcher: AutomationDispatcher(environment: environment))
        urlHandler?.register()
    }
}

/// The production `AutomationEnvironment`: reads live settings/license, checks
/// Screen Recording via `CGPreflightScreenCaptureAccess`, and forwards each seam
/// to the closure `AppDelegate` supplied. Pure routing decisions stay in the
/// dispatcher/gate; this type only adapts the live app to the protocol.
@MainActor
struct LiveAutomationEnvironment: AutomationEnvironment {
    let settings: () -> AppSettings
    let licenseStateProvider: () -> LicenseState
    let captureForAutomationHandler: (CaptureMode) async throws -> AutomationResult
    let ocrRegionHandler: () async throws -> String
    let pinHandler: (String?) throws -> Void
    let toggleAllPinsHandler: () -> Void
    let openSearchHandler: (String) -> Void
    let openSettingsHandler: (SettingsPane) -> Void
    let confirmHandler: (AutomationAction) async -> Bool
    let ocrPipeline: OCRPipeline
    let librarySearchProvider: () -> LibrarySearch?

    var licenseState: LicenseState {
        licenseStateProvider()
    }

    var urlSchemeEnabled: Bool {
        settings().urlSchemeEnabled
    }

    var confirmationMode: ConfirmationMode {
        // The persisted posture lives in §13.3 Settings; until that field exists,
        // the safe default is always-confirm for the scheme (any app can call it).
        .alwaysConfirm
    }

    var screenRecordingGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    func captureForAutomation(_ mode: CaptureMode) async throws -> AutomationResult {
        try await captureForAutomationHandler(mode)
    }

    func ocrRegion() async throws -> String {
        try await ocrRegionHandler()
    }

    func pin(path: String?) throws {
        try pinHandler(path)
    }

    func toggleAllPins() {
        toggleAllPinsHandler()
    }

    func openSearch(query: String) {
        openSearchHandler(query)
    }

    func openSettings(pane: SettingsPane) {
        openSettingsHandler(pane)
    }

    func confirm(action: AutomationAction) async -> Bool {
        await confirmHandler(action)
    }

    func librarySearch() -> LibrarySearch? {
        librarySearchProvider()
    }
}
