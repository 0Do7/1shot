import CoreGraphics
import Foundation
import ImageIO
import OneShotCore
import UniformTypeIdentifiers

// Image encode/decode via ImageIO only (portable; ImageIO is allowed by the
// portability law). No AppKit NSImage anywhere.

enum ImageCodec {
    /// Decodes encoded image bytes (PNG/JPEG/…) into a CGImage. Used to bring the
    /// base capture and any placed images into the render.
    static func decode(_ data: Data, name: String) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw RenderError.imageDecodeFailed(name)
        }
        return image
    }

    /// Encodes a CGImage to PNG bytes (flatten-on-export). Determinism: PNG is
    /// lossless and we pin no time/metadata, so the same CGImage round-trips to the
    /// same bytes — required for golden stability.
    static func encodePNG(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        let type = UTType.png.identifier as CFString
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, type, 1, nil) else {
            throw RenderError.pngEncodeFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw RenderError.pngEncodeFailed
        }
        return data as Data
    }
}

/// Resolves the encoded bytes for an `ImageReference`. The render core stays
/// portable and storage-agnostic: callers hand it the pixels (e.g. from a
/// `DocumentBundle.images` dictionary) rather than the renderer reaching into the
/// filesystem.
public struct ImageProvider: Sendable {
    private let resolve: @Sendable (String) -> Data?

    public init(_ resolve: @escaping @Sendable (String) -> Data?) {
        self.resolve = resolve
    }

    /// Convenience: back the provider with an in-memory name→bytes map (matches
    /// `DocumentBundle.images`).
    public init(images: [String: Data]) {
        self.init { images[$0] }
    }

    public func data(for reference: ImageReference) -> Data? {
        resolve(reference.fileName)
    }

    func data(forName name: String) -> Data? {
        resolve(name)
    }
}
