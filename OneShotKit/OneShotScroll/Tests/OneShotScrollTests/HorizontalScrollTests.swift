import CoreGraphics
import Foundation
import Testing
@testable import OneShotScroll

// Task 7.7 — horizontal scrolling: left-right luminance strips mirroring the
// vertical path across OverlapEstimator / Stitcher / StickyChrome.
// Spec: scrolling-capture "Vertical and horizontal capture".
// Test names follow the spec's "#### Scenario:" headings.

// MARK: - Column-profile primitives

@Test func horizontalProfileExtractsPerColumnLuma() throws {
    // A wide page's column profile must be the per-column analogue of the row
    // profile: one mean-luma value per column, columns left→right.
    let page = ScrollFixtures.widePage(width: 256, height: 64)
    let profile = try #require(LuminanceExtractor.horizontalProfile(of: page))
    #expect(profile.count == 256)
    // The widePage gradient trends brighter left→right, so the tail averages
    // higher than the head.
    let head = profile[0 ..< 32].reduce(0, +) / 32
    let tail = profile[224 ..< 256].reduce(0, +) / 32
    #expect(tail > head)
}

// MARK: - Scenario: Horizontal capture of a wide surface

@Test func horizontalCaptureOfAWideSurface() {
    // A wide spreadsheet-like surface: tiles overlap left→right at a known advance;
    // the stitched output must have correct left-to-right continuity.
    let page = ScrollFixtures.widePage(width: 2400, height: 180)
    let vw = 420
    let trueAdvance = 150
    let frames = ScrollFixtures.horizontalTiles(from: page, viewportWidth: vw, advance: trueAdvance, count: 8)

    let stitcher = Stitcher()
    var document = ScrollDocument(axis: .horizontal, tiles: [])
    for frame in frames {
        var grown = document
        let result = stitcher.stitch(incoming: frame, onto: document, appended: &grown)
        guard case let .ok(seam) = result else {
            Issue.record("expected ok horizontal stitch, got \(result)")
            return
        }
        if document.isEmpty {
            #expect(seam.advance == 0)
        } else {
            #expect(abs(seam.advance - trueAdvance) <= 1, "advance \(trueAdvance) -> \(seam.advance)")
        }
        document = grown
    }
    #expect(document.tiles.count == 8)
    // Along the horizontal axis: first viewport + 7 advances, ±1px per seam.
    let expected = vw + 7 * trueAdvance
    #expect(abs(Int(document.renderedSize().width) - expected) <= 8)
    // Cross-axis (height) is unchanged.
    #expect(Int(document.renderedSize().height) == 180)
}

@Test func horizontalCapture_recoversSmallAndLargeOffsets() throws {
    let page = ScrollFixtures.widePage(width: 2000, height: 160)
    let vw = 380
    let stitcher = Stitcher()
    for trueAdvance in [12, 60, 199, 320] {
        let pair = ScrollFixtures.horizontalTiles(from: page, viewportWidth: vw, advance: trueAdvance, count: 2)
        let prev = try #require(LuminanceExtractor.horizontalProfile(of: pair[0]))
        let next = try #require(LuminanceExtractor.horizontalProfile(of: pair[1]))
        let match = try #require(stitcher.estimate(previous: prev, next: next))
        #expect(abs(match.advance - trueAdvance) <= 1, "advance \(trueAdvance) -> \(match.advance)")
        #expect(match.confidence > stitcher.confidenceThreshold)
    }
}

@Test func horizontalCrossAxisMismatchIsHeight() {
    // For horizontal the cross-axis is HEIGHT: a height change must trip the
    // cross-axis guard, not a width change.
    let tile = ScrollFixtures.widePage(width: 400, height: 200)
    let shorter = ScrollFixtures.widePage(width: 400, height: 150)
    let stitcher = Stitcher()
    let document = ScrollDocument(axis: .horizontal, tiles: [ScrollTile(image: tile, offset: 0)])
    var grown = document
    let result = stitcher.stitch(incoming: shorter, onto: document, appended: &grown)
    #expect(result == .lowConfidence(.crossAxisMismatch(expected: 200, found: 150)))
    #expect(grown.tiles.count == 1)
}

// MARK: - Sticky chrome on the horizontal axis (sidebar / floating control)

@Test func horizontalStickySidebarDetectedAsLeadingBand() {
    let leftCols = 48
    let page = ScrollFixtures.widePage(width: 400 + 120 * 5, height: 200)
    let bodies = ScrollFixtures.horizontalTiles(from: page, viewportWidth: 400, advance: 120, count: 5)
    let frames = bodies.map { ScrollFixtures.withVerticalChrome($0, leftCols: leftCols, rightCols: 0) }
    let bands = StickyChromeDetector().detect(tiles: frames, axis: .horizontal)
    #expect(abs(bands.headerRows - leftCols) <= 1)
    #expect(bands.footerRows == 0)
}

@Test func horizontalDedupRemovesSidebarFromLaterTilesPreservingOverlap() {
    let leftCols = 30
    let advance = 100
    let page = ScrollFixtures.widePage(width: 400 + advance * 4, height: 160)
    let bodies = ScrollFixtures.horizontalTiles(from: page, viewportWidth: 400, advance: advance, count: 4)
    let frames = bodies.map { ScrollFixtures.withVerticalChrome($0, leftCols: leftCols, rightCols: 0) }
    let bands = StickyChromeDetector().detect(tiles: frames, axis: .horizontal)

    var document = ScrollDocument(axis: .horizontal, tiles: [])
    for frame in frames {
        document = document.appending(frame, advance: advance)
    }
    let traversedExtent = Int(document.renderedSize().width)
    let deduped = DedupCrop.dedup(document: document, bands: bands)

    #expect(deduped.tiles.count == 4)
    // Later tiles lose the leading sidebar columns; origin shifts forward by that.
    for i in 1 ..< deduped.tiles.count {
        #expect(deduped.tiles[i].offset == document.tiles[i].offset + bands.headerRows)
        #expect(deduped.tiles[i].image.width == frames[i].width - bands.headerRows)
    }
    // Body continuity preserved: rendered width equals the original traversal,
    // not the butt-jointed sum of cropped tile widths.
    #expect(Int(deduped.renderedSize().width) == traversedExtent)
    let buttJointSum = deduped.tiles.reduce(0) { $0 + $1.image.width }
    #expect(Int(deduped.renderedSize().width) < buttJointSum)
}
