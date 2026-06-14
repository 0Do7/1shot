import AppKit
import Foundation
import ImageIO
import OneShotCapture
import OneShotCore
import OneShotLibrary
import OneShotLicensing
import OneShotOCR

/// The interactions the dispatcher needs from the live app, injected as
/// closures/protocols so the dispatcher's routing is testable without standing up
/// the real CaptureCoordinator / windows. The app wires the real seams in
/// `AutomationRegistrar`; tests inject fakes.
@MainActor
protocol AutomationEnvironment {
    /// Current honest license state (capture gating).
    var licenseState: LicenseState { get }
    /// `AppSettings.urlSchemeEnabled`.
    var urlSchemeEnabled: Bool { get }
    /// Per-scheme confirmation posture.
    var confirmationMode: ConfirmationMode { get }
    /// Whether Screen Recording permission is currently granted.
    var screenRecordingGranted: Bool { get }

    /// Start a capture in `mode` via the normal coordinator (chip/output config
    /// applies exactly as if hotkey-triggered — spec: "follows the user's normal
    /// chip/output configuration"). Interactive modes present their overlay.
    func startCapture(_ mode: CaptureMode)
    /// Run OCR on a region the user picks interactively, returning recognized text.
    func ocrRegion() async throws -> String
    /// Pin an image (path or pasteboard). Stubbed until §10.5 — see registrar.
    func pin(path: String?) throws
    /// Toggle visibility of all pins.
    func toggleAllPins()
    /// Open the Library search UI seeded with `query`.
    func openSearch(query: String)
    /// Open Settings to `pane`.
    func openSettings(pane: SettingsPane)
    /// Ask the user to approve a side-effecting scheme action. Returns true to proceed.
    func confirm(action: AutomationAction) async -> Bool
    /// The OCR pipeline (Vision-backed in the app; a fake in tests).
    var ocrPipeline: OCRPipeline { get }
    /// The Library search engine, or nil when the Library is disabled.
    func librarySearch() -> LibrarySearch?
}

/// Central, source-agnostic dispatch: both AppIntents (§13.4) and the URL handler
/// (§13.5) funnel here so the gate (disabled-by-default, licensing, confirmation)
/// and the engine wiring live in ONE place (spec: "Public-surface parity").
///
/// Returns an `AutomationResult` on success or throws a typed `AutomationError`;
/// the URL handler turns either into an x-callback, the AppIntent surfaces it to
/// Shortcuts. The dispatcher itself performs no UI of its own beyond the injected
/// seams, so its decision flow is unit-testable with a fake environment.
@MainActor
struct AutomationDispatcher {
    let environment: any AutomationEnvironment

    /// Run a request from `source`. Applies the gate first, then dispatches.
    func run(
        _ action: AutomationAction,
        source: AutomationSource,
        forceConfirm: Bool = false
    ) async throws -> AutomationResult {
        switch AutomationGate.decide(
            action: action,
            source: source,
            urlSchemeEnabled: environment.urlSchemeEnabled,
            confirmationMode: environment.confirmationMode,
            licenseState: environment.licenseState
        ) {
        case let .reject(error):
            throw error
        case .confirm:
            guard await environment.confirm(action: action) else { throw AutomationError.cancelledByUser }
        case .proceed:
            if forceConfirm, action.hasExternalSideEffect {
                guard await environment.confirm(action: action) else { throw AutomationError.cancelledByUser }
            }
        }

        // Permission is enforced after the gate so a disabled scheme / expired
        // trial reports its own (more relevant) error first.
        if action.requiresScreenCapture, !environment.screenRecordingGranted {
            throw AutomationError.screenRecordingPermissionMissing
        }

        return try await perform(action)
    }

    // MARK: - Action execution

    private func perform(_ action: AutomationAction) async throws -> AutomationResult {
        switch action {
        case let .capture(mode):
            environment.startCapture(mode)
            return .ok
        case .ocrRegion:
            return try await .text(environment.ocrRegion())
        case let .ocrImage(path):
            return try .text(ocrImage(at: path))
        case let .pin(path):
            try environment.pin(path: path)
            return .ok
        case .hideShowAllPins:
            environment.toggleAllPins()
            return .ok
        case let .search(query):
            environment.openSearch(query: query)
            return .ok
        case let .openSettings(pane):
            environment.openSettings(pane: pane)
            return .ok
        }
    }

    /// Headless OCR of an on-disk image (the Shortcuts "Extract Text" path —
    /// spec: "recognition runs entirely on-device"; no capture permission needed).
    private func ocrImage(at path: String) throws -> String {
        guard let image = Self.loadImage(at: path) else {
            throw AutomationError.fileNotReadable(path)
        }
        let result = try environment.ocrPipeline.run(on: image, mode: .preserveLayout)
        // Honest empty result: "no text found" is an empty string, never garbage.
        return result.clipboardText ?? ""
    }

    /// Decode a CGImage from a file path via ImageIO. Returns nil for a
    /// missing/undecodable file so the caller raises `.fileNotReadable`.
    static func loadImage(at path: String) -> CGImage? {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
