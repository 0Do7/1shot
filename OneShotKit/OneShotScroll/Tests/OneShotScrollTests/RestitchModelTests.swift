import CoreGraphics
import Foundation
import Testing
@testable import OneShotScroll

// Task 7.6 — restitch MODEL: Codable round-trip + pure re-seam transforms (adjust
// a seam offset, trim a segment, re-derive layout WITHOUT recapture, operating on
// retained tiles). Spec: scrolling-capture "Post-capture restitch without
// recapture". Test names follow the spec's "#### Scenario:" headings.

private func capturedDocument(advance: Int = 120, count: Int = 5) -> ScrollDocument {
    let page = ScrollFixtures.tallPage(width: 140, height: 400 + advance * count)
    let frames = ScrollFixtures.tiles(from: page, viewportHeight: 400, advance: advance, count: count)
    var document = ScrollDocument(axis: .vertical, tiles: [])
    for frame in frames {
        document = document.appending(frame, advance: advance)
    }
    return document
}

/// Compares two documents pixel-byte-exact (CGImage has no value equality, so we
/// re-render each tile to RGBA and compare bytes) plus axis and offsets.
private func tilesByteEqual(_ lhs: ScrollDocument, _ rhs: ScrollDocument) -> Bool {
    guard lhs.axis == rhs.axis, lhs.tiles.count == rhs.tiles.count else { return false }
    for (left, right) in zip(lhs.tiles, rhs.tiles) {
        guard left.offset == right.offset else { return false }
        guard
            let lbuf = LuminanceExtractor.rgba(left.image),
            let rbuf = LuminanceExtractor.rgba(right.image),
            lbuf.width == rbuf.width, lbuf.height == rbuf.height,
            lbuf.pixels == rbuf.pixels
        else { return false }
    }
    return true
}

// MARK: - Codable round-trip

@Test func scrollDocumentCodableRoundTripsExactly() throws {
    let document = capturedDocument()
    let data = try JSONEncoder().encode(document)
    let decoded = try JSONDecoder().decode(ScrollDocument.self, from: data)

    #expect(decoded.axis == document.axis)
    #expect(decoded.tiles.map(\.offset) == document.tiles.map(\.offset))
    // Full-resolution law: tile pixel dimensions survive byte-exact (PNG lossless).
    #expect(decoded.tiles.map(\.pixelWidth) == document.tiles.map(\.pixelWidth))
    #expect(decoded.tiles.map(\.pixelHeight) == document.tiles.map(\.pixelHeight))
    #expect(tilesByteEqual(decoded, document))
}

@Test func horizontalDocumentCodableRoundTrips() throws {
    let page = ScrollFixtures.widePage(width: 1200, height: 160)
    let frames = ScrollFixtures.horizontalTiles(from: page, viewportWidth: 400, advance: 120, count: 4)
    var document = ScrollDocument(axis: .horizontal, tiles: [])
    for frame in frames {
        document = document.appending(frame, advance: 120)
    }

    let data = try JSONEncoder().encode(document)
    let decoded = try JSONDecoder().decode(ScrollDocument.self, from: data)
    #expect(decoded.axis == .horizontal)
    #expect(tilesByteEqual(decoded, document))
}

// MARK: - Scenario: Restitch after reopening from Library

@Test func restitchAfterReopeningFromLibrary() throws {
    // Save (encode) -> reopen (decode) -> all segments and seams still present and
    // adjustable. We then adjust a seam on the reopened doc to prove it is live.
    let document = capturedDocument(advance: 120, count: 4)
    let data = try JSONEncoder().encode(document)
    let reopened = try JSONDecoder().decode(ScrollDocument.self, from: data)

    #expect(reopened.tiles.count == document.tiles.count)
    #expect(reopened.tiles.map(\.offset) == document.tiles.map(\.offset))

    // Adjustable after reopen: move the seam before tile 2 to advance 80.
    let adjusted = reopened.adjustingSeam(before: 2, toAdvance: 80)
    let newAdvance = adjusted.tiles[2].offset - adjusted.tiles[1].offset
    #expect(newAdvance == 80)
}

