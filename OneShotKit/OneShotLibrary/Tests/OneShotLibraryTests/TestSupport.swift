import CoreGraphics
import Foundation
import OneShotOCR
@testable import OneShotLibrary

// MARK: - Deterministic fake recognizer (never real Vision)

/// In-memory recognizer: returns seeded lines, or throws a seeded error to exercise
/// per-item OCR failure isolation. Keeps indexing tests deterministic — no on-image
/// OCR, no screen-recording permission, no flakiness.
struct FakeTextRecognizer: TextRecognizing {
    var result: RecognizedText
    var error: RecognitionError?

    init(_ result: RecognizedText = RecognizedText(), error: RecognitionError? = nil) {
        self.result = result
        self.error = error
    }

    /// Seed from plain text — one line per `\n`-split segment.
    init(text: String) {
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { RecognizedTextLine(
                text: String($0),
                boundingBox: .init(x: 0, y: 0, width: 1, height: 0.05),
                confidence: 0.95
            ) }
        result = RecognizedText(lines: lines)
        error = nil
    }

    func recognizeText(in _: CGImage, options _: RecognitionOptions) throws -> RecognizedText {
        if let error { throw error }
        return result
    }
}

// MARK: - Image stand-in

/// A tiny blank image. The fake recognizer never inspects it; an image arg is only
/// structurally required by the pipeline signature.
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

// MARK: - Fixed clock

/// A deterministic reference instant so timestamp-derived names and date filters
/// are reproducible across runs.
let fixedNow = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14T22:13:20Z
