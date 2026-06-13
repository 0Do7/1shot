import CoreGraphics
import Foundation
import Testing
@testable import OneShotOCR

// Task 8.3 — pipeline assembly + product laws. Deterministic via fakes.

private func code(_ payload: String, symbology: String = "QR") -> DetectedCode {
    DetectedCode(
        symbology: symbology,
        payload: payload,
        boundingBox: NormalizedRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)
    )
}

private func pipeline(
    text: RecognizedText = RecognizedText(),
    codes: [DetectedCode] = []
) -> OCRPipeline {
    OCRPipeline(
        recognizer: FakeTextRecognizer(text),
        barcodeDetector: FakeBarcodeDetector(codes)
    )
}

/// Spec scenario: "QR code decoded from region" (QR-only → payload on clipboard).
@Test func qrCodeDecodedFromRegion() throws {
    let sut = pipeline(text: RecognizedText(), codes: [code("https://example.com/qr")])
    let result = try sut.run(on: blankImage(), mode: .preserveLayout)

    #expect(result.clipboardText == "https://example.com/qr") // payload on clipboard
    #expect(result.codes.count == 1)
    #expect(result.codes[0].urlPayload?.absoluteString == "https://example.com/qr") // open action
    #expect(!result.isEmpty)
}

/// Spec scenario: "Region with both text and QR code" — PRODUCT LAW: QR never
/// silently replaces the text on the clipboard.
@Test func regionWithBothTextAndQRCode() throws {
    let text = RecognizedText(lines: [
        line("Read the manual carefully", left: 0.1, top: 0.9),
        line("before getting started.", left: 0.1, top: 0.82),
    ])
    let sut = pipeline(text: text, codes: [code("https://example.com/secret")])
    let result = try sut.run(on: blankImage(), mode: .mergeLines)

    // Clipboard receives the recognized TEXT, not the QR payload.
    #expect(result.clipboardText == "Read the manual carefully before getting started.")
    #expect(result.clipboardText?.contains("example.com/secret") == false)
    // QR offered as a distinct surface.
    #expect(result.codes.map(\.payload) == ["https://example.com/secret"])
}

/// Spec scenario: "No text found" — honest empty result, clipboard untouched.
@Test func noTextFound() throws {
    let sut = pipeline(text: RecognizedText(), codes: [])
    let result = try sut.run(on: blankImage(), mode: .preserveLayout)

    #expect(result.clipboardText == nil) // app leaves clipboard unchanged
    #expect(result.isEmpty)
    #expect(result.codes.isEmpty)
}

/// Spec scenario: "Low-confidence text still delivered" — never suppressed.
@Test func lowConfidenceTextStillDelivered() throws {
    let text = RecognizedText(lines: [
        line("stylized hard to read", left: 0.1, top: 0.9, confidence: 0.18),
    ])
    let sut = pipeline(text: text, codes: [])
    let result = try sut.run(on: blankImage(), mode: .rawLines)

    #expect(result.clipboardText == "stylized hard to read") // delivered
    #expect(result.isLowConfidence()) // surfaced as low-confidence
    #expect(!result.isEmpty)
}

/// Spec scenario: "URL in captured text is actionable" — link surfaced AND the
/// URL remains verbatim in the clipboard string.
@Test func urlInClipboardTextRemainsVerbatim() throws {
    let text = RecognizedText(lines: [
        line("Visit https://example.com/docs now", left: 0.1, top: 0.9),
    ])
    let sut = pipeline(text: text, codes: [])
    let result = try sut.run(on: blankImage(), mode: .rawLines)

    #expect(result.clipboardText?.contains("https://example.com/docs") == true)
    #expect(result.links.map(\.value) == ["https://example.com/docs"])
}

/// The clipboard text IS the toast preview content (spec: "Toast reveals a bad
/// recognition before paste" — preview equals exact clipboard text).
@Test func clipboardTextIsExactToastPreviewContent() throws {
    let text = RecognizedText(lines: [
        line("rnistake here", left: 0.1, top: 0.9), // a plausible OCR error
    ])
    let result = try pipeline(text: text).run(on: blankImage(), mode: .rawLines)
    // There is exactly one string; preview and clipboard cannot diverge.
    #expect(result.clipboardText == "rnistake here")
}

/// Switching layout mode from the toast re-derives clipboard text WITHOUT changing
/// the QR surface (spec: switchable from the toast; QR stays distinct).
@Test func reformat_changesTextButPreservesCodeSurface() throws {
    let text = RecognizedText(lines: [
        line("line one wraps", left: 0.1, top: 0.9),
        line("onto line two", left: 0.1, top: 0.84),
    ])
    let sut = pipeline(text: text, codes: [code("PAYLOAD")])
    let raw = try sut.run(on: blankImage(), mode: .rawLines)
    #expect(raw.clipboardText == "line one wraps\nonto line two")

    let merged = sut.reformat(raw, to: .mergeLines)
    #expect(merged.clipboardText == "line one wraps onto line two")
    #expect(merged.codes == raw.codes) // QR surface unchanged across reformat
}

/// A barcode-detection failure must not sink the whole capture — text still wins.
@Test func barcodeFailureDoesNotSinkTextRecognition() throws {
    let text = RecognizedText(lines: [line("recognized fine", left: 0.1, top: 0.9)])
    let sut = OCRPipeline(
        recognizer: FakeTextRecognizer(text),
        barcodeDetector: FakeBarcodeDetector(error: .recognitionFailed("boom"))
    )
    let result = try sut.run(on: blankImage(), mode: .rawLines)
    #expect(result.clipboardText == "recognized fine")
    #expect(result.codes.isEmpty)
}

/// A non-URL QR payload exposes no open target (urlPayload never fabricated).
@Test func nonUrlQrPayloadHasNoOpenTarget() throws {
    let result = try pipeline(codes: [code("BEGIN:VCARD\nFN:Jane")]).run(on: blankImage(), mode: .rawLines)
    #expect(result.clipboardText == "BEGIN:VCARD\nFN:Jane") // still copied
    #expect(result.codes[0].urlPayload == nil) // no fabricated open action
}
