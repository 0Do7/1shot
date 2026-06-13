import OneShotCapture
import OneShotCore
import Testing
@testable import OneShot

private func window(id: UInt32, frame: LogicalRect) -> WindowDescriptor {
    WindowDescriptor(
        windowID: id,
        owningAppBundleID: "com.example.app",
        frame: frame,
        isOnScreen: true,
        windowLayer: 0
    )
}

/// Candidates are front-to-back (SCShareableContent order); window 1 overlaps
/// window 2, which overlaps window 3.
private let overlapping = [
    window(id: 1, frame: LogicalRect(x: 100, y: 100, width: 400, height: 300)),
    window(id: 2, frame: LogicalRect(x: 300, y: 200, width: 400, height: 300)),
    window(id: 3, frame: LogicalRect(x: 50, y: 50, width: 900, height: 700)),
]

@Test func windowUnderCursor_picksTopmostOfOverlappingWindows() {
    // The cursor is inside all three frames; the frontmost (lowest index) wins.
    let hit = WindowPickerModel.windowUnderCursor(LogicalPoint(x: 350, y: 250), in: overlapping)
    #expect(hit?.windowID == 1)
}

@Test func windowUnderCursor_fallsThroughToWindowsBehind() {
    // Outside window 1, inside windows 2 and 3 → 2 (in front of 3) wins.
    let hit = WindowPickerModel.windowUnderCursor(LogicalPoint(x: 600, y: 400), in: overlapping)
    #expect(hit?.windowID == 2)
}

@Test func windowUnderCursor_nilWhenOverNoWindow() {
    let hit = WindowPickerModel.windowUnderCursor(LogicalPoint(x: 10, y: 10), in: overlapping)
    #expect(hit == nil)
}

@Test func windowUnderCursor_nilForEmptyCandidates() {
    #expect(WindowPickerModel.windowUnderCursor(LogicalPoint(x: 350, y: 250), in: []) == nil)
}

@MainActor
struct WindowPickerModelTests {
    @Test func updateCursor_tracksHighlightAndNotifiesOnlyOnChange() {
        let model = WindowPickerModel(candidates: overlapping)
        var events: [UInt32?] = []
        model.onHighlightChange = { events.append($0?.windowID) }

        model.updateCursor(LogicalPoint(x: 350, y: 250)) // → 1
        model.updateCursor(LogicalPoint(x: 360, y: 260)) // still 1: no event
        model.updateCursor(LogicalPoint(x: 600, y: 400)) // → 2
        model.updateCursor(LogicalPoint(x: 10, y: 10)) // → nil

        #expect(events == [1, 2, nil])
        #expect(model.highlighted == nil)
    }

    @Test func updateCandidates_reresolvesHighlightAtCursor() {
        let model = WindowPickerModel(candidates: overlapping)
        model.updateCursor(LogicalPoint(x: 350, y: 250))
        #expect(model.highlighted?.windowID == 1)

        // Window 1 closed mid-pick: the same cursor now hits window 2.
        model.updateCandidates(Array(overlapping.dropFirst()), cursor: LogicalPoint(x: 350, y: 250))
        #expect(model.highlighted?.windowID == 2)
    }

    @Test func cancel_clearsHighlightAndNotifies() {
        let model = WindowPickerModel(candidates: overlapping)
        model.updateCursor(LogicalPoint(x: 350, y: 250))
        var events: [UInt32?] = []
        model.onHighlightChange = { events.append($0?.windowID) }

        model.cancel()
        model.cancel() // idempotent: no second event

        #expect(model.highlighted == nil)
        #expect(events == [nil])
    }
}
