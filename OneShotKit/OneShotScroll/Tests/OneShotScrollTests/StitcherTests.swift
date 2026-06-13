import CoreGraphics
import Foundation
import Testing
@testable import OneShotScroll

// Task 7.1 — overlap estimation + stitching of a long vertical surface.
// Spec: scrolling-capture "Vertical and horizontal capture" (vertical path) and
// "Honest failure messaging". Fixtures slice a tall pattern into overlapping
// tiles at a KNOWN advance so ground-truth is exact.

// MARK: - OverlapEstimator / coarse→refine accuracy

@Test func verticalCapture_recoversKnownOffsetWithinOnePixel() throws {
    let page = ScrollFixtures.tallPage(width: 200, height: 1600)
    let vh = 400
    let trueAdvance = 137
    let pair = ScrollFixtures.tiles(from: page, viewportHeight: vh, advance: trueAdvance, count: 2)
    let prev = try #require(LuminanceExtractor.verticalProfile(of: pair[0]))
    let next = try #require(LuminanceExtractor.verticalProfile(of: pair[1]))

    let stitcher = Stitcher()
    let match = stitcher.estimate(previous: prev, next: next)
    let estimated = try #require(match)
    #expect(abs(estimated.advance - trueAdvance) <= 1)
    #expect(estimated.confidence > stitcher.confidenceThreshold)
}

@Test func verticalCapture_recoversSmallAndLargeOffsets() throws {
    let page = ScrollFixtures.tallPage(width: 160, height: 2000)
    let vh = 380
    let stitcher = Stitcher()
    for trueAdvance in [12, 60, 199, 320] {
        let pair = ScrollFixtures.tiles(from: page, viewportHeight: vh, advance: trueAdvance, count: 2)
        let prev = try #require(LuminanceExtractor.verticalProfile(of: pair[0]))
        let next = try #require(LuminanceExtractor.verticalProfile(of: pair[1]))
        let match = try #require(stitcher.estimate(previous: prev, next: next))
        #expect(abs(match.advance - trueAdvance) <= 1, "advance \(trueAdvance) -> \(match.advance)")
        #expect(match.confidence > stitcher.confidenceThreshold)
    }
}

@Test func nccPeaksAtPerfectAlignment() {
    // A signal correlated with itself scores ~1.0; against a constant scores 0.
    let signal: [Float] = (0 ..< 64).map { Float(sin(Double($0) * 0.3)) }
    let perfect = signal.withUnsafeBufferPointer { sig in
        OverlapEstimator.ncc(a: sig.baseAddress!, b: sig.baseAddress!, count: signal.count)
    }
    #expect(perfect > 0.999)
    let flat = [Float](repeating: 0.5, count: 64)
    let none = signal.withUnsafeBufferPointer { sig in
        flat.withUnsafeBufferPointer { flt in
            OverlapEstimator.ncc(a: sig.baseAddress!, b: flt.baseAddress!, count: signal.count)
        }
    }
    #expect(none == 0) // flat window has zero variance -> defined as no match
}

// MARK: - Stitcher: building a ScrollDocument over many frames

@Test func verticalCapture_stitchesLongPageIntoSingleDocument() {
    let page = ScrollFixtures.tallPage(width: 180, height: 2400)
    let vh = 420
    let trueAdvance = 150
    let frames = ScrollFixtures.tiles(from: page, viewportHeight: vh, advance: trueAdvance, count: 8)

    let stitcher = Stitcher()
    var document = ScrollDocument(axis: .vertical, tiles: [])
    for frame in frames {
        var grown = document
        let result = stitcher.stitch(incoming: frame, onto: document, appended: &grown)
        guard case let .ok(seam) = result else {
            Issue.record("expected ok stitch, got \(result)")
            return
        }
        if document.isEmpty {
            #expect(seam.advance == 0)
        } else {
            #expect(abs(seam.advance - trueAdvance) <= 1)
        }
        document = grown
    }
    #expect(document.tiles.count == 8)
    // Total traversed height = first viewport + 7 advances, ±1px per seam.
    let expected = vh + 7 * trueAdvance
    let rendered = Int(document.renderedSize().height)
    #expect(abs(rendered - expected) <= 8)
    #expect(Int(document.renderedSize().width) == 180)
}

