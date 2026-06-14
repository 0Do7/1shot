import CoreGraphics
import CoreText
import Foundation
import ImageIO
import OneShotCore
import UniformTypeIdentifiers
@testable import OneShotRender

// Synthetic redaction fixtures: a deterministic capture-like CGImage with KNOWN
// strings rendered via CoreText at a typical UI size, so the OCR-defeat test can
// (1) confirm Vision reads the strings on the untouched capture and (2) assert it
// reads NONE of them once the region is redacted and exported (task 6.1).

enum RedactionFixtures {
    static let captureName = "ocr-capture.png"

    /// The strings rendered into the synthetic capture. Distinctive tokens so the
    /// OCR substring check has no chance of incidental matches.
    static let strings: [String] = [
        "PasswordHunter4242",
        "secret-token-ZQW9",
        "user@private.example",
        "Account: 5512-9087-3344",
    ]

    /// Capture geometry (1x; one base-image px == one output px at scale 1).
    static let width = 480
    static let height = 200
    /// Where the text block sits — the region a redaction will cover. Document
    /// coordinates == base-image pixels at scale 1.
    static let textRegion = DocRect(x: 20, y: 30, width: 440, height: 150)

    /// Builds the synthetic capture: light background with the known strings drawn
    /// as crisp black ~12pt text (well within "typical UI size" per the spec).
    static func capturePNG(pointSize: CGFloat = 12) -> Data {
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        // Light, flat background (worst case for redaction — maximum text contrast).
        ctx.setFillColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let font = CTFontCreateUIFontForLanguage(.system, pointSize, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, pointSize, nil)
        let black = CGColor(colorSpace: space, components: [0, 0, 0, 1])!

        // ctx is CG default (bottom-left origin, y-up); draw lines top-to-bottom.
        let lineGap: CGFloat = 34
        let topY = CGFloat(height) - 40
        for (i, string) in strings.enumerated() {
            let attrs: [CFString: Any] = [
                kCTFontAttributeName: font,
                kCTForegroundColorAttributeName: black,
            ]
            let attributed = CFAttributedStringCreate(kCFAllocatorDefault, string as CFString, attrs as CFDictionary)!
            let line = CTLineCreateWithAttributedString(attributed)
            ctx.textPosition = CGPoint(x: 30, y: topY - CGFloat(i) * lineGap)
            CTLineDraw(line, ctx)
        }
        let image = ctx.makeImage()!
        let out = NSMutableData()
        let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, nil)
        _ = CGImageDestinationFinalize(dest)
        return out as Data
    }

    static func provider(pointSize: CGFloat = 12) -> ImageProvider {
        ImageProvider(images: [captureName: capturePNG(pointSize: pointSize)])
    }

    static func baseRef() -> ImageReference {
        ImageReference(fileName: captureName, pixelWidth: width, pixelHeight: height, scale: 1)
    }

    /// A document with one redaction over the full text region.
    static func redactedDocument(
        style: RedactionAnnotation.Style,
        strength: Double
    ) -> AnnotationDocument {
        AnnotationDocument(
            baseImage: baseRef(),
            annotations: [
                .redaction(RedactionAnnotation(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000601")!,
                    rect: textRegion,
                    style: style,
                    strength: strength
                )),
            ]
        )
    }
}
