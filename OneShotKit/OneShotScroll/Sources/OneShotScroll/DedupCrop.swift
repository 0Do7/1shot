import CoreGraphics
import Foundation

// Sticky-chrome de-duplication (task 7.2, spec:scrolling-capture "Sticky chrome
// handling": "exclude repeated chrome from the stitched body so it does not
// appear duplicated at every seam. Fixed chrome from the first frame SHALL be
// preserved once at the corresponding edge of the output").
//
// Given the chrome bands the detector found, we crop the header band off the top
// and the footer band off the bottom of EVERY TILE EXCEPT THE FIRST. The first
// tile keeps its chrome, so the header appears exactly once at the top of the
// stitched output (and the footer once at the bottom, contributed by the last
// tile — which keeps ITS footer for the same reason). Cropping only the
// duplicated edge bands also keeps the seams clean: a fixed floating element
// inside an edge band can't ghost into the body because the band is removed
// before stitching.

enum DedupCrop {
    /// Crops `bands.headerRows` from the top and `bands.footerRows` from the
    /// bottom of a single tile. Returns the original image when there's nothing
    /// to crop or the crop would be empty (honest: never invent pixels).
    static func cropBody(_ image: CGImage, bands: ChromeBands) -> CGImage {
        guard bands.hasChrome else { return image }
        let height = image.height
        let keepTop = bands.headerRows
        let keepHeight = height - bands.headerRows - bands.footerRows
        guard keepHeight > 0, keepTop >= 0 else { return image }
        let rect = CGRect(x: 0, y: keepTop, width: image.width, height: keepHeight)
        return image.cropping(to: rect) ?? image
    }

    /// Applies chrome dedup across an ordered tile sequence: the FIRST tile is
    /// returned untouched (it carries the chrome the output keeps); the LAST tile
    /// keeps its footer (so the bottom chrome survives once) but loses its
    /// duplicated header; every middle tile loses both header and footer.
    static func dedup(tiles: [CGImage], bands: ChromeBands) -> [CGImage] {
        guard bands.hasChrome, tiles.count > 1 else { return tiles }
        return tiles.enumerated().map { index, tile in
            if index == 0 {
                return tile // first tile: keep the chrome we preserve once
            }
            if index == tiles.count - 1 {
                // last tile: drop the duplicated header, keep the real footer
                return cropBody(tile, bands: ChromeBands(headerRows: bands.headerRows, footerRows: 0))
            }
            return cropBody(tile, bands: bands)
        }
    }

    /// Convenience: dedup a whole `ScrollDocument`. Tiles are re-cropped and the
    /// document is rebuilt PRESERVING the original measured body overlap: only the
    /// chrome rows change geometry. Cropping `headerRows` off a later tile makes
    /// its new top row the old row `headerRows`, so its origin shifts DOWN by
    /// `headerRows` (original offset + header) to keep that body content at the
    /// same canvas position; the footer crop only trims the far edge and needs no
    /// origin change. The body therefore stays continuous — later tiles still
    /// overlap earlier ones by the original advance, overpainting the seam instead
    /// of re-emitting a duplicated band. Vertical axis only (7.1/7.2 scope).
    static func dedup(document: ScrollDocument, bands: ChromeBands) -> ScrollDocument {
        guard document.axis == .vertical, bands.hasChrome, document.tiles.count > 1 else { return document }
        let original = document.tiles.map(\.image)
        let cropped = dedup(tiles: original, bands: bands)
        var rebuiltTiles: [ScrollTile] = []
        rebuiltTiles.reserveCapacity(cropped.count)
        for (index, image) in cropped.enumerated() {
            // First tile anchors at its original offset (its header is the chrome
            // we keep once). Each later tile loses `headerRows` from the top, so
            // its origin moves down by exactly that to leave the body where it was.
            let originalOffset = document.tiles[index].offset
            let offset = index == 0 ? originalOffset : originalOffset + bands.headerRows
            rebuiltTiles.append(ScrollTile(image: image, offset: offset))
        }
        return ScrollDocument(axis: document.axis, tiles: rebuiltTiles)
    }
}
