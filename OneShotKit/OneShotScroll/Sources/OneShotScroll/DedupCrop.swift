import CoreGraphics
import Foundation

// Sticky-chrome de-duplication (task 7.2, spec:scrolling-capture "Sticky chrome
// handling": "exclude repeated chrome from the stitched body so it does not
// appear duplicated at every seam. Fixed chrome from the first frame SHALL be
// preserved once at the corresponding edge of the output").
//
// Given the chrome bands the detector found, we crop the leading band off the
// start and the trailing band off the end of EVERY TILE EXCEPT THE FIRST. The
// first tile keeps its chrome, so the leading band appears exactly once at the
// start of the stitched output (and the trailing band once at the end,
// contributed by the last tile — which keeps ITS trailing band for the same
// reason). Cropping only the duplicated edge bands also keeps the seams clean: a
// fixed floating element inside an edge band can't ghost into the body because
// the band is removed before stitching.
//
// HORIZONTAL (task 7.7): the leading/trailing bands are left/right columns and
// the crop is along x rather than y; the seam-offset math is identical because
// `headerRows`/`footerRows` already name the band extent ALONG the scroll axis.

enum DedupCrop {
    /// Crops `bands.headerRows` from the leading edge and `bands.footerRows` from
    /// the trailing edge of a single tile along `axis`. Returns the original image
    /// when there's nothing to crop or the crop would be empty (honest: never
    /// invent pixels).
    static func cropBody(_ image: CGImage, bands: ChromeBands, axis: ScrollAxis = .vertical) -> CGImage {
        guard bands.hasChrome else { return image }
        let extent = axis == .vertical ? image.height : image.width
        let keep = extent - bands.headerRows - bands.footerRows
        guard keep > 0, bands.headerRows >= 0 else { return image }
        let rect = switch axis {
        case .vertical:
            CGRect(x: 0, y: bands.headerRows, width: image.width, height: keep)
        case .horizontal:
            CGRect(x: bands.headerRows, y: 0, width: keep, height: image.height)
        }
        return image.cropping(to: rect) ?? image
    }

    /// Applies chrome dedup across an ordered tile sequence: the FIRST tile is
    /// returned untouched (it carries the chrome the output keeps); the LAST tile
    /// keeps its trailing band (so it survives once) but loses its duplicated
    /// leading band; every middle tile loses both leading and trailing bands.
    static func dedup(tiles: [CGImage], bands: ChromeBands, axis: ScrollAxis = .vertical) -> [CGImage] {
        guard bands.hasChrome, tiles.count > 1 else { return tiles }
        return tiles.enumerated().map { index, tile in
            if index == 0 {
                return tile // first tile: keep the chrome we preserve once
            }
            if index == tiles.count - 1 {
                // last tile: drop the duplicated leading band, keep the trailing one
                return cropBody(tile, bands: ChromeBands(headerRows: bands.headerRows, footerRows: 0), axis: axis)
            }
            return cropBody(tile, bands: bands, axis: axis)
        }
    }

    /// Convenience: dedup a whole `ScrollDocument`. Tiles are re-cropped and the
    /// document is rebuilt PRESERVING the original measured body overlap: only the
    /// chrome positions change geometry. Cropping `headerRows` off a later tile
    /// makes its new leading edge the old position `headerRows`, so its origin
    /// shifts FORWARD by `headerRows` (original offset + header) to keep that body
    /// content at the same canvas position; the trailing crop only trims the far
    /// edge and needs no origin change. The body therefore stays continuous —
    /// later tiles still overlap earlier ones by the original advance, overpainting
    /// the seam instead of re-emitting a duplicated band. Works for both axes.
    static func dedup(document: ScrollDocument, bands: ChromeBands) -> ScrollDocument {
        guard bands.hasChrome, document.tiles.count > 1 else { return document }
        let original = document.tiles.map(\.image)
        let cropped = dedup(tiles: original, bands: bands, axis: document.axis)
        var rebuiltTiles: [ScrollTile] = []
        rebuiltTiles.reserveCapacity(cropped.count)
        for (index, image) in cropped.enumerated() {
            // First tile anchors at its original offset (its leading band is the
            // chrome we keep once). Each later tile loses `headerRows` from the
            // leading edge, so its origin moves forward by exactly that to leave
            // the body where it was.
            let originalOffset = document.tiles[index].offset
            let offset = index == 0 ? originalOffset : originalOffset + bands.headerRows
            rebuiltTiles.append(ScrollTile(image: image, offset: offset))
        }
        return ScrollDocument(axis: document.axis, tiles: rebuiltTiles)
    }
}
