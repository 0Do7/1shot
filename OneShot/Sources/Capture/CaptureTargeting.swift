import OneShotCore

/// Pure display-selection rules shared by the whole-display capture modes
/// (spec:capture-engine "Fullscreen", "Delayed", "Multi-display correctness").
enum CaptureTargeting {
    /// The display a fullscreen/delayed capture should grab: the one under the
    /// cursor, falling back to the first (main) display when the cursor is over
    /// no known display.
    static func fullscreenDisplay(in layout: DisplayLayout, cursor: LogicalPoint) -> DisplayDescriptor? {
        layout.display(containing: cursor) ?? layout.displays.first
    }
}