@Test func resultOk_carriesSeamForRestitch() {
    // The seam document retains advance + absolute offset so restitch can
    // re-render without recapture (spec: Post-capture restitch).
    let page = ScrollFixtures.tallPage(width: 120, height: 1200)
    let vh = 300
    let frames = ScrollFixtures.tiles(from: page, viewportHeight: vh, advance: 100, count: 3)
    let stitcher = Stitcher()
    var document = ScrollDocument(axis: .vertical, tiles: [])
    var offsets: [Int] = []
    for frame in frames {
        var grown = document
        if case let .ok(seam) = stitcher.stitch(incoming: frame, onto: document, appended: &grown) {
            offsets.append(seam.offset)
        }
        document = grown
    }
    // Offsets accumulate: ~0, ~100, ~200.
    #expect(offsets.count == 3)
    #expect(offsets[0] == 0)
    #expect(abs(offsets[1] - 100) <= 1)
    #expect(abs(offsets[2] - 200) <= 2)
    // Document tiles store the same absolute offsets.
    #expect(document.tiles.map(\.offset) == offsets)
}

// MARK: - Honest failure

// Note: the "Low-confidence stitch halts with explanation" scenario (task 7.5)
// is covered in HonestFailureTests, which additionally asserts the typed
// explanation/remedy. The earlier 7.1 duplicate was removed to avoid a name
// collision after swiftformat normalizes test names (the repo strips the legacy
// `test_` prefix).

@Test func noSilentGarbage_documentUnchangedOnFailure() {
    // Cross-axis mismatch (viewport resized) must not stitch a misaligned tile.
    let tile = ScrollFixtures.tallPage(width: 200, height: 400)
    let narrower = ScrollFixtures.tallPage(width: 150, height: 400)
    let stitcher = Stitcher()
    let document = ScrollDocument(axis: .vertical, tiles: [ScrollTile(image: tile, offset: 0)])
    var grown = document
    let result = stitcher.stitch(incoming: narrower, onto: document, appended: &grown)
    #expect(result == .lowConfidence(.crossAxisMismatch(expected: 200, found: 150)))
    #expect(grown.tiles.count == 1)
}

@Test func firstFrameAlwaysAnchorsAtZero() {
    let tile = ScrollFixtures.tallPage(width: 100, height: 300)
    let stitcher = Stitcher()
    var grown = ScrollDocument(axis: .vertical, tiles: [])
    let result = stitcher.stitch(incoming: tile, onto: grown, appended: &grown)
    #expect(result == .ok(Seam(advance: 0, offset: 0, confidence: 1)))
    #expect(grown.tiles.count == 1)
    #expect(grown.tiles[0].offset == 0)
}

// MARK: - Full-resolution output (no downscale)

@Test func longRetinaCaptureStaysAtFullResolution() {
    // Tiles keep their native pixel size; the rendered canvas equals the sum of
    // advances + last viewport at full density (no downscaling anywhere).
    let scale = 2 // simulate a 2x display by full-res tiles
    let page = ScrollFixtures.tallPage(width: 100 * scale, height: 30 * 200 * scale)
    let vh = 200 * scale
    let advance = 180 * scale
    let frames = ScrollFixtures.tiles(from: page, viewportHeight: vh, advance: advance, count: 6)
    let stitcher = Stitcher()
    var document = ScrollDocument(axis: .vertical, tiles: [])
    for frame in frames {
        var grown = document
        _ = stitcher.stitch(incoming: frame, onto: document, appended: &grown)
        document = grown
    }
    // Every tile is still full native width; none downscaled.
    #expect(document.tiles.allSatisfy { $0.pixelWidth == 100 * scale })
    #expect(Int(document.renderedSize().width) == 100 * scale)
}

// MARK: - LuminanceStrip edge bands

@Test func luminanceStripExtractsCorrectEdgeBands() throws {
    let page = ScrollFixtures.tallPage(width: 64, height: 256)
    let tile = try #require(page.cropping(to: CGRect(x: 0, y: 0, width: 64, height: 200)))
    let top = try #require(LuminanceExtractor.verticalStrip(of: tile, edge: .top, rows: 32))
    let bottom = try #require(LuminanceExtractor.verticalStrip(of: tile, edge: .bottom, rows: 32))
    #expect(top.count == 32)
    #expect(top.origin == 0)
    #expect(bottom.count == 32)
    #expect(bottom.origin == 200 - 32)
    // The bottom band's samples equal the full profile's tail.
    let full = try #require(LuminanceExtractor.verticalProfile(of: tile))
    #expect(Array(full[(200 - 32) ..< 200]) == bottom.samples)
}

// MARK: - ScrollDocument value semantics

@Test func scrollDocumentRenderedSizeIsPureFunctionOfTilesAndAxis() {
    let a = ScrollFixtures.tallPage(width: 80, height: 100)
    let b = ScrollFixtures.tallPage(width: 80, height: 100)
    let doc = ScrollDocument(axis: .vertical, tiles: [])
        .appending(a, advance: 0)
        .appending(b, advance: 60)
    // height = first 100 + advance 60 = 160; width = 80.
    #expect(doc.renderedSize() == CGSize(width: 80, height: 160))
    #expect(ScrollDocument(axis: .vertical, tiles: []).renderedSize() == .zero)
}
