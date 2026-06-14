import Foundation

/// The complete, package-level outcome of one OCR capture (task 8.3, the
/// package-testable parts). The app layer renders the toast and writes the
/// clipboard from this value; it carries everything needed to honor the spec
/// laws without the package touching any UI.
///
/// Product laws encoded here:
/// - **Honest failure**: when nothing was recognized, `clipboardText` is nil and
///   `isEmpty` is true — the app states "no text found" and does NOT modify the
///   clipboard.
/// - **QR never silently replaces text**: `codes` is a *separate* field. When
///   text exists, `clipboardText` is the text; QR payloads are offered as
///   distinct actions and never swapped into the clipboard automatically.
/// - **Low-confidence still delivered**: low-confidence text still populates
///   `clipboardText`; confidence is surfaced via `averageConfidence`, never used
///   to suppress.
public struct OCRResult: Hashable, Sendable {
    /// The exact plain-text string to place on the clipboard, or nil when there
    /// is nothing to write (honest empty result — clipboard left untouched).
    /// When non-nil this is ALSO the exact toast preview content (spec: the
    /// preview is the exact clipboard text, so a bad recognition is visible).
    public var clipboardText: String?

    /// The recognized lines (with confidence/geometry) before layout formatting —
    /// retained so the app can re-format on a layout-mode switch from the toast.
    public var recognized: RecognizedText

    /// The layout mode used to produce `clipboardText`.
    public var layoutMode: LayoutMode

    /// URLs/emails found in the recognized text. Verbatim copies remain inside
    /// `clipboardText`; these are the actionable toast items.
    public var links: [DetectedLink]

    /// Decoded QR/barcodes. A SEPARATE surface — never folded into `clipboardText`.
    public var codes: [DetectedCode]

    public init(
        clipboardText: String?,
        recognized: RecognizedText,
        layoutMode: LayoutMode,
        links: [DetectedLink],
        codes: [DetectedCode]
    ) {
        self.clipboardText = clipboardText
        self.recognized = recognized
        self.layoutMode = layoutMode
        self.links = links
        self.codes = codes
    }

    /// True when there is neither text nor any decoded code — the app shows
    /// "no text found" and leaves the clipboard unchanged.
    public var isEmpty: Bool {
        clipboardText == nil && codes.isEmpty
    }

    /// True when text was recognized but with low mean confidence. Drives a toast
    /// badge only; the text is delivered regardless (spec: never suppressed).
    public func isLowConfidence(threshold: Double = 0.5) -> Bool {
        guard let average = recognized.averageConfidence else { return false }
        return average < threshold
    }

    /// Average recognition confidence, surfaced for the toast. Nil when empty.
    public var averageConfidence: Double? {
        recognized.averageConfidence
    }
}
