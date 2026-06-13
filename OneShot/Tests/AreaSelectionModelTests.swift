import OneShotCore
import Testing
@testable import OneShot

/// Two displays with mixed scale factors: the main 2× internal at the origin and
/// a 1× external to its right — the setup the mixed-DPI scenarios describe.
private let retina = DisplayDescriptor(
    id: 1,
    logicalFrame: LogicalRect(x: 0, y: 0, width: 1512, height: 982),
    scale: 2.0
)
private let external1x = DisplayDescriptor(
    id: 2,
    logicalFrame: LogicalRect(x: 1512, y: 0, width: 1920, height: 1080),
    scale: 1.0
)
private let layout = DisplayLayout(displays: [retina, external1x])

// MARK: Pure geometry

@Test func normalizedRect_backwardDragYieldsPositiveSize() {
    let rect = AreaSelectionModel.normalizedRect(
        from: LogicalPoint(x: 300, y: 300),
        to: LogicalPoint(x: 100, y: 100)
    )
    #expect(rect == LogicalRect(x: 100, y: 100, width: 200, height: 200))
}

@Test func hitTest_classifiesCornersEdgesBodyAndMiss() {
    let rect = LogicalRect(x: 100, y: 100, width: 100, height: 100)
    #expect(AreaSelectionModel.hitTest(LogicalPoint(x: 100, y: 100), in: rect, slop: 8) == .corner(.topLeft))
    #expect(AreaSelectionModel.hitTest(LogicalPoint(x: 200, y: 200), in: rect, slop: 8) == .corner(.bottomRight))
    #expect(AreaSelectionModel.hitTest(LogicalPoint(x: 100, y: 150), in: rect, slop: 8) == .edge(.left))
    #expect(AreaSelectionModel.hitTest(LogicalPoint(x: 150, y: 100), in: rect, slop: 8) == .edge(.top))
    #expect(AreaSelectionModel.hitTest(LogicalPoint(x: 150, y: 150), in: rect, slop: 8) == .body)
    #expect(AreaSelectionModel.hitTest(LogicalPoint(x: 400, y: 400), in: rect, slop: 8) == nil)
}

@Test func resolved_cornerPivotsOnOppositeCorner() {
    let rect = LogicalRect(x: 100, y: 100, width: 100, height: 100)
    let result = AreaSelectionModel.resolved(
        handle: .corner(.topLeft),
        grabRect: rect,
        grabPoint: LogicalPoint(x: 100, y: 100),
        to: LogicalPoint(x: 120, y: 130)
    )
    #expect(result == LogicalRect(x: 120, y: 130, width: 80, height: 70))
}

@Test func resolved_leftEdgeMovesOneSideOnly() {
    let rect = LogicalRect(x: 100, y: 100, width: 100, height: 100)
    let result = AreaSelectionModel.resolved(
        handle: .edge(.left),
        grabRect: rect,
        grabPoint: LogicalPoint(x: 100, y: 150),
        to: LogicalPoint(x: 80, y: 150)
    )
    #expect(result == LogicalRect(x: 80, y: 100, width: 120, height: 100))
}

@Test func nudged_resizeClampsToOnePointFloor() {
    let thin = LogicalRect(x: 0, y: 0, width: 1, height: 50)
    let result = AreaSelectionModel.nudged(thin, .left, resizing: true, step: 1)
    #expect(result.width == 1)
}

// MARK: Stateful flow

@MainActor
struct AreaSelectionModelTests {
    private func drag(_ model: AreaSelectionModel, from: LogicalPoint, to: LogicalPoint) {
        model.pointerDown(at: from)
        model.pointerDragged(to: to)
        model.pointerUp()
    }

    /// Scenario: User drags a region and confirms — on the 2× display the output
    /// pixels are exactly the region at native (Retina) density.
    @Test func dragRegionOnRetina_resolvesToNativePixels() {
        let model = AreaSelectionModel(layout: layout)
        drag(model, from: LogicalPoint(x: 100, y: 100), to: LogicalPoint(x: 200, y: 200))
        let target = model.target()
        #expect(target?.display.id == 1)
        #expect(target?.pixels == PixelRect(x: 200, y: 200, width: 200, height: 200))
    }

    /// Scenario: Capture on a 1× external display attached to a Retina Mac —
    /// a 100×100-pt region yields a 100×100-px image.
    @Test func dragRegionOnExternal1x_resolvesToOneToOnePixels() {
        let model = AreaSelectionModel(layout: layout)
        drag(model, from: LogicalPoint(x: 1612, y: 100), to: LogicalPoint(x: 1712, y: 200))
        let target = model.target()
        #expect(target?.display.id == 2)
        #expect(target?.pixels == PixelRect(x: 100, y: 100, width: 100, height: 100))
    }

