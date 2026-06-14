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

    /// Erase (content-aware fill / background-blend) tuning. Per spike S1
    /// (`docs/spikes/s1-inpainting.md`): Core Image ships NO inpainting filter on
    /// macOS 26.3, so MVP content-aware removal is CI **diffusion fill** — seed the
    /// hole with the surrounding ring's average colour, then repeated
    /// blur-and-reblend passes with shrinking sigma so border colours diffuse
    /// inward. It beats the blur-fill baseline 2–4× and is near-invisible on flat /
    /// gradient / texture backgrounds (the cases users most often clean up). On
    /// structured content (code/web text) NO naive fill reconstructs occluded
    /// structure — that needs a patch-match/ML kernel, deferred post-MVP — but the
    /// fill still leaves NO legible original residue, which is the redaction floor.
    enum EraseFill {
        /// Ring (in OUTPUT pixels) sampled OUTSIDE the region to seed the fill.
        static let ringInset: Double = 12
        /// Diffusion sigmas (OUTPUT pixels), large→small, applied in order. Scaled
        /// up for big regions so the seed colour reaches the centre.
        static let baseSigmas: [Double] = [60, 40, 25, 15, 8, 4, 2]
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

        case .erase:
            // Content-aware background-matching fill (spike S1 diffusion fill). The
            // region's original pixels never enter the result — the fill is
            // synthesized purely from the SURROUNDING ring, so no legible residue
            // can survive (it is irreversible, like the obscuring styles).
            return erasedPatch(of: source, region: intRegion)
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

    // MARK: Erase (content-aware background-matching fill — spike S1 diffusion fill)

    /// Synthesizes a fill for `region` from the SURROUNDING content only (never the
    /// region's own pixels), so the result blends with the background and leaves no
    /// legible residue. Implements the spike-S1 "diffusion fill": seed the hole with
    /// the ring-average colour, then repeated blur-and-reblend passes with shrinking
    /// sigma so border colours diffuse inward toward the centre.
    ///
    /// Critically, the region's original pixels are masked OUT before any blur, so
    /// the obscured content can never bleed into the output — this is what makes
    /// erase OCR-defeating (the floor test asserts no original text survives).
    private static func erasedPatch(of source: CGImage, region: CGRect) -> CGImage? {
        let full = CGRect(x: 0, y: 0, width: source.width, height: source.height)
        let input = CIImage(cgImage: source)

        // 1) Average colour of a ring JUST OUTSIDE the region (the surrounding
        //    background context). Computed over the ring rect MINUS the region so the
        //    hole's own pixels never contribute to the seed colour.
        let ring = region.insetBy(dx: -EraseFill.ringInset, dy: -EraseFill.ringInset).intersection(full)
        let seedColor = ringAverageColor(of: input, ring: ring, hole: region) ?? neutralSeed
        let seed = CIImage(color: seedColor).cropped(to: full)

        // 2) Background outside the hole = the real surrounding pixels; inside the
        //    hole = the seed colour. The original hole pixels are discarded here.
        let holeMask = mask(for: region, in: full)
        guard var current = blend(foreground: seed, background: input, mask: holeMask) else { return nil }

        // 3) Diffuse the surrounding colour inward. Each pass blurs the whole image
        //    (clamped so edges stay full-strength), then re-blends so OUTSIDE the
        //    hole snaps back to the true surrounding pixels and only the hole keeps
        //    the diffused colour. Sigmas scale with region size so the fill reaches
        //    the centre of large regions.
        let span = max(region.width, region.height)
        let sigmaScale = max(1, span / 240)
        for baseSigma in EraseFill.baseSigmas {
            let sigma = baseSigma * Double(sigmaScale)
            let blurred = current.clampedToExtent()
                .applyingGaussianBlur(sigma: sigma)
                .cropped(to: full)
            guard let reblended = blend(foreground: blurred, background: input, mask: holeMask) else { return nil }
            current = reblended
        }

        let result = current.cropped(to: region)
        return ciContext.createCGImage(result, from: region, format: .RGBA8, colorSpace: RenderColorSpace.sRGB)
    }

    /// Neutral mid-grey used only when the ring average cannot be computed (e.g. a
    /// region covering the entire image with no surrounding ring). Still leaks
    /// nothing about the original content.
    private static let neutralSeed = CIColor(red: 0.5, green: 0.5, blue: 0.5)

    /// Mean colour of `ring` EXCLUDING `hole`, as a flat `CIColor`. Returns nil when
    /// the ring has no area outside the hole to sample.
    private static func ringAverageColor(of image: CIImage, ring: CGRect, hole: CGRect) -> CIColor? {
        guard ring.width >= 1, ring.height >= 1 else { return nil }
        // Sample only the four border bands of the ring (the parts OUTSIDE the hole)
        // by averaging the ring then the hole and removing the hole's contribution is
        // fiddly; instead average each present border band and mean those. This keeps
        // the hole's pixels entirely out of the seed.
        var samples: [CIColor] = []
        let bands: [CGRect] = [
            CGRect(x: ring.minX, y: hole.maxY, width: ring.width, height: ring.maxY - hole.maxY), // top
            CGRect(x: ring.minX, y: ring.minY, width: ring.width, height: hole.minY - ring.minY), // bottom
            CGRect(x: ring.minX, y: hole.minY, width: hole.minX - ring.minX, height: hole.height), // left
            CGRect(x: hole.maxX, y: hole.minY, width: ring.maxX - hole.maxX, height: hole.height), // right
        ]
        for band in bands where band.width >= 1 && band.height >= 1 {
            if let color = averageColor(of: image, in: band.integral) { samples.append(color) }
        }
        guard !samples.isEmpty else { return nil }
        let n = Double(samples.count)
        return CIColor(
            red: samples.map(\.red).reduce(0, +) / n,
            green: samples.map(\.green).reduce(0, +) / n,
            blue: samples.map(\.blue).reduce(0, +) / n
        )
    }

    /// Average colour of `rect` via CIAreaAverage, read back as a `CIColor`.
    private static func averageColor(of image: CIImage, in rect: CGRect) -> CIColor? {
        guard rect.width >= 1, rect.height >= 1,
              let filter = CIFilter(name: "CIAreaAverage") else { return nil }
        filter.setValue(image.cropped(to: rect), forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: rect), forKey: kCIInputExtentKey)
        guard let output = filter.outputImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            output,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: RenderColorSpace.sRGB
        )
        return CIColor(
            red: CGFloat(pixel[0]) / 255,
            green: CGFloat(pixel[1]) / 255,
            blue: CGFloat(pixel[2]) / 255
        )
    }

    /// White inside `region`, black elsewhere — the mask selecting the hole.
    private static func mask(for region: CGRect, in full: CGRect) -> CIImage {
        CIImage(color: .white).cropped(to: region)
            .composited(over: CIImage(color: .black).cropped(to: full))
    }

    /// `foreground` where the mask is white, `background` where it is black.
    private static func blend(foreground: CIImage, background: CIImage, mask: CIImage) -> CIImage? {
        guard let filter = CIFilter(name: "CIBlendWithMask") else { return nil }
        filter.setValue(foreground, forKey: kCIInputImageKey)
        filter.setValue(background, forKey: kCIInputBackgroundImageKey)
        filter.setValue(mask, forKey: kCIInputMaskImageKey)
        return filter.outputImage
    }
}
