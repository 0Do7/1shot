import CoreGraphics
import Foundation

/// A normalized rectangle in Vision's coordinate convention: origin bottom-left,
/// axes in [0, 1] of the source image. Kept local to OneShotOCR (a recognition
/// detail) rather than reusing OneShotCore's pixel/logical rects, which model the
/// *capture* coordinate spaces, not Vision normalized output.
///
/// Stored as a value type so recognized layout is `Sendable` and deterministically
/// testable without any image present.
public struct NormalizedRect: Hashable, Sendable {
    /// Distance from the left edge, in [0, 1].
    public var x: Double
    /// Distance from the **bottom** edge, in [0, 1] (Vision convention).
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var minX: Double {
        x
    }

    public var maxX: Double {
        x + width
    }

    /// Top edge measured from the bottom — larger y is higher on screen.
    public var maxY: Double {
        y + height
    }

    public var midY: Double {
        y + height / 2
    }
}

/// One recognized line of text with its position and the recognizer's confidence.
/// The unit of layout post-processing (task 8.2) and the honest-confidence surface
/// (spec: "Low-confidence text still delivered").
public struct RecognizedTextLine: Hashable, Sendable {
    /// The recognized string for this line, exactly as the recognizer returned it.
    public var text: String
    /// Normalized bounding box (Vision convention: bottom-left origin).
    public var boundingBox: NormalizedRect
    /// Recognizer confidence in [0, 1]. Surfaced, never used to silently drop text.
    public var confidence: Double

    public init(text: String, boundingBox: NormalizedRect, confidence: Double) {
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}

/// The raw output of text recognition over one image: the lines (top-to-bottom,
/// reading order) plus the languages the recognizer was configured to find.
/// Layout/link/clipboard logic all derive from this value, so they are testable
/// against a fake recognizer with zero Vision involvement.
public struct RecognizedText: Hashable, Sendable {
    public var lines: [RecognizedTextLine]
    /// BCP-47 language identifiers actually applied for the run (e.g. "en-US",
    /// "de-DE"). Empty when the recognizer auto-detected without reporting.
    public var languages: [String]

    public init(lines: [RecognizedTextLine] = [], languages: [String] = []) {
        self.lines = lines
        self.languages = languages
    }

    /// Honest-failure helper: true when no line carried any non-whitespace text.
    public var isEmpty: Bool {
        lines.allSatisfy { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// Mean confidence across non-empty lines, or nil when there are none.
    /// Used only for surfacing ("low-confidence" badge), never for suppression.
    public var averageConfidence: Double? {
        let scored = lines
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(\.confidence)
        guard !scored.isEmpty else { return nil }
        return scored.reduce(0, +) / Double(scored.count)
    }
}

/// How aggressively the recognizer should trade speed for accuracy. Maps to
/// `VNRequestTextRecognitionLevel`; defaults to accurate (OCR-capture is a
/// deliberate, one-region action, not a live feed).
public enum RecognitionLevel: Sendable {
    case fast
    case accurate
}

/// Language posture for a recognition run (spec: "Automatic language detection").
/// `.automatic` MUST be the default; a manual override exists but is opt-in.
public enum RecognitionLanguages: Hashable, Sendable {
    /// Let the recognizer auto-detect language(s) — the product default.
    case automatic
    /// Force a specific ordered set of BCP-47 identifiers (manual override).
    case explicit([String])
}

/// Options for a single recognition run.
public struct RecognitionOptions: Hashable, Sendable {
    public var languages: RecognitionLanguages
    public var level: RecognitionLevel
    /// Vision's built-in language correction (lexicon-based). On by default;
    /// turning it off can help code/IDs but hurts prose.
    public var usesLanguageCorrection: Bool

    public init(
        languages: RecognitionLanguages = .automatic,
        level: RecognitionLevel = .accurate,
        usesLanguageCorrection: Bool = true
    ) {
        self.languages = languages
        self.level = level
        self.usesLanguageCorrection = usesLanguageCorrection
    }

    public static let `default` = RecognitionOptions()
}

/// Errors a recognizer may surface. "No text found" is **not** an error — it is a
/// valid empty `RecognizedText` (spec law: honest, typed empty result, never
/// garbage and never a thrown failure for the ordinary empty case).
public enum RecognitionError: Error, Equatable, Sendable {
    /// The underlying framework failed (request error). Carries a message for logs.
    case recognitionFailed(String)
}

/// Seam between the OCR pipeline and the OS text recognizer. A real Vision-backed
/// implementation ships in the app; a deterministic fake drives the unit tests so
/// layout/link/QR/clipboard logic is verified without flaky on-image OCR.
///
/// Headless by design: input is a `CGImage`, so recognition needs no
/// screen-recording permission and runs in tests.
public protocol TextRecognizing: Sendable {
    func recognizeText(in image: CGImage, options: RecognitionOptions) throws -> RecognizedText
}
