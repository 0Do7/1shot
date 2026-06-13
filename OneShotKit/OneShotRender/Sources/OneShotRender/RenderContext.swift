import CoreGraphics
import Foundation
import OneShotCore

// Deterministic CPU rendering substrate (design D13 render quality / spec:
// rendering quality and export fidelity). Everything renders into a fixed-format
// sRGB CGBitmapContext so output is byte-reproducible across runs and machines —
// the prerequisite for stable golden snapshots.

enum RenderColorSpace {
    /// One fixed sRGB color space for every render. Created once; CGColorSpace is
    /// thread-safe and immutable, so a shared instance keeps goldens stable.
    static let sRGB: CGColorSpace = .init(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
}

extension DocColor {
    /// CGColor in the fixed sRGB space. Built component-wise (never from a system
    /// palette) so the same DocColor always yields identical pixels.
    var cgColor: CGColor {
        CGColor(
            colorSpace: RenderColorSpace.sRGB,
            components: [CGFloat(red), CGFloat(green), CGFloat(blue), CGFloat(alpha)]
        ) ?? CGColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }
}

/// A document-space → pixel-space transform plus the backing context. Document
/// coordinates are top-left origin, y-down (Geometry.swift); CoreGraphics is
/// bottom-left origin, y-up. We flip once and render everything in flipped,
/// document-aligned space so geometry math matches the model exactly.
struct RenderSurface {
    let context: CGContext
    /// Output pixel dimensions.
    let pixelWidth: Int
    let pixelHeight: Int
    /// Pixels per document unit (1 unit = one base-image pixel). 2.0 = Retina.
    let scale: CGFloat
    /// The visible document rect being rendered (crop window or full canvas).
    let visibleRect: DocRect

    /// Maps a document point into the (already flipped, scaled) context coordinate
    /// system. After `prepareDocumentSpace()` the context is translated so the
    /// visible rect's top-left sits at the origin and y grows downward.
    func point(_ p: DocPoint) -> CGPoint {
        CGPoint(x: p.x - visibleRect.minX, y: p.y - visibleRect.minY)
    }

    func rect(_ r: DocRect) -> CGRect {
        CGRect(
            x: r.minX - visibleRect.minX,
            y: r.minY - visibleRect.minY,
            width: r.size.width,
            height: r.size.height
        )
    }
}

enum RenderError: Error, Equatable {
    case contextCreationFailed
    case missingImage(String)
    case imageDecodeFailed(String)
    case pngEncodeFailed
    case emptyCanvas
}

enum BitmapContextFactory {
    /// Creates a premultiplied-RGBA sRGB context at the given pixel size, set up so
    /// drawing happens in document space: top-left origin, y-down, 1 doc unit =
    /// `scale` pixels. All AA/interpolation flags are pinned for determinism.
    static func make(pixelWidth: Int, pixelHeight: Int, scale: CGFloat) throws -> CGContext {
        guard pixelWidth > 0, pixelHeight > 0 else { throw RenderError.emptyCanvas }
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: RenderColorSpace.sRGB,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw RenderError.contextCreationFailed
        }

        // Deterministic quality knobs (spec: WYSIWYG / golden stability).
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)
        context.interpolationQuality = .high
        context.setShouldSmoothFonts(false) // subpixel smoothing is display-dependent; off for stable goldens
        context.setShouldSubpixelPositionFonts(true)
        context.setShouldSubpixelQuantizeFonts(false)

        // Flip from CG's bottom-left y-up into document top-left y-down, then scale
        // so we can draw using raw document units everywhere downstream.
        context.translateBy(x: 0, y: CGFloat(pixelHeight))
        context.scaleBy(x: scale, y: -scale)
        return context
    }
}
