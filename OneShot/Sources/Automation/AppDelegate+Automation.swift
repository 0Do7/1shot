import AppKit
import OneShotCapture
import OneShotCore
import OneShotLibrary
import OneShotLicensing
import OneShotOCR

/// Installs the automation surface (§13.4 AppIntents + §13.5 URL scheme) from a
/// dedicated file so the change to `AppDelegate` itself is a single additive call
/// (`installAutomation()`) — another lane edits `AppDelegate.swift` concurrently.
///
/// The seams are wired to the real engines where they already exist in the app
/// (capture via the coordinator) and to honest stubs where the consuming lane has
/// not wired its app surface yet (pin §10.5, Library UI §9, Settings §13.3,
/// real licensing §14). Each stub fails or no-ops honestly and is logged in
/// docs/spec-conflicts.md — none invents an engine.
extension AppDelegate {
    /// `coordinator` is passed in from the call site inside `AppDelegate` (where
    /// the private property is visible) so this extension touches no private
    /// member — keeping the concurrent-edit surface on `AppDelegate.swift` to the
    /// single additive `installAutomation(coordinator:)` call.
    func installAutomation(coordinator: CaptureCoordinator) {
        let environment = LiveAutomationEnvironment(
            settings: { AppSettings() },
            licenseStateProvider: { Self.automationLicenseState() },
            startCaptureHandler: { mode in Task { await coordinator.perform(mode) } },
            ocrRegionHandler: { try await Self.automationOCRRegion() },
            pinHandler: { try Self.automationPin(path: $0) },
            toggleAllPinsHandler: { Self.automationToggleAllPins() },
            openSearchHandler: { [weak self] query in self?.automationOpenSearch(query) },
            openSettingsHandler: { [weak self] pane in self?.automationOpenSettings(pane) },
            confirmHandler: { await Self.automationConfirm($0) },
            ocrPipeline: .live(),
            librarySearchProvider: { Self.automationLibrarySearch() }
        )
        AutomationRegistrar.shared.install(environment: environment)
    }

    // MARK: Honest stubs (engine app-wiring owned by other lanes)

    /// §14 commerce lane owns the real `LicenseManager` instance in the app. Until
    /// it wires one in, automation reads an honest in-trial default so the surface
    /// is functional. The licensing GATE (expired-trial → contracted error) is
    /// fully unit-tested against injected states; only this app-default is interim.
    private static func automationLicenseState() -> LicenseState {
        .trial(daysRemaining: 14)
    }

    /// §8.3 OCR capture flow (hotkey → region → clipboard) is not yet wired into
    /// the app; the headless OCR-on-file path IS live. Region OCR throws an honest
    /// "not yet available" rather than returning a blank string.
    private static func automationOCRRegion() async throws -> String {
        throw AutomationError
            .malformedRequest("Region OCR via automation is not available yet (pending the in-app OCR flow, §8.3).")
    }

    /// §10.5 pin engine is not built. The intent/scheme surface exists (spec:
    /// "define the pin intent's surface but guard/stub it"); invoking it fails
    /// honestly instead of pretending to pin.
    private static func automationPin(path _: String?) throws {
        throw AutomationError.malformedRequest("Pinning is not available yet (pending the pin engine, §10.5).")
    }

    /// §10.5 pin engine deferred — no pins exist to toggle, so this is a no-op.
    private static func automationToggleAllPins() {
        NSLog("1shot automation: hide/show all pins requested but the pin engine (§10.5) is not built yet.")
    }

    /// §9 Library UI is not wired into the app; opening the search window is
    /// deferred. Logged so the no-op is observable, not silent.
    private func automationOpenSearch(_ query: String) {
        NSLog("1shot automation: open Library search '\(query)' requested; the Library window (§9) is not wired yet.")
    }

    /// §13.3 Settings UI is not built; opening a pane is deferred. Logged.
    private func automationOpenSettings(_ pane: SettingsPane) {
        NSLog(
            "1shot automation: open Settings pane '%@' requested; the Settings window (§13.3) is not wired yet.",
            pane.rawValue
        )
    }

    /// §9 Library store is not instantiated in the app yet, so structured search
    /// returns no results (the dispatcher handles nil as an honest empty result).
    private static func automationLibrarySearch() -> LibrarySearch? {
        nil
    }

    /// Confirmation prompt for a side-effecting scheme action (spec: always-confirm
    /// mode). A blocking modal alert; the user approves or declines.
    @MainActor
    private static func automationConfirm(_ action: AutomationAction) async -> Bool {
        let alert = NSAlert()
        alert.messageText = "Allow 1shot automation?"
        alert.informativeText = "Another app asked 1shot to perform an action "
            + "(\(String(describing: action))). Allow it?"
        alert.addButton(withTitle: "Allow")
        alert.addButton(withTitle: "Don't Allow")
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }
}
