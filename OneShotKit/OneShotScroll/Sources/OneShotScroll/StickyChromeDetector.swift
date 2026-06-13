import Accelerate
import CoreGraphics
import Foundation

// Sticky-chrome detection (task 7.2, spec:scrolling-capture "Sticky chrome
// handling", design D8: "Sticky-header detection via per-row variance mask —
// rows static across frames = chrome → cropped").
//
// A viewport-fixed header/footer occupies the SAME pixel rows in every frame and
// shows the SAME content while the body scrolls beneath it. So for each row we
// take that row's mean luminance in every frame and measure its variance across
// frames: a static row has ~zero cross-frame variance, a scrolling-body row has
// high variance. The detector returns the static row RANGES that hug the top
// and bottom edges — those are the chrome bands. (Interior static rows, e.g. a
// solid block that happens not to change, are NOT chrome: chrome is edge-fixed,
// and only edge-anchored bands are safe to dedup.)
//
// HORIZONTAL (task 7.7): the same logic mirrors across the scroll axis. For a
// horizontal scroll the fixed bands are LEFT/RIGHT columns (a sticky sidebar /
// floating control), detected from the per-COLUMN profile. `headerRows`/
// `footerRows` therefore name the LEADING/TRAILING band extent ALONG the scroll
// axis: rows for vertical, columns for horizontal.

/// The static chrome bands found at the leading/trailing edges of the viewport
/// along the scroll axis, in tile-pixel coordinates. Either may be empty.
struct ChromeBands: Equatable {
    /// Leading band: positions [0, headerRows) along the axis are static.
    /// (Top rows for vertical, left columns for horizontal.) 0 = none.
    let headerRows: Int
    /// Trailing band: the last `footerRows` positions along the axis are static.
    /// (Bottom rows for vertical, right columns for horizontal.) 0 = none.
    let footerRows: Int

    static let none = ChromeBands(headerRows: 0, footerRows: 0)

    var hasChrome: Bool {
        headerRows > 0 || footerRows > 0
    }
}

struct StickyChromeDetector {
    /// A row counts as static when its cross-frame variance of mean luma is at or
    /// below this. Luma is in [0, 1]; 1e-5 tolerates rounding jitter while still
    /// rejecting any visible movement (a 1/255 step is ~1.5e-5 squared).
    var varianceThreshold: Float = 1e-5
    /// Require at least this many frames before claiming any chrome: with one or
    /// two frames "static across frames" is meaningless.
    var minimumFrames: Int = 3

    /// Detect edge chrome across a sequence of equal-size tiles along `axis`
    /// (vertical default for back-compat). All tiles must share the same pixel
    /// size; mismatched or too-few tiles yield `.none`. For horizontal the bands
    /// are left/right columns; for vertical, top/bottom rows (task 7.7).
    func detect(tiles: [CGImage], axis: ScrollAxis = .vertical) -> ChromeBands {
        guard tiles.count >= minimumFrames else { return ChromeBands.none }
        let height = tiles[0].height
        let width = tiles[0].width
        guard height > 0, width > 0 else { return ChromeBands.none }
        guard tiles.allSatisfy({ $0.width == width && $0.height == height }) else { return ChromeBands.none }

        // Per-frame profile along the scroll axis (rows for vertical, columns for
        // horizontal). `extent` is the band length along that axis.
        let extent = axis == .vertical ? height : width
        var profiles: [[Float]] = []
        profiles.reserveCapacity(tiles.count)
        for tile in tiles {
            guard let profile = LuminanceExtractor.profile(of: tile, axis: axis) else { return ChromeBands.none }
            profiles.append(profile)
        }
        return detect(profiles: profiles, height: extent)
    }

    /// Variance-mask core, separated for direct testing on synthetic profiles.
    /// `profiles[frame][row]` = mean luma of that row in that frame.
    func detect(profiles: [[Float]], height: Int) -> ChromeBands {
        guard profiles.count >= minimumFrames, height > 0 else { return ChromeBands.none }
        var isStatic = [Bool](repeating: false, count: height)
        let frameCount = profiles.count
        var perRow = [Float](repeating: 0, count: frameCount)
        for row in 0 ..< height {
            for frame in 0 ..< frameCount {
                perRow[frame] = profiles[frame][row]
            }
            isStatic[row] = Self.variance(perRow) <= varianceThreshold
        }

        // Header: leading run of static rows. Footer: trailing run. A frame that
        // is static EVERYWHERE (e.g. a blank capture) is not "all chrome" — that
        // would dedup the whole tile away — so we cap each band below full height.
        var headerRows = 0
        while headerRows < height, isStatic[headerRows] {
            headerRows += 1
        }
        var footerRows = 0
        while footerRows < height, isStatic[height - 1 - footerRows] {
            footerRows += 1
        }
        if headerRows >= height {
            // Entire tile static; treat none of it as removable chrome.
            return ChromeBands.none
        }
        if headerRows + footerRows > height {
            footerRows = height - headerRows
        }
        return ChromeBands(headerRows: headerRows, footerRows: footerRows)
    }

    /// Population variance via Accelerate.
    static func variance(_ values: [Float]) -> Float {
        guard values.count > 1 else { return 0 }
        var mean: Float = 0
        var meanSquare: Float = 0
        values.withUnsafeBufferPointer { buf in
            vDSP_measqv(buf.baseAddress!, 1, &meanSquare, vDSP_Length(values.count)) // mean of squares
            vDSP_meanv(buf.baseAddress!, 1, &mean, vDSP_Length(values.count))
        }
        return Swift.max(0, meanSquare - mean * mean)
    }
}
