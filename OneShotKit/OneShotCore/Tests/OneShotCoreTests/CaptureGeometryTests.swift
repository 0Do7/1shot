import Foundation
import Testing
@testable import OneShotCore

/// A Retina MacBook (2x, main) with a 1x external to its right — the exact
/// mixed-DPI arrangement the spec scenarios name.
private let retina = DisplayDescriptor(
    id: 1,
    logicalFrame: LogicalRect(x: 0, y: 0, width: 1512, height: 982),
    scale: 2
)
private let external1x = DisplayDescriptor(
    id: 2,
    logicalFrame: LogicalRect(x: 1512, y: -200, width: 1920, height: 1080),
    scale: 1
)
private let layout = DisplayLayout(displays: [retina, external1x])

/// Deterministic generator for property tests (no seeded RNG in stdlib).
private struct LCG {
    var state: UInt64
    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 33) / Double(UInt32.max)
    }

    mutating func int(_ range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(next() * Double(range.count - 1))
    }
}

// Spec: Capture on a 1x display attached to a Retina Mac
@Test func areaOn1xDisplay_capturesAt1xDensity() throws {
    let selection = LogicalRect(x: 1612, y: 100, width: 100, height: 100)
    let target = try #require(layout.selectionTarget(for: selection))
    #expect(target.display.id == external1x.id)
    #expect(target.pixels == PixelRect(x: 100, y: 300, width: 100, height: 100))
}

// Spec: Capture on the Retina display of the same setup
@Test func areaOn2xDisplay_capturesAt2xDensity() throws {
    let selection = LogicalRect(x: 50, y: 60, width: 100, height: 100)
    let target = try #require(layout.selectionTarget(for: selection))
    #expect(target.display.id == retina.id)
    #expect(target.pixels == PixelRect(x: 100, y: 120, width: 200, height: 200))
}

// Spec: cross-display selection is constrained to one display, never corrupted
@Test func crossDisplaySelection_constrainedToBestOverlapDisplay() throws {
    // 300pt wide straddling the boundary at x=1512; 200pt on the external side.
    let selection = LogicalRect(x: 1412, y: 100, width: 300, height: 100)
    let target = try #require(layout.selectionTarget(for: selection))
    #expect(target.display.id == external1x.id)
    // Pixels clamped to the owning display — no mixed-scale output possible.
    #expect(target.pixels == PixelRect(x: 0, y: 300, width: 200, height: 100))
}

@Test func selectionOutsideAllDisplays_returnsNil() {
    #expect(layout.selectionTarget(for: LogicalRect(x: -500, y: -500, width: 100, height: 100)) == nil)
    // Above the Retina display but left of the (elevated) external.
    #expect(layout.display(containing: LogicalPoint(x: 100, y: -100)) == nil)
}

@Test func pointLookup_respectsPerDisplayBounds() {
    #expect(layout.display(containing: LogicalPoint(x: 100, y: 100))?.id == retina.id)
    #expect(layout.display(containing: LogicalPoint(x: 1600, y: -100))?.id == external1x.id)
    // The external extends above y=0; the Retina does not.
    #expect(layout.display(containing: LogicalPoint(x: 1513, y: -1))?.id == external1x.id)
}

@Test func displayPixelDimensions_deriveFromScale() {
    #expect(retina.pixelWidth == 3024)
    #expect(retina.pixelHeight == 1964)
    #expect(external1x.pixelWidth == 1920)
    #expect(external1x.pixelHeight == 1080)
}

// Property: pixel→logical→pixel round-trips exactly on every display
// (pixels are always representable in points; no drift permitted).
@Test func property_pixelLogicalRoundTrip_isExact() {
    var rng = LCG(state: 7)
    for display in layout.displays {
        for _ in 0 ..< 500 {
            let w = rng.int(1 ... 400)
            let h = rng.int(1 ... 400)
            let original = PixelRect(
                x: rng.int(0 ... display.pixelWidth - w),
                y: rng.int(0 ... display.pixelHeight - h),
                width: w,
                height: h
            )
            let roundTripped = display.pixelRect(for: display.logicalRect(for: original))
            #expect(roundTripped == original, "drift on display \(display.id): \(original) → \(roundTripped)")
        }
    }
}

// Property: outward snapping never loses selected content — the pixel rect's
// logical footprint always covers the (clamped) selection.
@Test func property_outwardSnapping_coversSelection() {
    var rng = LCG(state: 23)
    for display in layout.displays {
        for _ in 0 ..< 500 {
            let frame = display.logicalFrame
            // Fractional-coordinate selections inside the display.
            let x = frame.minX + rng.next() * (frame.width - 50)
            let y = frame.minY + rng.next() * (frame.height - 50)
            let selection = LogicalRect(x: x, y: y, width: 1 + rng.next() * 49, height: 1 + rng.next() * 49)

            let pixels = display.pixelRect(for: selection)
            let footprint = display.logicalRect(for: pixels)
            let epsilon = 1e-9
            #expect(footprint.minX <= selection.minX + epsilon)
            #expect(footprint.minY <= selection.minY + epsilon)
            #expect(footprint.maxX >= selection.maxX - epsilon)
            #expect(footprint.maxY >= selection.maxY - epsilon)
            // ...while never exceeding the display.
            #expect(pixels.x >= 0 && pixels.y >= 0)
            #expect(pixels.x + pixels.width <= display.pixelWidth)
            #expect(pixels.y + pixels.height <= display.pixelHeight)
        }
    }
}

// Property: a selection fully inside one display always resolves to that display.
@Test func property_containedSelection_resolvesToItsDisplay() {
    var rng = LCG(state: 42)
    for display in layout.displays {
        for _ in 0 ..< 200 {
            let frame = display.logicalFrame
            let selection = LogicalRect(
                x: frame.minX + rng.next() * (frame.width - 60),
                y: frame.minY + rng.next() * (frame.height - 60),
                width: 10 + rng.next() * 50,
                height: 10 + rng.next() * 50
            )
            #expect(layout.display(bestFor: selection)?.id == display.id)
        }
    }
}

@Test func captureGeometry_roundTripsThroughCodable() throws {
    let decoded = try JSONDecoder().decode(
        DisplayLayout.self,
        from: JSONEncoder().encode(layout)
    )
    #expect(decoded == layout)
}
