import Foundation
import OneShotCapture
import OneShotCore

/// The single typed catalog of every action the automation surface can request,
/// shared by BOTH entry points (AppIntents §13.4 and the URL scheme §13.5) so
/// there is exactly one place that says "this is what 1shot can be told to do
/// from outside" (spec:automation "Public-surface parity"). Each case carries the
/// parameters the action needs; nothing here touches AppKit or the live engines,
/// so the whole catalog — and the parser/gate built on it — is unit-testable.
///
/// Side-effect classification lives on the case (`hasExternalSideEffect`) so the
/// confirmation contract (spec: "Actions with side effects beyond the app … SHALL
/// be confirmable") is derived from the action, never re-decided per call site.
enum AutomationAction: Equatable {
    /// Start a capture in the given mode. Interactive modes (area/window) present
    /// their overlay; non-interactive modes (fullscreen/repeat) shoot immediately.
    case capture(CaptureMode)
    /// Run OCR on a freshly captured region (interactive region pick), returning text.
    case ocrRegion
    /// Run OCR on an image already on disk at `path`, returning text. The headless
    /// path used by Shortcuts "Extract Text" steps.
    case ocrImage(path: String)
    /// Pin an image: from a file `path`, or from the current pasteboard when nil.
    case pin(path: String?)
    /// Toggle visibility of all pins (spec catalog: "hide/show all pins").
    case hideShowAllPins
    /// Open the Library search UI seeded with `query` (may be empty to just open).
    case search(query: String)
    /// Open Settings to a named pane.
    case openSettings(pane: SettingsPane)

    /// True when the action does something observable *outside* the app (takes a
    /// screen capture, materializes/pins an image). Drives the confirmation gate.
    /// Pure-internal navigation (search, open settings, toggle pins) is exempt.
    var hasExternalSideEffect: Bool {
        switch self {
        case .capture, .ocrRegion, .pin:
            true
        case .ocrImage, .hideShowAllPins, .search, .openSettings:
            false
        }
    }

    /// True when the action requires Screen Recording permission to produce real
    /// pixels. An OCR-on-file or pasteboard pin needs no capture permission.
    var requiresScreenCapture: Bool {
        switch self {
        case .capture, .ocrRegion:
            true
        case .ocrImage, .pin, .hideShowAllPins, .search, .openSettings:
            false
        }
    }

    /// True when the action is gated by capture licensing (spec: "Automation
    /// respects trial and license state" — capture is blocked post-expiry; search
    /// and the existing-data surfaces keep working forever). A live capture or an
    /// interactive OCR region IS a capture; OCR on an existing file, pinning an
    /// existing image, search, and settings are not.
    var isLicensedCapture: Bool {
        switch self {
        case .capture, .ocrRegion:
            true
        case .ocrImage, .pin, .hideShowAllPins, .search, .openSettings:
            false
        }
    }
}

/// The named Settings panes addressable from automation (spec:automation
/// "open Settings to a named pane"). Raw values are the STABLE scheme tokens —
/// renaming one breaks documented `oneshot://settings?pane=…` callers.
enum SettingsPane: String, CaseIterable {
    case general
    case capture
    case shortcuts
    case library
    case destinations
    case automation
    case about
}
