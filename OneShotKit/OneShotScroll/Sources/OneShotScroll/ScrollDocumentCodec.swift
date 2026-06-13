import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Codable round-trip for the restitch model (task 7.6, spec:scrolling-capture
// "Post-capture restitch ... MUST remain available after the document is saved to
// the Library and reopened"). A `ScrollDocument` is the source segments + seam
// offsets; persisting it means persisting the tiles too. We encode each tile's
// pixels as LOSSLESS PNG via ImageIO (an OS framework, allowed) so the
// full-resolution law survives the round-trip — PNG is byte-exact, never lossy,
// never downscaled. (Library file-format wiring is a later integration task; this
// just guarantees the value type round-trips so that wiring is trivial.)

/// Errors from (de)serializing a `ScrollDocument`'s tile pixels. Honest-failure:
/// a tile that can't be encoded/decoded surfaces a typed error, never silent loss.
public enum ScrollCodecError: Error, Equatable {
    case tileEncodeFailed(tileIndex: Int)
    case tileDecodeFailed(tileIndex: Int)
}

extension ScrollTile: Codable {
    private enum CodingKeys: String, CodingKey {
        case png
        case offset
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let png = try container.decode(Data.self, forKey: .png)
        let offset = try container.decode(Int.self, forKey: .offset)
        guard let image = ScrollImageCodec.decode(png) else {
            throw ScrollCodecError.tileDecodeFailed(tileIndex: 0)
        }
        self.init(image: image, offset: offset)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        guard let png = ScrollImageCodec.encode(image) else {
            throw ScrollCodecError.tileEncodeFailed(tileIndex: 0)
        }
        try container.encode(png, forKey: .png)
        try container.encode(offset, forKey: .offset)
    }
}

extension ScrollDocument: Codable {
    private enum CodingKeys: String, CodingKey {
        case axis
        case tiles
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let axis = try container.decode(ScrollAxis.self, forKey: .axis)
        let tiles = try container.decode([ScrollTile].self, forKey: .tiles)
        self.init(axis: axis, tiles: tiles)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(axis, forKey: .axis)
        try container.encode(tiles, forKey: .tiles)
    }
}

/// Lossless CGImage <-> PNG bytes via ImageIO. PNG keeps every pixel byte-exact at
/// native resolution (no downscale, no lossy quantization), honoring the
/// full-resolution law across a Library save/reopen.
enum ScrollImageCodec {
    static func encode(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data as CFMutableData, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