    /// Scenario: Selection shows live dimensions — the pixel readout updates as
    /// the free corner moves, reported in the source display's native pixels.
    @Test func liveDimensions_updateDuringDrag() {
        let model = AreaSelectionModel(layout: layout)
        model.pointerDown(at: LogicalPoint(x: 100, y: 100))
        model.pointerDragged(to: LogicalPoint(x: 150, y: 150))
        #expect(model.pixelSize()?.width == 100)
        #expect(model.pixelSize()?.height == 100)
        model.pointerDragged(to: LogicalPoint(x: 300, y: 200))
        #expect(model.pixelSize()?.width == 400)
        #expect(model.pixelSize()?.height == 200)
    }

    /// Scenario: User cancels the selection — nothing is left to capture.
    @Test func cancel_clearsSelectionAndTarget() {
        let model = AreaSelectionModel(layout: layout)
        drag(model, from: LogicalPoint(x: 100, y: 100), to: LogicalPoint(x: 200, y: 200))
        model.cancel()
        #expect(model.selection == nil)
        #expect(model.target() == nil)
    }

    /// Scenario: a cross-display selection is constrained to the display owning
    /// most of it (here the 1× external), never a mixed-scale result.
    @Test func crossDisplaySelection_constrainedToBestDisplay() {
        let model = AreaSelectionModel(layout: layout)
        drag(model, from: LogicalPoint(x: 1400, y: 100), to: LogicalPoint(x: 1700, y: 300))
        let target = model.target()
        #expect(target?.display.id == 2)
        #expect(target?.pixels == PixelRect(x: 0, y: 100, width: 188, height: 200))
    }

    /// A click with no drag arms no capture.
    @Test func emptyClick_leavesNoSelection() {
        let model = AreaSelectionModel(layout: layout)
        model.pointerDown(at: LogicalPoint(x: 100, y: 100))
        model.pointerUp()
        #expect(model.selection == nil)
        #expect(model.target() == nil)
    }

    /// Keyboard nudge: arrow translates the whole selection; Option+arrow resizes.
    @Test func nudge_movesAndResizesSelection() {
        let model = AreaSelectionModel(layout: layout)
        drag(model, from: LogicalPoint(x: 100, y: 100), to: LogicalPoint(x: 200, y: 200))
        model.nudge(.right, resizing: false, step: 1)
        model.nudge(.up, resizing: false, step: 1)
        #expect(model.selection == LogicalRect(x: 101, y: 99, width: 100, height: 100))
        model.nudge(.down, resizing: true, step: 1)
        #expect(model.selection?.height == 101)
    }

    /// Adjusting a corner handle before confirming reshapes the selection.
    @Test func adjustCorner_reshapesSelection() {
        let model = AreaSelectionModel(layout: layout)
        drag(model, from: LogicalPoint(x: 100, y: 100), to: LogicalPoint(x: 200, y: 200))
        model.pointerDown(at: LogicalPoint(x: 100, y: 100)) // grabs top-left
        model.pointerDragged(to: LogicalPoint(x: 120, y: 130))
        model.pointerUp()
        #expect(model.selection == LogicalRect(x: 120, y: 130, width: 80, height: 70))
    }

    /// Grabbing inside the selection moves the whole region.
    @Test func adjustBody_movesWholeSelection() {
        let model = AreaSelectionModel(layout: layout)
        drag(model, from: LogicalPoint(x: 100, y: 100), to: LogicalPoint(x: 200, y: 200))
        model.pointerDown(at: LogicalPoint(x: 150, y: 150)) // grabs body
        model.pointerDragged(to: LogicalPoint(x: 160, y: 170))
        model.pointerUp()
        #expect(model.selection == LogicalRect(x: 110, y: 120, width: 100, height: 100))
    }

    /// The magnifier samples a native-pixel square centered on the cursor and
    /// clamped inside the display under it.
    @Test func magnifierSample_centersAndClamps() {
        let model = AreaSelectionModel(layout: layout)
        let centered = model.magnifierSample(around: LogicalPoint(x: 100, y: 100), pixelDiameter: 21)
        #expect(centered?.display.id == 1)
        #expect(centered?.pixels == PixelRect(x: 190, y: 190, width: 21, height: 21))

        let clamped = model.magnifierSample(around: LogicalPoint(x: 1, y: 1), pixelDiameter: 21)
        #expect(clamped?.pixels.x == 0)
        #expect(clamped?.pixels.y == 0)
    }
}
