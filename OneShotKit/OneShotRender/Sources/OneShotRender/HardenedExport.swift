import CoreGraphics
import Foundation
import ImageIO
import OneShotCore
import UniformTypeIdentifiers

// Hardened, non-reversible export (task 6.2, spec:redaction "Hardened,
// non-reversible export"). The flattened CGImage from `AnnotationRasterizer`
// already has every redaction burned destructively into its pixels (task 6.1);
// this layer guarantees the ENCODED artifact carries nothing more than those
// flattened pixels: no EXIF, no GPS, no embedded thumbnail, no alternate
// representation that could leak the original content of a redacted region.
//
// Portability: ImageIO only (allowed by the portability law). No AppKit/NSImage.

/// Errors specific to hardened encoding (separate from `RenderError` so callers
/// can distinguish "this format is not encodable on this OS" from a render fault).
public enum HardenedExportError: Error, Equatable, Sendable {
    /// The OS has no ImageIO encoder for this format (e.g. WebP encode on a macOS
    /// version that only decodes it). Honest, typed failure — never a silent
    /// fallback to a different format that would surprise the user.
    case formatNotEncodable(ImageFormat)
    /// ImageIO refused to finalize the destination.
    case encodeFailed(ImageFormat)
}

/// Metadata-stripped, redaction-safe image encoding for every supported format.
public enum HardenedExport {
    /// JPEG/HEIC are lossy; this is the quality used when none is specified. High
    /// enough to be WYSIWYG, and lossy compression only further destroys any
    /// (already-destroyed) redacted content — it can never recover it.
    public static let defaultLossyQuality: Double = 0.92

    /// Encodes a flattened CGImage to the given format with ALL metadata stripped.
    ///
    /// Hardening guarantees, by construction:
    /// 1. We encode a freshly-rendered CGImage that has no attached EXIF/GPS/IPTC.
    /// 2. We pass an explicit, minimal properties dictionary — no
    ///    `kCGImageDestinationEmbedThumbnail` (so ImageIO embeds no reduced-res
    ///    copy that could leak a pre-redaction thumbnail), and no source-metadata
    ///    copy.
    /// 3. The redaction pixels are already destructive (task 6.1), so no layer,
    ///    channel, or alternate representation holds the original content.
    public static func encode(
        _ image: CGImage,
        format: ImageFormat,
        quality: Double = defaultLossyQuality
    ) throws -> Data {
        let data = NSMutableData()
        let type = format.utType as CFString
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, type, 1, nil) else {
            // No encoder registered for this UTType on this OS.
            throw HardenedExportError.formatNotEncodable(format)
        }

        // Minimal, explicit properties. We deliberately do NOT:
        //   - copy any source image properties (there are none on a rendered CGImage),
        //   - request an embedded thumbnail (kCGImageDestinationEmbedThumbnail),
        //   - set Orientation/GPS/EXIF dictionaries.
        var properties: [CFString: Any] = [
            // Belt-and-suspenders: never embed a thumbnail.
            kCGImageDestinationEmbedThumbnail: false,
        ]
        if format.isLossy {
            properties[kCGImageDestinationLossyCompressionQuality] = max(0, min(1, quality))
        }

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw HardenedExportError.encodeFailed(format)
        }
        return data as Data
    }

    /// Render + hardened-encode a document in one call (the export path other lanes
    /// consume). Redactions are burned destructively in `render`; this strips
    /// metadata on the way out.
    public static func export(
        document: AnnotationDocument,
        images: ImageProvider,
        format: ImageFormat,
        scale: Double? = nil,
        quality: Double = defaultLossyQuality
    ) throws -> Data {
        let image = try AnnotationRasterizer.render(document: document, images: images, scale: scale)
        return try encode(image, format: format, quality: quality)
    }

    /// Whether a format is encodable on this OS right now (some formats decode but
    /// do not encode on every macOS version, e.g. WebP). Lets the UI present only
    /// real options instead of failing at save time.
    public static func isEncodable(_ format: ImageFormat) -> Bool {
        let types = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return types.contains(format.utType)
    }
}

private extension ImageFormat {
    var isLossy: Bool {
        switch self {
        case .jpeg, .heic, .webp: true
        case .png: false
        }
    }
}
