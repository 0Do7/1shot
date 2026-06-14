import CoreGraphics
import Foundation
import ImageIO
import OneShotCore
import UniformTypeIdentifiers

/// Encodes a `CGImage` to the bytes of a chosen `ImageFormat` (task 11.3,
/// spec:output-destinations "Export format support" / "File-size-conscious
/// defaults"). Built on ImageIO (`CGImageDestination`) + UniformTypeIdentifiers,
/// driven entirely off Core's `ImageFormat`.
///
/// Honest failure: WebP/HEIC encoder availability is macOS-version dependent.
/// When the running OS can't materialize a `CGImageDestination` for the
/// format's UTType, we throw `EncodingError.formatUnsupportedOnThisOS` rather
/// than crash or silently fall back.
public enum ImageEncoder {
    /// Knobs for a single encode. Lossless formats ignore `quality`.
    public struct Options: Hashable, Sendable {
        /// 0.0…1.0 for lossy formats (JPEG/WebP/HEIC). Clamped on use.
        public var quality: Double
        /// Export Retina captures at 1x logical resolution: divide the pixel
        /// dimensions by `scale` using high-quality resampling. Maps to Core's
        /// `OutputPreset.downscaleRetinaTo1x`.
        public var downscaleRetinaTo1x: Bool
        /// Backing-store scale of the source image (e.g. 2.0 on a 2x display).
        /// Only consulted when `downscaleRetinaTo1x` is true.
        public var sourceScale: Double

        public init(
            quality: Double = 0.8,
            downscaleRetinaTo1x: Bool = false,
            sourceScale: Double = 1.0
        ) {
            self.quality = quality
            self.downscaleRetinaTo1x = downscaleRetinaTo1x
            self.sourceScale = sourceScale
        }
    }

    /// Typed encode failures (spec: honest failure — no silent degradation).
    public enum EncodingError: Error, Equatable, Sendable {
        /// ImageIO has no encoder for this format on the running OS version.
        case formatUnsupportedOnThisOS(ImageFormat)
        /// `CGImageDestinationFinalize` reported failure (corrupt/unwritable buffer).
        case encodeFailed(ImageFormat)
        /// High-quality downscale could not produce a context/image.
        case downscaleFailed
    }

    /// Encode `image` to `format`'s bytes. Quality applies to lossy formats;
    /// PNG is always lossless. Strips all metadata (no EXIF GPS / serials /
    /// usernames — spec: "Default export size sanity").
    public static func encode(
        _ image: CGImage,
        format: ImageFormat,
        options: Options = Options()
    ) throws -> Data {
        let source = try downscaledIfNeeded(image, options: options)
        guard let utType = UTType(format.utType) else {
            throw EncodingError.formatUnsupportedOnThisOS(format)
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            utType.identifier as CFString,
            1,
            nil
        ) else {
            // ImageIO refused the UTType → no encoder on this OS version.
            throw EncodingError.formatUnsupportedOnThisOS(format)
        }

        CGImageDestinationAddImage(destination, source, encodeProperties(for: format, options: options) as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw EncodingError.encodeFailed(format)
        }
        return data as Data
    }

    /// Whether the running OS can encode `format` (probe without producing
    /// output) — lets the app hide unavailable formats up front instead of
    /// failing at save time.
    public static func isSupported(_ format: ImageFormat) -> Bool {
        guard let utType = UTType(format.utType) else { return false }
        return CGImageDestinationCreateWithData(
            NSMutableData() as CFMutableData,
            utType.identifier as CFString,
            1,
            nil
        ) != nil
    }

    // MARK: Encode properties

    private static func encodeProperties(for format: ImageFormat, options: Options) -> [CFString: Any] {
        // Strip every metadata family ImageIO would otherwise carry over:
        // EXIF (GPS, timestamps), GPS, TIFF (camera/serial), IPTC. This keeps
        // exports free of location data and hardware/user identifiers.
        var properties: [CFString: Any] = [
            kCGImagePropertyExifDictionary: [CFString: Any](),
            kCGImagePropertyGPSDictionary: [CFString: Any](),
            kCGImagePropertyTIFFDictionary: [CFString: Any](),
            kCGImagePropertyIPTCDictionary: [CFString: Any](),
        ]

        switch format {
        case .png:
            // Lossless; no quality key. (Metadata stripping above is the size win.)
            break
        case .jpeg, .webp, .heic:
            properties[kCGImageDestinationLossyCompressionQuality] = clampedQuality(options.quality)
        }
        return properties
    }

    private static func clampedQuality(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }

    // MARK: Retina → 1x downscale

    /// Divide pixel dimensions by `sourceScale` using high-quality resampling.
    /// Preserves logical pixel dimensions exactly (rounds to the nearest pixel),
    /// so a 400×300pt region captured at 2x (800×600px) becomes 400×300px.
    private static func downscaledIfNeeded(_ image: CGImage, options: Options) throws -> CGImage {
        guard options.downscaleRetinaTo1x, options.sourceScale > 1.0 else { return image }

        let targetWidth = Int((Double(image.width) / options.sourceScale).rounded())
        let targetHeight = Int((Double(image.height) / options.sourceScale).rounded())
        guard targetWidth > 0, targetHeight > 0 else { return image }

        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw EncodingError.downscaleFailed
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        guard let scaled = context.makeImage() else {
            throw EncodingError.downscaleFailed
        }
        return scaled
    }
}