// MARK: - Scenario: Fix a misaligned seam after capture

@Test func fixAMisalignedSeamAfterCapture() {
    // One seam is wrong; dragging it to the correct offset re-derives the layout
    // from the original segments — no recapture (we only touch offsets, never
    // re-rasterize or re-estimate).
    let document = capturedDocument(advance: 120, count: 4)
    let originalImages = document.tiles.map(\.image)

    // Misalign the seam before tile 2 (advance becomes 200 instead of 120).
    let misaligned = document.adjustingSeam(before: 2, toAdvance: 200)
    #expect(misaligned.tiles[2].offset - misaligned.tiles[1].offset == 200)
    // Tiles 0,1 unchanged; tiles 2,3 shifted rigidly by +80.
    #expect(misaligned.tiles[0].offset == document.tiles[0].offset)
    #expect(misaligned.tiles[1].offset == document.tiles[1].offset)
    #expect(misaligned.tiles[3].offset == document.tiles[3].offset + 80)

    // Correct it back to 120; the downstream tile returns to its original offset.
    let corrected = misaligned.adjustingSeam(before: 2, toAdvance: 120)
    #expect(corrected.tiles.map(\.offset) == document.tiles.map(\.offset))
    // No recapture: the underlying images are the SAME objects throughout.
    #expect(corrected.tiles.map(\.image) == originalImages)
}

@Test func adjustingSeamOnTileZeroIsNoOp() {
    let document = capturedDocument(count: 3)
    #expect(document.adjustingSeam(before: 0, toAdvance: 50).tiles.map(\.offset) == document.tiles.map(\.offset))
    #expect(document.adjustingSeam(before: 99, toAdvance: 50).tiles.map(\.offset) == document.tiles.map(\.offset))
}

// MARK: - Scenario: Trim a bad trailing segment

@Test func trimABadTrailingSegment() {
    // The final segment captured a popup; removing it re-renders without that
    // segment, the survivors keeping their relative spacing.
    let document = capturedDocument(advance: 120, count: 5)
    let trimmed = document.trimming(1, fromEnd: true)
    #expect(trimmed.tiles.count == 4)
    // Survivors keep their original offsets (we removed from the end, so the
    // anchor and inter-tile advances are unchanged).
    #expect(trimmed.tiles.map(\.offset) == Array(document.tiles.map(\.offset).prefix(4)))
    // Rendered extent shrank by exactly the removed tail's contribution.
    #expect(Int(trimmed.renderedSize().height) < Int(document.renderedSize().height))
}

@Test func trimmingLeadingSegmentReanchorsAtZero() {
    let document = capturedDocument(advance: 100, count: 4)
    let trimmed = document.trimming(1, fromEnd: false)
    #expect(trimmed.tiles.count == 3)
    // New first tile re-anchors to 0; relative spacing preserved (was 100 each).
    #expect(trimmed.tiles[0].offset == 0)
    #expect(trimmed.tiles[1].offset == 100)
    #expect(trimmed.tiles[2].offset == 200)
}

@Test func trimmingInteriorSegmentCollapsesSeam() {
    // Removing an interior tile collapses its two seams into one (advances sum):
    // 0,100,200,300 with tile 1 removed -> survivors at 0,100(=advance 100+? ),...
    let document = capturedDocument(advance: 100, count: 4) // offsets 0,100,200,300
    let trimmed = document.trimming(at: 1)
    #expect(trimmed.tiles.count == 3)
    // Original surviving offsets were 0,200,300; re-anchored keeps their gaps:
    // first->0, advance to old-200 = 200, advance to old-300 = 100 -> 0,200,300.
    #expect(trimmed.tiles.map(\.offset) == [0, 200, 300])
}

@Test func reanchoredEmptyStaysEmpty() {
    let empty = ScrollDocument.reanchored(axis: .vertical, tiles: [])
    #expect(empty.isEmpty)
    #expect(empty.renderedSize() == .zero)
}
