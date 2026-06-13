import CoreGraphics
import Foundation

// Luminance extraction for overlap correlation (task 7.1, design D8: "estimate
// offset by normalized cross-correlation on downsampled luminance strips").
//
// We correlate on per-row mean luminance ("row profiles") rather than full 2-D
// images: for a vertical scroll the signal that distinguishes one scroll
// position from the next is how brightness varies DOWN the strip, so a 1-D
// profile of length = strip height is both sufficient and cheap. Cross-axis
// detail is averaged out, which also makes the estimator robust to a few
// columns of moving chrome (e.g. a scrollbar).
//
// LUMINANCE FORMULA: Rec. 601 luma — Y = 0.299 R + 0.587 G + 0.114 B — applied
// to the rendered sRGB component bytes. We pick 601 over 709 deliberately: the
// exact coefficients are immaterial to correlation (any fixed luminance-like
// projection preserves the vertical brightness pattern we match on), and 601 is
// the long-standing default that keeps the math identical across machines. The
// values are NOT linearized; correlating on the gamma-encoded signal is fine
// and avoids a per-pixel pow().

/// A 1-D luminance profile sampled from a band at one edge of a tile, plus the
/// geometry needed to map a profile index back to a tile pixel. For a vertical
/// scroll a profile entry is the mean luma of one pixel row across the band's
/// width; the profile runs top→bottom in tile pixel order.
struct LuminanceStrip {
    /// One luminance sample (0...1) per pixel position along the scroll axis.
    let samples: [Float]
    /// The tile-pixel position along the axis at which the band starts
    /// (the y of the band's top row for vertical; x of its left column otherwise).
    let origin: Int

    var count: Int {
        samples.count
    }
}

enum LuminanceExtractor {
    /// Rec. 601 luma coefficients (see file header).
    static let lumaR: Float = 0.299
    static let lumaG: Float = 0.587
    static let lumaB: Float = 0.114

    /// A tight straight-alpha RGBA8 buffer plus its pixel dimensions. A named
    /// struct (rather than a 3-tuple) keeps the trio addressable as a unit.
    struct RGBAImage {
        let pixels: [UInt8]
        let width: Int
        let height: Int
    }

    /// Renders the whole tile once into a tight straight-alpha RGBA8 sRGB buffer,
    /// so luminance is read from byte-reproducible pixels regardless of the
    /// CGImage's source format. Returns nil only if the context can't be made.
    static func rgba(_ image: CGImage) -> RGBAImage? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let ok: Bool = pixels.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return ok ? RGBAImage(pixels: pixels, width: width, height: height) : nil
    }

    /// Builds the full-height row profile of a vertical tile: one mean-luma value
    /// per pixel row. (The "strip" used by the estimator is a sub-range of this;
    /// extracting the whole profile once lets the estimator slice cheaply.)
    static func verticalProfile(of image: CGImage) -> [Float]? {
        guard let buffer = rgba(image) else { return nil }
        return verticalProfile(pixels: buffer.pixels, width: buffer.width, height: buffer.height)
    }

    /// Extracts a `LuminanceStrip` for the band of `rows` rows at one edge of a
    /// vertical tile: `.top` samples rows [0, rows); `.bottom` samples the last
    /// `rows` rows. This is the cheap signal the overlap estimator can correlate
    /// when it only needs the edge bands rather than the whole profile.
    enum Edge { case top, bottom }

    static func verticalStrip(of image: CGImage, edge: Edge, rows: Int) -> LuminanceStrip? {
        guard let profile = verticalProfile(of: image) else { return nil }
        let height = profile.count
        let band = Swift.min(Swift.max(rows, 0), height)
        switch edge {
        case .top:
            return LuminanceStrip(samples: Array(profile[0 ..< band]), origin: 0)
        case .bottom:
            return LuminanceStrip(samples: Array(profile[(height - band) ..< height]), origin: height - band)
        }
    }

    /// Mean luma per row from a straight RGBA8 buffer (rows top→bottom). Pixels
    /// of length width*height*4. The alpha channel is ignored: fully transparent
    /// regions read as black, which is deterministic and fine for matching.
    static func verticalProfile(pixels: [UInt8], width: Int, height: Int) -> [Float] {
        guard width > 0, height > 0 else { return [] }
        var profile = [Float](repeating: 0, count: height)
        let inv = 1.0 / Float(width) / 255.0
        pixels.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for y in 0 ..< height {
                let row = base + y * width * 4
                var acc: Float = 0
                for x in 0 ..< width {
                    let px = row + x * 4
                    acc += lumaR * Float(px[0]) + lumaG * Float(px[1]) + lumaB * Float(px[2])
                }
                profile[y] = acc * inv
            }
        }
        return profile
    }

    // MARK: - Horizontal axis (task 7.7)

    // The horizontal path mirrors the vertical one with rows↔columns swapped: for
    // a left-right scroll the discriminating signal is how brightness varies ACROSS
    // the strip, so a 1-D profile of length = strip width (one mean-luma value per
    // pixel column, columns left→right) is the analogue of the row profile. The
    // estimator/stitcher consume the profile axis-agnostically, so they need no
    // horizontal-specific code beyond picking this profile.

    /// Builds the full-width column profile of a horizontal tile: one mean-luma
    /// value per pixel column (columns left→right). The cross-axis (height) is
    /// averaged out, mirroring `verticalProfile`'s averaging of width.
    static func horizontalProfile(of image: CGImage) -> [Float]? {
        guard let buffer = rgba(image) else { return nil }
        return horizontalProfile(pixels: buffer.pixels, width: buffer.width, height: buffer.height)
    }

    /// Mean luma per column from a straight RGBA8 buffer (columns left→right).
    static func horizontalProfile(pixels: [UInt8], width: Int, height: Int) -> [Float] {
        guard width > 0, height > 0 else { return [] }
        var profile = [Float](repeating: 0, count: width)
        let inv = 1.0 / Float(height) / 255.0
        pixels.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for x in 0 ..< width {
                var acc: Float = 0
                for y in 0 ..< height {
                    let px = base + (y * width + x) * 4
                    acc += lumaR * Float(px[0]) + lumaG * Float(px[1]) + lumaB * Float(px[2])
                }
                profile[x] = acc * inv
            }
        }
        return profile
    }

    /// Axis-dispatching profile: the per-position mean-luma signal the estimator
    /// correlates, running along the scroll axis (rows for vertical, columns for
    /// horizontal). Centralizes the axis switch so callers stay axis-agnostic.
    static func profile(of image: CGImage, axis: ScrollAxis) -> [Float]? {
        switch axis {
        case .vertical: verticalProfile(of: image)
        case .horizontal: horizontalProfile(of: image)
        }
    }
}
