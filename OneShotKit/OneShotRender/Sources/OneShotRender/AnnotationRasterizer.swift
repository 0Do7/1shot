import CoreGraphics
import Foundation
import OneShotCore

/// Rasterizes an `AnnotationDocument` (untouched base image + every annotation,
/// in z-order) into pixels. This is the flatten step (design D3): the document is
/// never mutated; rendering happens only here, only at export / preview.
///
/// Portability: CoreGraphics + CoreText + ImageIO only (design D2, CI-enforced).
public enum AnnotationRasterizer {
    /// Renders the document's visible rect at the given scale into a CGImage.
    ///
    /// - Parameters:
    ///   - document: the scene graph to flatten.
    ///   - images: resolves encoded bytes for the base image and any placed images
    ///     (e.g. `ImageProvider(images: bundle.images)`).
    ///   - scale: output pixels per document unit. 1.0 = logical size, 2.0 = Retina.
    ///     Defaults to the base image's capture scale so a 2x capture exports at full
    ///     native density (spec: Retina capture exports at full resolution).
    /// - Returns: the flattened CGImage in fixed sRGB space.
    public static func render(
        document: AnnotationDocument,
        images: ImageProvider,
        scale: Double? = nil
    ) throws -> CGImage {
        let effectiveScale = CGFloat(scale ?? document.baseImage.scale)
        let visible = document.visibleRect

        // Pixel dimensions = visible document size × scale, rounded to whole pixels.
        let pixelWidth = Int((visible.size.width * Double(effectiveScale)).rounded())
        let pixelHeight = Int((visible.size.height * Double(effectiveScale)).rounded())
        guard pixelWidth > 0, pixelHeight > 0 else { throw RenderError.emptyCanvas }

        let context = try BitmapContextFactory.make(
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            scale: effectiveScale
        )
        let surface = RenderSurface(
            context: context,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            scale: effectiveScale,
            visibleRect: visible
        )

        // 1) Canvas background (transparent or solid fill across the full visible rect).
        paintBackground(document: document, surface: surface)

        // 2) Base image at its document position (origin 0,0, native pixel size).
        guard let baseData = images.data(for: document.baseImage) else {
            throw RenderError.missingImage(document.baseImage.fileName)
        }
        let baseImage = try ImageCodec.decode(baseData, name: document.baseImage.fileName)
        let drawer = AnnotationDrawer(surface: surface, images: images, document: document)
        drawer.drawCGImage(baseImage, in: surface.rect(document.baseImageRect))

        // 3) Annotations in z-order (index 0 = bottom).
        for annotation in document.annotations {
            drawer.draw(annotation)
        }

        guard let image = context.makeImage() else {
            throw RenderError.contextCreationFailed
        }
        return image
    }

    /// Flatten-on-export: render and encode to PNG bytes (spec: export flattens
    /// without mutating the document; rendering quality and export fidelity).
    public static func flattenedPNGData(
        document: AnnotationDocument,
        images: ImageProvider,
        scale: Double? = nil
    ) throws -> Data {
        let image = try render(document: document, images: images, scale: scale)
        return try ImageCodec.encodePNG(image)
    }

    // MARK: Background

    private static func paintBackground(document: AnnotationDocument, surface: RenderSurface) {
        let visible = surface.rect(surface.visibleRect)
        switch document.canvas.background {
        case .transparent:
            // Context starts cleared (premultiplied alpha 0); nothing to paint. But
            // if a crop/canvas extends beyond the base image and the user wants a
            // transparent margin, leaving it clear is correct.
            break
        case let .color(color):
            surface.context.saveGState()
            surface.context.setFillColor(color.cgColor)
            surface.context.fill(visible)
            surface.context.restoreGState()
        }
    }
}
