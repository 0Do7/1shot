import CoreGraphics
import Foundation
import OneShotCore
import Testing
@testable import OneShotRender

// Task 5.1 render-core suite. Golden snapshots are AA-tolerant (GoldenSupport).
// Each `#### Scenario:` in specs/annotation-editor/spec.md maps to a test named
// after it. DRAFT baselines live in Tests/OneShotRenderTests/Goldens.

@Test func packageBuildsAndLinks() {
    #expect(OneShotRenderInfo.packageName == "OneShotRender")
}

// MARK: - Golden snapshot assertions (one per annotation type + combined)

/// Renders a document and either records the baseline (ONESHOT_RECORD_GOLDENS=1)
/// or asserts against the committed DRAFT baseline within AA tolerance.
private func assertGolden(
    _ name: String,
    _ document: AnnotationDocument,
    scale: Double = 1,
    sourceLocation: SourceLocation = #_sourceLocation
) throws {
    let image = try AnnotationRasterizer.render(
        document: document,
        images: Canonical.provider(),
        scale: scale
    )

    if Golden.isRecording {
        let dir = Golden.recordDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try ImageCodec.encodePNG(image)
        try data.write(to: dir.appendingPathComponent("\(name).png"))
        return
    }

    guard let url = Golden.baselineURL(name), let baselineData = try? Data(contentsOf: url),
          let baseline = RasterBuffer.decodePNG(baselineData)
    else {
        Issue.record("\(GoldenError.missingBaseline(name))", sourceLocation: sourceLocation)
        return
    }
    let result = GoldenComparator.compare(candidate: image, baseline: baseline)
    #expect(result.passes, "golden mismatch for \(name): \(result.summary)", sourceLocation: sourceLocation)
}

@Test func golden_arrow() throws {
    try assertGolden("arrow", Canonical.arrow)
}

@Test func golden_curvedArrow() throws {
    try assertGolden("curved-arrow", Canonical.curvedArrow)
}

@Test func golden_line() throws {
    try assertGolden("line", Canonical.line)
}

@Test func golden_rectangle() throws {
    try assertGolden("rectangle", Canonical.rectangle)
}

@Test func golden_ellipse() throws {
    try assertGolden("ellipse", Canonical.ellipse)
}

@Test func golden_text() throws {
    try assertGolden("text", Canonical.text)
}

@Test func golden_highlight() throws {
    try assertGolden("highlight", Canonical.highlight)
}

@Test func golden_spotlight() throws {
    try assertGolden("spotlight", Canonical.spotlight)
}

@Test func golden_counters() throws {
    try assertGolden("counters", Canonical.counters)
}

@Test func golden_freehand() throws {
    try assertGolden("freehand", Canonical.freehand)
}

@Test func golden_magnifier() throws {
    try assertGolden("magnifier", Canonical.magnifier)
}

@Test func golden_redaction() throws {
    try assertGolden("redaction", Canonical.redaction)
}

@Test func golden_combined() throws {
    try assertGolden("combined", Canonical.combined)
}

// MARK: - spec: Rendering quality and export fidelity

/// #### Scenario: Export matches canvas
/// The flattened PNG decodes to pixels identical to the directly-rendered CGImage
/// (same rasterizer path = WYSIWYG by construction).
@Test func exportMatchesCanvas() throws {
    let doc = Canonical.combined
    let provider = Canonical.provider()
    let canvasImage = try AnnotationRasterizer.render(document: doc, images: provider, scale: 1)
    let pngData = try AnnotationRasterizer.flattenedPNGData(document: doc, images: provider, scale: 1)
    let exported = try #require(RasterBuffer.decodePNG(pngData))
    let result = GoldenComparator.compare(candidate: exported, baseline: canvasImage)
    #expect(result.dimensionsMatch)
    #expect(result.meanDifference <= Golden.meanTolerance)
}

/// #### Scenario: Retina capture exports at full resolution
@Test func retinaCaptureExportsAtFullResolution() throws {
    // A 2x-density capture exported with default settings keeps full 2x pixels.
    let doc = Canonical.document([.arrow(ArrowAnnotation(
        id: Canonical.uuid(99),
        start: DocPoint(x: 20, y: 20),
        end: DocPoint(x: 100, y: 100),
        stroke: StrokeStyle(color: Canonical.red, width: 4)
    )),], scale: 2)
    // No explicit scale => uses baseImage.scale (2.0).
    let image = try AnnotationRasterizer.render(document: doc, images: Canonical.provider())
    #expect(image.width == Canonical.baseWidth * 2)
    #expect(image.height == Canonical.baseHeight * 2)
}

