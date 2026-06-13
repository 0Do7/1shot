import CoreGraphics
import CoreText
import Foundation
@testable import OneShotOCR

// MARK: - Deterministic fakes (drive unit tests without on-image OCR)

/// In-memory recognizer: returns whatever lines the test seeds. Makes layout,
/// link, and clipboard logic deterministic (Vision output on synthetic images is
/// flaky; we don't gamble unit tests on it).
struct FakeTextRecognizer: TextRecognizing {
    var result: RecognizedText
    var error: RecognitionError?

    init(_ result: RecognizedText = RecognizedText(), error: RecognitionError? = nil) {
        self.result = result
        self.error = error
    }

    func recognizeText(in _: CGImage, options _: RecognitionOptions) throws -> RecognizedText {
        if let error { throw error }
        return result
    }
}

/// In-memory barcode detector: returns seeded codes.
struct FakeBarcodeDetector: BarcodeDetecting {
    var codes: [DetectedCode]
    var error: RecognitionError?

    init(_ codes: [DetectedCode] = [], error: RecognitionError? = nil) {
        self.codes = codes
        self.error = error
    }

    func detectCodes(in _: CGImage) throws -> [DetectedCode] {
        if let error { throw error }
        return codes
    }
}

// MARK: - Line builder

/// Build a recognized line from a left edge + baseline, in Vision normalized
/// space (bottom-left origin). `top` is the distance from the bottom of the
/// image to the line's top edge — larger = higher on screen.
func line(
    _ text: String,
    left: Double,
    top: Double,
    width: Double = 0.3,
    height: Double = 0.04,
    confidence: Double = 0.95
) -> RecognizedTextLine {
    RecognizedTextLine(
        text: text,
        boundingBox: NormalizedRect(x: left, y: top - height, width: width, height: height),
        confidence: confidence
    )
}

// MARK: - Real-OCR integration helper

/// A 1×1 white CGImage placeholder (only used where an image arg is structurally
/// required but never inspected — e.g. the fake recognizer path).
func blankImage(width: Int = 4, height: Int = 4) -> CGImage {
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return ctx.makeImage()!
}

/// Render crisp large black text on a white background into a CGImage with Core
/// Graphics + Core Text — the tolerant real-OCR integration fixture. Kept minimal
/// (single big line) so real Vision recognizes it reliably and CI doesn't flake.
func renderedTextImage(
    _ string: String,
    fontSize: CGFloat = 96,
    width: Int = 1200,
    height: Int = 240
) -> CGImage {
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

    let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
    // Use the Core Text attribute keys directly so this helper needs no AppKit.
    let attributes: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorAttributeName: CGColor(red: 0, green: 0, blue: 0, alpha: 1),
    ]
    let attributed = CFAttributedStringCreate(
        kCFAllocatorDefault,
        string as CFString,
        attributes as CFDictionary
    )!
    let lineToDraw = CTLineCreateWithAttributedString(attributed)

    // Center vertically-ish; left-pad a little.
    ctx.textPosition = CGPoint(x: 40, y: CGFloat(height) / 2 - fontSize / 3)
    CTLineDraw(lineToDraw, ctx)

    return ctx.makeImage()!
}
