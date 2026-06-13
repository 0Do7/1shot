import CoreGraphics
import CoreImage
import Foundation
import OneShotCore

// Destructive region obscuring (task 6.1, spec:redaction "Effective obscuring
// strength" + "Hardened, non-reversible export"). Blur and pixelate sample the
// already-rendered pixels BENEATH the redaction and overwrite them irreversibly;
// blackout is a solid fill. There is no reversible/weak transform here — once a
// region is redacted the original pixels are gone from the output bitmap.
//
// Portability: CoreImage is allowed by the portability law (it forbids ONLY
// AppKit/SwiftUI/UIKit — design D2, Scripts/check-portability.sh). No NSImage.
enum RedactionRenderer {
    /// Floor constants that DEFEAT on-device OCR at the smallest user-selectable
    /// strength (spec scenario: "Strength cannot be lowered below the floor").
    ///
    /// These are expressed in **base-image pixels** (the unit of
    /// `RedactionAnnotation.strength`) and are scaled to output pixels at render
    /// time. A Gaussian sigma of `RedactionFloor.blurSigma` over typical 11–14pt UI
    /// text smears glyph strokes past Vision's recognizable threshold; an equally
    /// sized pixelate cell collapses each glyph into one or two flat blocks. The
    /// OCR-defeat is verified by the real `VisionTextRecognizer` in the test suite.
    enum RedactionFloor {
        /// Minimum Gaussian blur sigma (base-image pixels).
        static let blurSigma: Double = 8
        /// Minimum pixelate cell edge (base-image pixels).
        static let pixelCell: Double = 12
    }

    /// One shared CIContext. CIContext is thread-safe for rendering and reusing it
    /// avoids the ~hundreds-of-ms first-pipeline build cost on every redaction.
    /// Pinned to the same fixed sRGB working/output space as the rasterizer so
    /// redacted pixels stay byte-deterministic for goldens.
    private static let ciContext: CIContext = .init(options: [
        .workingColorSpace: RenderColorSpace.sRGB,
        .outputColorSpace: RenderColorSpace.sRGB,
        // Deterministic CPU render path (no GPU driver variance) so the golden
        // snapshot of the real blur is reproducible across machines.
        .useSoftwareRenderer: true,
    ])

    /// Maps `strength` (base-image px) to an effective Gaussian sigma in OUTPUT
    /// pixels, never below the OCR-defeat floor. `scale` is output px per doc unit.
    static func effectiveBlurSigma(strength: Double, scale: CGFloat) -> Double {
        let floored = max(strength, RedactionFloor.blurSigma)
        return floored * Double(scale)
    }

    /// Maps `strength` (base-image px) to an effective pixelate cell in OUTPUT
    /// pixels, never below the OCR-defeat floor (and never below 1).
    static func effectivePixelCell(strength: Double, scale: CGFloat) -> Double {
        let floored = max(strength, RedactionFloor.pixelCell)
        return max(1, floored * Double(scale))
    }

    /// Produces the destructively obscured pixels for `region` of `source`.
    ///
    /// - Parameters:
    ///   - source: the already-flattened bitmap (base + lower annotations) the
    ///     redaction sits over, in OUTPUT pixels (origin bottom-left, CG convention).
    ///   - region: the redaction rect in OUTPUT pixels (origin bottom-left), already
    ///     clamped to the source bounds by the caller.
    ///   - style/strength: the redaction parameters.
    ///   - scale: output px per document unit (to convert strength to output px).
    /// - Returns: a CGImage exactly `region`-sized whose pixels obscure the source,
    ///   or `nil` if the region is degenerate.
    static func obscuredPatch(
        of source: CGImage,
        region: CGRect,
        style: RedactionAnnotation.Style,
        strength: Double,
        scale: CGFloat
    ) -> CGImage? {
        let intRegion = region.integral
        guard intRegion.width >= 1, intRegion.height >= 1 else { return nil }

        switch style {
        case .blackout:
            // Solid opaque black; no source pixels survive at all.
            return solidPatch(width: Int(intRegion.width), height: Int(intRegion.height), color: DocColor.black)

        case .blur:
            let sigma = effectiveBlurSigma(strength: strength, scale: scale)
            return blurredPatch(of: source, region: intRegion, sigma: sigma)

        case .pixelate:
            let cell = effectivePixelCell(strength: strength, scale: scale)
            return pixelatedPatch(of: source, region: intRegion, cell: cell)
        }
    }

    // MARK: Blackout

    private static func solidPatch(width: Int, height: Int, color: DocColor) -> CGImage? {
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: RenderColorSpace.sRGB,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }

    // MARK: Blur

    /// Gaussian blur sampled from the source region. Edge handling: we clamp the
    /// region's edges (CIAffineClamp) BEFORE blurring so the filter samples real
    /// neighbouring colour instead of transparent black, then crop back to the
    /// region's exact extent — otherwise edges would darken / leak the surrounding
    /// content and, worse, leave a faint readable rim. This is the standard
    /// "clamp + blur + crop" recipe.
    private static func blurredPatch(of source: CGImage, region: CGRect, sigma: Double) -> CGImage? {
        let input = CIImage(cgImage: source)
        // Work in a region-local coordinate frame so the output extent is finite.
        let cropped = input.cropped(to: region)
        let clamped = cropped.clampedToExtent()
        guard let blur = CIFilter(name: "CIGaussianBlur") else { return nil }
        blur.setValue(clamped, forKey: kCIInputImageKey)
        blur.setValue(sigma, forKey: kCIInputRadiusKey)
        guard let blurred = blur.outputImage else { return nil }
        // Crop the (now infinite) clamped+blurred image back to the original region.
        let result = blurred.cropped(to: region)
        return ciContext.createCGImage(result, from: region, format: .RGBA8, colorSpace: RenderColorSpace.sRGB)
    }

    // MARK: Pixelate

    /// Mosaic pixelation sampled from the source region. CIPixellate averages each
    /// cell into one colour; we clamp the edges first (same reason as blur) so the
    /// border cells are full-strength flat blocks rather than half-transparent.
    private static func pixelatedPatch(of source: CGImage, region: CGRect, cell: Double) -> CGImage? {
        let input = CIImage(cgImage: source)
        let cropped = input.cropped(to: region)
        let clamped = cropped.clampedToExtent()
        guard let pixelate = CIFilter(name: "CIPixellate") else { return nil }
        pixelate.setValue(clamped, forKey: kCIInputImageKey)
        // Anchor the mosaic grid to the region origin so cells align regardless of
        // where the region sits — deterministic blocks for the golden snapshot.
        pixelate.setValue(CIVector(x: region.minX, y: region.minY), forKey: kCIInputCenterKey)
        pixelate.setValue(cell, forKey: kCIInputScaleKey)
        guard let pixelated = pixelate.outputImage else { return nil }
        let result = pixelated.cropped(to: region)
        return ciContext.createCGImage(result, from: region, format: .RGBA8, colorSpace: RenderColorSpace.sRGB)
    }
}
