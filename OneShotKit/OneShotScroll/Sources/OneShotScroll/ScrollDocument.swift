import CoreGraphics
import Foundation

// Scrolling-capture seam model (task 7.1, spec:scrolling-capture "Post-capture
// restitch without recapture", design D8). The stitcher's output is NOT a
// flattened bitmap: it retains the source tiles plus the seam offset of each
// tile relative to its predecessor, so the restitch view can re-render from the
// originals without recapture. Library round-trip (persisting these tiles) is a
// later integration task — `ScrollDocument` deliberately lives in OneShotScroll,
// not OneShotCore, until then.

/// Scroll direction of a capture session. The axis is modeled here for both
/// orientations, but 7.1/7.2 implement only the vertical paths; horizontal
/// stitching is task 7.7 (later). `renderedSize()` and the stitcher honor the
/// axis so the horizontal path slots in without changing the document shape.
public enum ScrollAxis: String, Codable, Hashable, Sendable {
    case vertical
    case horizontal
}

/// One captured viewport frame placed into the scroll document. `image` is the
/// full-resolution tile at the source display's native density (the spec's
/// "full-resolution output" law — tiles are never downscaled). `offset` is the
/// displacement, in tile pixels along the scroll axis, of this tile's origin
/// relative to the FIRST tile's origin: tile 0 has offset 0, and each later
/// tile's offset is its predecessor's offset plus the newly revealed advance.
public struct ScrollTile: @unchecked Sendable {
    // @unchecked Sendable invariant: `image` is a CGImage we treat as immutable
    // (never drawn into after construction); the rest are value types. CGImage is
    // internally thread-safe for reads, matching CapturedFrame's own contract.

    /// Full-resolution tile pixels.
    public let image: CGImage
    /// Origin displacement along the scroll axis, in tile pixels, from tile 0.
    /// For the first tile this is 0.
    public let offset: Int

    public init(image: CGImage, offset: Int) {
        self.image = image
        self.offset = offset
    }

    /// Pixel size of the tile.
    public var pixelWidth: Int {
        image.width
    }

    public var pixelHeight: Int {
        image.height
    }

    /// Extent along the scroll axis (height for vertical, width for horizontal).
    public func extent(axis: ScrollAxis) -> Int {
        switch axis {
        case .vertical: image.height
        case .horizontal: image.width
        }
    }

    /// Extent across the scroll axis (width for vertical, height for horizontal).
    public func crossExtent(axis: ScrollAxis) -> Int {
        switch axis {
        case .vertical: image.width
        case .horizontal: image.height
        }
    }
}

/// The editable result of a scrolling capture: the ordered source tiles, each
/// with its seam offset, plus the axis. Re-rendering the flattened canvas is a
/// pure function of these fields (`renderedSize()` gives the canvas the renderer
/// must allocate), so seam edits and trims never require recapture.
public struct ScrollDocument: @unchecked Sendable {
    // @unchecked Sendable invariant: only stored property beyond value types is
    // each ScrollTile's CGImage, which carries the same immutable-reads invariant.

    public let axis: ScrollAxis
    /// Tiles in capture order. `tiles[0]` is the anchor (offset 0). Offsets are
    /// monotonically non-decreasing along a well-formed capture.
    public let tiles: [ScrollTile]

    public init(axis: ScrollAxis, tiles: [ScrollTile]) {
        self.axis = axis
        self.tiles = tiles
    }

    public var isEmpty: Bool {
        tiles.isEmpty
    }

    /// Pixel size of the flattened canvas covering every tile at its seam offset.
    /// Along the axis: from the minimum tile origin to the maximum tile far edge.
    /// Across the axis: the widest tile (tiles may differ if the viewport
    /// resized mid-capture). Empty document → zero size.
    public func renderedSize() -> CGSize {
        guard let first = tiles.first else { return .zero }
        var minOrigin = first.offset
        var maxFarEdge = first.offset + first.extent(axis: axis)
        var maxCross = first.crossExtent(axis: axis)
        for tile in tiles.dropFirst() {
            minOrigin = Swift.min(minOrigin, tile.offset)
            maxFarEdge = Swift.max(maxFarEdge, tile.offset + tile.extent(axis: axis))
            maxCross = Swift.max(maxCross, tile.crossExtent(axis: axis))
        }
        let alongExtent = maxFarEdge - minOrigin
        switch axis {
        case .vertical:
            return CGSize(width: maxCross, height: alongExtent)
        case .horizontal:
            return CGSize(width: alongExtent, height: maxCross)
        }
    }