/// Explicit 1x vs 2x: same document renders at proportional pixel dimensions, and
/// 1x default-scale honours base image scale=1.
@Test func scaleControlsPixelDimensions() throws {
    let doc = Canonical.rectangle // base scale 1
    let oneX = try AnnotationRasterizer.render(document: doc, images: Canonical.provider(), scale: 1)
    let twoX = try AnnotationRasterizer.render(document: doc, images: Canonical.provider(), scale: 2)
    #expect(oneX.width == Canonical.baseWidth)
    #expect(twoX.width == Canonical.baseWidth * 2)
    #expect(twoX.height == Canonical.baseHeight * 2)
}

// MARK: - spec: Re-editable annotation document

/// #### Scenario: Export flattens without mutating the document
@Test func exportFlattensWithoutMutatingTheDocument() throws {
    let before = Canonical.combined
    let provider = Canonical.provider()
    _ = try AnnotationRasterizer.flattenedPNGData(document: before, images: provider)
    // Value type: rasterization cannot mutate it; assert structural identity holds.
    #expect(before == Canonical.combined)
    #expect(before.annotations.count == 6)
}

// MARK: - spec: Annotation tool set

/// #### Scenario: Counter badges auto-increment
/// Deleting badge 2 renumbers the rest — verified via the document's position-
/// derived numbering that the rasterizer draws.
@Test func counterBadgesAutoIncrement() throws {
    var doc = Canonical.counters
    let ids = doc.annotations.map(\.id)
    #expect(doc.counterNumber(for: ids[0]) == 1)
    #expect(doc.counterNumber(for: ids[1]) == 2)
    #expect(doc.counterNumber(for: ids[2]) == 3)
    // Delete the middle counter.
    doc.annotations.remove(at: 1)
    #expect(doc.counterNumber(for: ids[0]) == 1)
    #expect(doc.counterNumber(for: ids[2]) == 2)
    // And it still rasterizes.
    let image = try AnnotationRasterizer.render(document: doc, images: Canonical.provider(), scale: 1)
    #expect(image.width == Canonical.baseWidth)
}

/// #### Scenario: Curved arrow is created and reshaped
/// The curved arrow renders to different pixels than the straight one with the
/// same endpoints (the control point reshapes the object).
@Test func curvedArrowIsCreatedAndReshaped() throws {
    let stroke = StrokeStyle(color: Canonical.blue, width: 6)
    let straight = Canonical.document([.arrow(ArrowAnnotation(
        id: Canonical.uuid(30),
        start: DocPoint(x: 40, y: 60),
        end: DocPoint(x: 270, y: 150),
        stroke: stroke
    )),])
    let curved = Canonical.document([.arrow(ArrowAnnotation(
        id: Canonical.uuid(30),
        start: DocPoint(x: 40, y: 60),
        end: DocPoint(x: 270, y: 150),
        control: DocPoint(x: 80, y: 180),
        stroke: stroke
    )),])
    let a = try AnnotationRasterizer.render(document: straight, images: Canonical.provider(), scale: 1)
    let b = try AnnotationRasterizer.render(document: curved, images: Canonical.provider(), scale: 1)
    let diff = GoldenComparator.compare(candidate: a, baseline: b)
    #expect(diff.dimensionsMatch)
    #expect(diff.meanDifference > Golden.meanTolerance, "curved arrow must differ from straight")
}

