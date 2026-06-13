import CoreGraphics
import Foundation
@testable import OneShotScroll

// Deterministic, headless fixtures for the stitcher/chrome tests (design D13:
// "stitcher unit tests on recorded fixture frame sequences (deterministic, runs
// on CI without permissions)"). We synthesize a tall pattern image and slice it
// into overlapping viewport tiles at a KNOWN scroll offset, so ground-truth
// advance is exact and the estimator can be asserted to ±1px.

enum ScrollFixtures {
    static let sRGB: CGColorSpace = .init(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    /// Makes a straight-RGBA8 context of the given pixel size, cleared to black.
    static func context(width: Int, height: Int) -> CGContext {
        let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: sRGB,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx
    }

    /// A tall page with a non-repeating vertical pattern: horizontal stripes of
    /// pseudo-random brightness plus a smooth gradient. Every row has a distinct
    /// luminance signature, so an exact scroll offset is recoverable. CG is
    /// y-up; we draw in raw pixel rows (row index = y from the bottom), which is
    /// fine because we only need DISTINCT, STABLE rows, not a particular sense.
    static func tallPage(width: Int, height: Int, seed: UInt64 = 0x9E37_79B9) -> CGImage {
        let ctx = context(width: width, height: height)
        var state = seed
        func next() -> Double {
            // xorshift64* — deterministic across machines.
            state ^= state >> 12
            state ^= state << 25
            state ^= state >> 27
            let v = state &* 0x2545_F491_4F6C_DD1D
            return Double(v >> 11) / Double(1 << 53)
        }
        for row in 0 ..< height {
            let noise = next()
            let gradient = Double(row) / Double(height)
            // Mix so adjacent rows differ AND the long-range trend is monotone.
            let level = 0.15 + 0.7 * (0.5 * noise + 0.5 * gradient)
            ctx.setFillColor(CGColor(srgbRed: level, green: level * 0.9, blue: 1 - level, alpha: 1))
            ctx.fill(CGRect(x: 0, y: row, width: width, height: 1))
        }
        return ctx.makeImage()!
    }

    /// Slices a tall page into `count` viewport tiles of `viewportHeight`, each
    /// scrolled `advance` pixels past the previous (advance < viewportHeight so
    /// tiles overlap). Tile i covers source rows [i*advance, i*advance+vh).
    /// Requires the page to be tall enough to hold every tile.
    static func tiles(
        from page: CGImage,
        viewportHeight: Int,
        advance: Int,
        count: Int
    ) -> [CGImage] {
        var out: [CGImage] = []
        for i in 0 ..< count {
            let top = i * advance
            let rect = CGRect(x: 0, y: top, width: page.width, height: viewportHeight)
            out.append(page.cropping(to: rect)!)
        }
        return out
    }

    /// Composites a fixed top band and/or bottom band (a solid color) over a tile,
    /// simulating sticky chrome: the band is identical across all tiles built this
    /// way while the body differs.
    static func withChrome(
        _ body: CGImage,
        headerRows: Int,
        footerRows: Int,
        headerLevel: Double = 0.95,
        footerLevel: Double = 0.05
    ) -> CGImage {
        let width = body.width
        let height = body.height
        let ctx = context(width: width, height: height)
        // CG is y-up: draw the body filling the frame, then overpaint bands.
        ctx.draw(body, in: CGRect(x: 0, y: 0, width: width, height: height))
        if headerRows > 0 {
            // Header = top in tile (image-row) space = high y in CG space.
            ctx.setFillColor(CGColor(srgbRed: headerLevel, green: headerLevel, blue: headerLevel, alpha: 1))
            ctx.fill(CGRect(x: 0, y: height - headerRows, width: width, height: headerRows))
        }
        if footerRows > 0 {
            ctx.setFillColor(CGColor(srgbRed: footerLevel, green: footerLevel, blue: footerLevel, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: footerRows))
        }
        return ctx.makeImage()!
    }

    /// Mean luma of a horizontal pixel band [topRow, topRow+rows) of an image,
    /// for assertions about which content survived a crop. Image-row order
    /// (top = row 0); converts to CG y-up internally.
    static func meanLuma(of image: CGImage, topRow: Int, rows: Int) -> Float {
        guard let buf = LuminanceExtractor.rgba(image) else { return -1 }
        let profile = LuminanceExtractor.verticalProfile(pixels: buf.pixels, width: buf.width, height: buf.height)
        var sum: Float = 0
        for row in topRow ..< (topRow + rows) {
            sum += profile[row]
        }
        return sum / Float(rows)
    }
}