    /// Appends a tile whose origin sits `advance` pixels past the previous tile's
    /// origin along the axis (the value `OverlapEstimator` recovers). The first
    /// appended tile anchors at offset 0 regardless of `advance`.
    public func appending(_ image: CGImage, advance: Int) -> ScrollDocument {
        let offset = tiles.last.map { $0.offset + advance } ?? 0
        return ScrollDocument(axis: axis, tiles: tiles + [ScrollTile(image: image, offset: offset)])
    }

    // MARK: - Re-seam transforms (task 7.6)

    // Restitch operates PURELY on the retained tiles: every transform returns a new
    // document by re-deriving offsets, never recapturing or rasterizing. The
    // renderer flattens the result; these only move/trim the seam geometry. (Spec:
    // "the corrected result re-rendered from the original segments — no recapture".)

    /// Re-positions the seam BEFORE tile `index` (1...tiles.count-1) so that tile's
    /// origin sits `advance` pixels past its predecessor, and SHIFTS every tile at
    /// or after `index` by the same delta so the rest of the stack stays rigid
    /// (only the one seam moves; downstream relative spacing is preserved). Tile 0
    /// has no preceding seam, so `index <= 0` or out of range is a no-op.
    public func adjustingSeam(before index: Int, toAdvance advance: Int) -> ScrollDocument {
        guard index >= 1, index < tiles.count else { return self }
        let currentAdvance = tiles[index].offset - tiles[index - 1].offset
        let delta = advance - currentAdvance
        guard delta != 0 else { return self }
        let shifted = tiles.enumerated().map { idx, tile in
            idx >= index ? ScrollTile(image: tile.image, offset: tile.offset + delta) : tile
        }
        return ScrollDocument(axis: axis, tiles: shifted)
    }

    /// Removes tile `index`, re-deriving offsets so the result is well-formed
    /// (anchored at 0). Trimming preserves the relative advances of the SURVIVING
    /// tiles: the seams either side of the removed tile collapse into one whose
    /// advance is their sum (the surviving neighbours keep their original gap to
    /// the rest of the stack). Out-of-range index is a no-op.
    public func trimming(at index: Int) -> ScrollDocument {
        guard index >= 0, index < tiles.count else { return self }
        var kept = tiles
        kept.remove(at: index)
        return Self.reanchored(axis: axis, tiles: kept)
    }

    /// Trims `count` tiles from the leading (`fromEnd == false`) or trailing end,
    /// re-anchoring the survivors. Removing a bad popup at the tail is the common
    /// case (spec scenario "Trim a bad trailing segment").
    public func trimming(_ count: Int, fromEnd: Bool) -> ScrollDocument {
        guard count > 0 else { return self }
        let keepCount = Swift.max(0, tiles.count - count)
        let kept = fromEnd ? Array(tiles.prefix(keepCount)) : Array(tiles.suffix(keepCount))
        return Self.reanchored(axis: axis, tiles: kept)
    }

    /// Re-derives a well-formed document from a tile list: the first surviving tile
    /// is re-anchored to offset 0 and every later tile keeps its ORIGINAL spacing
    /// to its predecessor (advance = original offset difference). This is the pure
    /// "re-derive layout" the restitch view needs after a trim. Empty stays empty.
    public static func reanchored(axis: ScrollAxis, tiles: [ScrollTile]) -> ScrollDocument {
        guard let first = tiles.first else { return ScrollDocument(axis: axis, tiles: []) }
        var rebuilt: [ScrollTile] = [ScrollTile(image: first.image, offset: 0)]
        rebuilt.reserveCapacity(tiles.count)
        var previousOriginal = first.offset
        var runningOffset = 0
        for tile in tiles.dropFirst() {
            let advance = tile.offset - previousOriginal
            runningOffset += advance
            rebuilt.append(ScrollTile(image: tile.image, offset: runningOffset))
            previousOriginal = tile.offset
        }
        return ScrollDocument(axis: axis, tiles: rebuilt)
    }
}