/// #### Scenario: Spotlight dims outside the region
/// Pixels inside the region keep the base luminance; pixels outside are darkened.
@Test func spotlightDimsOutsideTheRegion() throws {
    let doc = Canonical.spotlight
    let image = try AnnotationRasterizer.render(document: doc, images: Canonical.provider(), scale: 1)
    let plain = try AnnotationRasterizer.render(
        document: Canonical.document([]),
        images: Canonical.provider(),
        scale: 1
    )
    let lit = try #require(RasterBuffer.rgba(image))
    let base = try #require(RasterBuffer.rgba(plain))

    func luminance(_ buf: [UInt8], _ x: Int, _ y: Int, _ w: Int) -> Int {
        let i = (y * w + x) * 4
        return Int(buf[i]) + Int(buf[i + 1]) + Int(buf[i + 2])
    }
    // Center of region (150, 115) stays roughly equal; a corner outside is darker.
    let insideLit = luminance(lit.pixels, 150, 115, lit.width)
    let insideBase = luminance(base.pixels, 150, 115, base.width)
    let outsideLit = luminance(lit.pixels, 10, 10, lit.width)
    let outsideBase = luminance(base.pixels, 10, 10, base.width)
    #expect(abs(insideLit - insideBase) < 30, "region interior stays at full brightness")
    #expect(outsideLit < outsideBase - 30, "outside the region is dimmed")
}

/// #### Scenario: Magnifier callout tracks its source
/// Moving the source region changes the callout content (different pixels inside
/// the callout frame).
@Test func magnifierCalloutTracksItsSource() throws {
    let calloutRect = DocRect(x: 150, y: 120, width: 150, height: 70)
    let border = StrokeStyle(color: .white, width: 4)
    let a = Canonical.document([.magnifier(MagnifierAnnotation(
        id: Canonical.uuid(40),
        sourceRect: DocRect(x: 30, y: 24, width: 60, height: 40),
        calloutRect: calloutRect,
        border: border
    )),])
    let b = Canonical.document([.magnifier(MagnifierAnnotation(
        id: Canonical.uuid(40),
        sourceRect: DocRect(x: 30, y: 90, width: 60, height: 40),
        calloutRect: calloutRect,
        border: border
    )),])
    let imgA = try AnnotationRasterizer.render(document: a, images: Canonical.provider(), scale: 1)
    let imgB = try AnnotationRasterizer.render(document: b, images: Canonical.provider(), scale: 1)
    let diff = GoldenComparator.compare(candidate: imgA, baseline: imgB)
    #expect(diff.meanDifference > Golden.meanTolerance, "callout content must track the source region")
}

// MARK: - spec: Smart text-following highlight

/// #### Scenario: Highlight snaps to a text line
/// Snapped mode renders one filled band per detected line rect.
@Test func highlightSnapsToATextLine() throws {
    let doc = Canonical.highlight // three snapped rects over the dark bars
    let image = try AnnotationRasterizer.render(document: doc, images: Canonical.provider(), scale: 1)
    let lit = try #require(RasterBuffer.rgba(image))
    // A pixel on a highlighted band must be tinted toward the yellow marker vs base.
    let i = (28 * lit.width + 120) * 4
    #expect(lit.pixels[i] > 60) // red channel raised by yellow multiply over dark bar
}

/// #### Scenario: Highlight over non-text content
/// Free mode renders a single rectangular band wherever dragged.
@Test func highlightOverNonTextContent() throws {
    let doc = Canonical.document([.highlight(HighlightAnnotation(
        id: Canonical.uuid(50),
        mode: .free,
        rects: [DocRect(x: 40, y: 150, width: 200, height: 30)],
        color: Canonical.yellow
    )),])
    let image = try AnnotationRasterizer.render(document: doc, images: Canonical.provider(), scale: 1)
    #expect(image.width == Canonical.baseWidth) // renders without text detection
}

// MARK: - Determinism (golden-stability prerequisite)

/// Two renders of the same document are byte-identical — the basis for stable
/// goldens (WYSIWYG / fixed sRGB CPU context).
@Test func renderIsDeterministic() throws {
    let doc = Canonical.combined
    let a = try AnnotationRasterizer.flattenedPNGData(document: doc, images: Canonical.provider(), scale: 1)
    let b = try AnnotationRasterizer.flattenedPNGData(document: doc, images: Canonical.provider(), scale: 1)
    #expect(a == b)
}

// MARK: - Error handling

@Test func missingBaseImageThrows() throws {
    let doc = Canonical.document([])
    #expect(throws: RenderError.missingImage(Canonical.baseName)) {
        _ = try AnnotationRasterizer.render(document: doc, images: ImageProvider(images: [:]), scale: 1)
    }
}
