import Foundation
import OneShotCapture
import OneShotCore

/// Drives the window-picking flow (task 3.3, spec:capture-engine "Window
/// highlighting during pick"): given the capture candidates and a cursor
/// position, it tracks which window should be highlighted before any capture
/// occurs. The capture-mode coordinator (task 3.4) feeds it cursor moves and
/// consumes `onHighlightChange` to drive `WindowHighlightOverlay`.
@MainActor
final class WindowPickerModel {
    /// Candidates as produced by `ShareableContentService.capturableWindows`,
    /// FRONT-TO-BACK (SCShareableContent enumeration order — verified by live
    /// probe; see that helper's doc comment).
    private(set) var candidates: [WindowDescriptor]

    /// The window currently highlighted, if the cursor is over one.
    private(set) var highlighted: WindowDescriptor?

    /// Fired only when the highlight actually changes (including to nil).
    var onHighlightChange: ((WindowDescriptor?) -> Void)?

    init(candidates: [WindowDescriptor]) {
        self.candidates = candidates
    }

    /// Topmost candidate under a cursor position (global logical points, CG
    /// top-left orientation — the space `WindowDescriptor.frame` uses).
    /// Pure: candidates are front-to-back, so the first containing frame wins.
    nonisolated static func windowUnderCursor(
        _ point: LogicalPoint,
        in candidates: [WindowDescriptor]
    ) -> WindowDescriptor? {
        candidates.first { $0.frame.contains(point) }
    }

    func windowUnderCursor(_ point: LogicalPoint) -> WindowDescriptor? {
        Self.windowUnderCursor(point, in: candidates)
    }

    /// Recompute the highlight for a cursor move; notifies on change only.
    func updateCursor(_ point: LogicalPoint) {
        setHighlighted(windowUnderCursor(point))
    }

    /// Refresh candidates mid-pick (windows open/close while picking) and
    /// re-resolve the highlight at the current cursor position.
    func updateCandidates(_ candidates: [WindowDescriptor], cursor: LogicalPoint) {
        self.candidates = candidates
        setHighlighted(windowUnderCursor(cursor))
    }

    /// Esc hook for the coordinator (task 3.4): clears the highlight. The
    /// model installs no event monitors itself.
    func cancel() {
        setHighlighted(nil)
    }

    private func setHighlighted(_ window: WindowDescriptor?) {
        guard window?.windowID != highlighted?.windowID else { return }
        highlighted = window
        onHighlightChange?(window)
    }
}
