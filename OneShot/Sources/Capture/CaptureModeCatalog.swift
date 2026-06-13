import OneShotCapture
import OneShotCore

/// Single source of truth tying each capture `BindableAction` to its
/// `CaptureMode` and menu presentation (spec:capture-engine "Capture modes":
/// every mode is invocable both by a configurable global hotkey AND from the
/// menu-bar menu). The menu builds from `entries`; the hotkey dispatch maps via
/// `mode(for:)`.
enum CaptureModeCatalog {
    struct Entry: Equatable {
        let action: BindableAction
        let mode: CaptureMode
        let title: String
    }

    /// The six still-capture modes, in menu order. Scrolling (§7) and OCR (§8)
    /// are separate lanes and intentionally not in this still-capture list.
    static let entries: [Entry] = [
        Entry(action: .captureArea, mode: .area, title: "Capture Area"),
        Entry(action: .captureWindow, mode: .window, title: "Capture Window"),
        Entry(action: .captureFullscreen, mode: .fullscreen, title: "Capture Fullscreen"),
        Entry(action: .captureRepeat, mode: .repeatArea, title: "Repeat Last Area"),
        Entry(action: .captureDelayed, mode: .delayed, title: "Capture with Delay"),
        Entry(action: .captureFreeze, mode: .freezeScreen, title: "Freeze Screen & Capture"),
    ]

    static func entry(for action: BindableAction) -> Entry? {
        entries.first { $0.action == action }
    }

    static func mode(for action: BindableAction) -> CaptureMode? {
        entry(for: action)?.mode
    }
}
