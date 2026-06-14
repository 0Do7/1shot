import CoreGraphics
import Foundation
import Testing
@testable import OneShotScroll

// Task 7.2 — sticky-chrome detection + dedup.
// Spec: scrolling-capture "Sticky chrome handling". Frames share an identical
// top (and/or bottom) band while the body scrolls; the detector must return the
// band and DedupCrop must remove it from all but the first tile.

private func chromeFrames(
    width: Int = 160,
    height: Int = 400,
    headerRows: Int,
    footerRows: Int,
    advance: Int = 120,
    count: Int = 5
) -> [CGImage] {
    let page = ScrollFixtures.tallPage(width: width, height: height + advance * count)
    let bodies = ScrollFixtures.tiles(from: page, viewportHeight: height, advance: advance, count: count)
    return bodies.map { ScrollFixtures.withChrome($0, headerRows: headerRows, footerRows: footerRows) }
}

// MARK: - Detection

@Test func stickyHeaderDetectedAsStaticTopBand() {
    let frames = chromeFrames(headerRows: 48, footerRows: 0)
    let bands = StickyChromeDetector().detect(tiles: frames)
    #expect(abs(bands.headerRows - 48) <= 1)
    #expect(bands.footerRows == 0)
}

@Test func stickyHeaderAndFooterBothDetected() {
    let frames = chromeFrames(headerRows: 40, footerRows: 30)
    let bands = StickyChromeDetector().detect(tiles: frames)
    #expect(abs(bands.headerRows - 40) <= 1)
    #expect(abs(bands.footerRows - 30) <= 1)
}

@Test func noChromeWhenEveryRowScrolls() {
    // A page with no fixed band: all rows differ across frames -> no chrome.
    let page = ScrollFixtures.tallPage(width: 160, height: 1400)
    let frames = ScrollFixtures.tiles(from: page, viewportHeight: 300, advance: 120, count: 5)
    let bands = StickyChromeDetector().detect(tiles: frames)
    #expect(bands == ChromeBands.none)
}

@Test func tooFewFramesYieldsNoChrome() {
    let frames = chromeFrames(headerRows: 40, footerRows: 0, count: 2)
    #expect(StickyChromeDetector().detect(tiles: frames) == ChromeBands.none)
}

@Test func fullyStaticFrameIsNotAllChrome() {
    // An entirely static sequence (identical frames) must not dedup the whole
    // tile away — that would erase the only content.
    let solid = ScrollFixtures.withChrome(
        ScrollFixtures.tallPage(width: 100, height: 200),
        headerRows: 200, footerRows: 0
    )
    let bands = StickyChromeDetector().detect(tiles: [solid, solid, solid, solid])
    #expect(bands == ChromeBands.none)
}

// MARK: - Dedup

@Test func stickyHeaderNotRepeated_dedupRemovesHeaderFromLaterTiles() {
    let headerRows = 50
    let frames = chromeFrames(headerRows: headerRows, footerRows: 0)
    let bands = StickyChromeDetector().detect(tiles: frames)
    let deduped = DedupCrop.dedup(tiles: frames, bands: bands)

    // First tile unchanged (keeps the header we preserve once).
    #expect(deduped[0].height == frames[0].height)
    // Every later tile lost the header band.
    for i in 1 ..< deduped.count {
        #expect(deduped[i].height == frames[i].height - bands.headerRows)
    }
    // The header content (bright band) survives exactly once: in tile 0's top.
    let headerLuma = ScrollFixtures.meanLuma(of: deduped[0], topRow: 0, rows: headerRows - 1)
    #expect(headerLuma > 0.9)
    // And the deduped middle tiles start with body content, not the bright header.
    let bodyTop = ScrollFixtures.meanLuma(of: deduped[2], topRow: 0, rows: 5)
    #expect(bodyTop < 0.9)
}

@Test func floatingElementDoesNotCorruptSeams_bodyIsContinuous() {
    // A fixed footer band (a floating toolbar) is removed from interior tiles so
    // the stitched body stays continuous and the band doesn't ghost at seams.
    let footerRows = 40
    let frames = chromeFrames(headerRows: 0, footerRows: footerRows)
    let bands = StickyChromeDetector().detect(tiles: frames)
    let deduped = DedupCrop.dedup(tiles: frames, bands: bands)

    // Interior tiles lost the footer; the last tile KEEPS the footer once.
    #expect(deduped[1].height == frames[1].height - footerRows)
    #expect(deduped.last?.height == frames.last!.height)
}

@Test func dedupDocumentPreservesBodyOverlap_onlyChromeRemoved() {
    let headerRows = 30
    let advance = 100
    let frames = chromeFrames(headerRows: headerRows, footerRows: 0, count: 4)
    let bands = StickyChromeDetector().detect(tiles: frames)
    var document = ScrollDocument(axis: .vertical, tiles: [])
    for frame in frames {
        document = document.appending(frame, advance: advance)
    }

    // The traversed content extent BEFORE dedup is the ground truth the deduped
    // render must preserve (header dedup removes duplicated band content, not the
    // continuous body, so the along-axis extent does not grow).
    let traversedExtent = Int(document.renderedSize().height)

    let deduped = DedupCrop.dedup(document: document, bands: bands)
    #expect(deduped.tiles.count == 4)

    // Body overlap is PRESERVED: only the header band shifts geometry. Each later
    // tile loses `headerRows` from the top, so its origin moves down by exactly
    // that — never to the previous tile's far edge (which would re-emit the body
    // overlap as a duplicated band).
    for i in 1 ..< deduped.tiles.count {
        let expectedOffset = document.tiles[i].offset + bands.headerRows
        #expect(deduped.tiles[i].offset == expectedOffset)
        // Consecutive deduped tiles still OVERLAP (advance < cropped extent): the
        // body region is shared and overpainted, not concatenated edge-to-edge.
        let advanceFromPrev = deduped.tiles[i].offset - deduped.tiles[i - 1].offset
        #expect(advanceFromPrev < deduped.tiles[i].image.height)
    }

    // The rendered along-axis extent equals the original traversed extent — NOT
    // the sum of cropped tile heights (which would be ~2x the body at every seam).
    #expect(Int(deduped.renderedSize().height) == traversedExtent)
    let buttJointSum = deduped.tiles.reduce(0) { $0 + $1.image.height }
    #expect(Int(deduped.renderedSize().height) < buttJointSum)
}

@Test func dedupNoOpWhenNoChrome() {
    let page = ScrollFixtures.tallPage(width: 80, height: 600)
    let frames = ScrollFixtures.tiles(from: page, viewportHeight: 200, advance: 100, count: 3)
    let deduped = DedupCrop.dedup(tiles: frames, bands: ChromeBands.none)
    #expect(deduped.map(\.height) == frames.map(\.height))
}
