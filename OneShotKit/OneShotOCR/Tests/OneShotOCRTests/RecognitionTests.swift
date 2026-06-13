import CoreGraphics
import Foundation
import Testing
@testable import OneShotOCR

// Task 8.1 — recognition wrapper, language posture, confidence surfacing.
//
// Two flavors:
// - Deterministic (fake recognizer): language carry-through, mixed-script
//   passthrough, confidence math. No on-image OCR → no flake.
// - Tolerant integration (real Vision on a Core Text-rendered image): asserts
//   substring presence, case-insensitive. Minimal & crisp so CI is stable.

// MARK: Options / defaults

// Spec: "A manual language override SHALL exist but MUST default to automatic."
@Test func automaticLanguageIsTheDefault() {
    #expect(RecognitionOptions.default.languages == .automatic)
    #expect(RecognitionOptions().languages == .automatic)
}

/// Confidence math: average ignores blank lines, surfaced not suppressed.
@Test func averageConfidence_ignoresBlankLines() {
    let recognized = RecognizedText(lines: [
        line("a", left: 0.1, top: 0.9, confidence: 0.4),
        line("   ", left: 0.1, top: 0.8, confidence: 0.0), // blank → excluded
        line("b", left: 0.1, top: 0.7, confidence: 0.6),
    ])
    #expect(recognized.averageConfidence == 0.5)
    #expect(RecognizedText().averageConfidence == nil)
}

// MARK: Deterministic language passthrough

/// Spec scenario: "Mixed-language region" — both scripts reach the output. Driven
/// by the fake so it never depends on Vision actually being installed/accurate.
@Test func mixedLanguageRegion() throws {
    let text = RecognizedText(
        lines: [
            line("Hello world", left: 0.1, top: 0.9),
            line("こんにちは世界", left: 0.1, top: 0.8),
        ],
        languages: ["en-US", "ja"]
    )
    let p = OCRPipeline(recognizer: FakeTextRecognizer(text), barcodeDetector: FakeBarcodeDetector())
    let result = try p.run(on: blankImage(), mode: .rawLines)
    #expect(result.clipboardText?.contains("Hello world") == true)
    #expect(result.clipboardText?.contains("こんにちは世界") == true) // both scripts present
}

/// Spec scenario: "Non-English text recognized without configuration" — diacritics
/// preserved verbatim through the pipeline with language left automatic.
@Test func nonEnglishTextRecognizedWithoutConfiguration() throws {
    let german = "Grüße über die Straße"
    let text = RecognizedText(lines: [line(german, left: 0.1, top: 0.9)])
    let p = OCRPipeline(recognizer: FakeTextRecognizer(text), barcodeDetector: FakeBarcodeDetector())
    // No language selection step performed (default options).
    let result = try p.run(on: blankImage(), mode: .rawLines)
    #expect(result.clipboardText == german) // diacritics intact
}

// MARK: Tolerant real-Vision integration (crisp rendered text)

@Test func realVision_recognizesCrispRenderedWord() throws {
    let image = renderedTextImage("Hamburglar")
    let recognized = try VisionTextRecognizer().recognizeText(in: image, options: .default)
    let joined = recognized.lines.map(\.text).joined(separator: " ").lowercased()
    #expect(joined.contains("hamburglar"), "got: '\(joined)'")
    // Honest confidence: a crisp word recognizes with non-trivial confidence.
    #expect((recognized.averageConfidence ?? 0) > 0.3)
}

@Test func realVision_emptyImageYieldsHonestEmptyResult() throws {
    let recognized = try VisionTextRecognizer().recognizeText(in: blankImage(width: 64, height: 64), options: .default)
    #expect(recognized.isEmpty) // typed empty, not garbage, not a throw
    #expect(recognized.averageConfidence == nil)
}

/// Spec scenario: "OCR works offline" — recognition over a CGImage makes no network
/// request by construction (Vision is on-device). This asserts it runs headlessly
/// and returns a result with no network configured in the test environment.
@Test func ocrWorksOffline() throws {
    let image = renderedTextImage("Offline")
    let recognized = try VisionTextRecognizer().recognizeText(in: image, options: .default)
    let joined = recognized.lines.map(\.text).joined().lowercased()
    #expect(joined.contains("offline"), "got: '\(joined)'")
}
