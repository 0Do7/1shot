import CoreGraphics
import Foundation

/// Composes the recognizer, barcode detector, layout post-processing, and link
/// detection into one `OCRResult` (task 8.3, package-testable parts). This is the
/// single place the product laws are enforced, so the app layer only renders.
///
/// Injectable seams (`TextRecognizing`, `BarcodeDetecting`) make the whole
/// pipeline deterministically testable with fakes — no on-image OCR in unit tests.
public struct OCRPipeline: Sendable {
    private let recognizer: any TextRecognizing
    private let barcodeDetector: any BarcodeDetecting

    public init(
        recognizer: any TextRecognizing,
        barcodeDetector: any BarcodeDetecting
    ) {
        self.recognizer = recognizer
        self.barcodeDetector = barcodeDetector
    }

    /// Convenience: the production wiring (Vision recognizer + Vision barcodes).
    public static func live() -> OCRPipeline {
        OCRPipeline(
            recognizer: VisionTextRecognizer(),
            barcodeDetector: VisionBarcodeDetector()
        )
    }

    /// Run OCR + barcode detection over `image` and assemble the result.
    ///
    /// Ordering and laws:
    /// - Recognize text and decode codes independently (both on-device).
    /// - If text exists, `clipboardText` is the layout-formatted text; codes are
    ///   surfaced separately (QR never replaces text).
    /// - If NO text exists but a QR/barcode does, the code payload becomes the
    ///   clipboard text (spec: "decoded URL is placed on the clipboard" for a
    ///   QR-only region) while still being offered as an open action.
    /// - If neither exists, `clipboardText` is nil (honest empty result).
    public func run(
        on image: CGImage,
        mode: LayoutMode,
        options: RecognitionOptions = .default
    ) throws -> OCRResult {
        let recognized = try recognizer.recognizeText(in: image, options: options)
        // Barcode detection must not sink the whole capture if it errors; text is
        // the primary product. Treat a barcode failure as "no codes".
        let codes = (try? barcodeDetector.detectCodes(in: image)) ?? []
        return assemble(recognized: recognized, codes: codes, mode: mode)
    }

    /// Pure assembly step — separated so it is unit-testable directly from a
    /// `RecognizedText` + `[DetectedCode]` without any image. The app re-runs this
    /// (via `reformat`) when the user switches layout mode from the toast.
    public func assemble(
        recognized: RecognizedText,
        codes: [DetectedCode],
        mode: LayoutMode
    ) -> OCRResult {
        let formatted = LayoutProcessor.format(recognized, mode: mode)
        let hasText = !formatted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        let clipboardText: String? = if hasText {
            formatted
        } else if let firstCode = codes.first {
            // QR-only region: payload becomes the clipboard text (spec scenario).
            firstCode.payload
        } else {
            nil // honest empty result
        }

        let links = LinkDetector.detectLinks(in: formatted)

        return OCRResult(
            clipboardText: clipboardText,
            recognized: recognized,
            layoutMode: mode,
            links: links,
            codes: codes
        )
    }

    /// Re-derive a result under a new layout mode from an existing one, without
    /// re-running recognition (toast "switch layout mode" affordance). The QR
    /// codes carry over untouched — switching layout never changes the QR surface.
    public func reformat(_ result: OCRResult, to mode: LayoutMode) -> OCRResult {
        assemble(recognized: result.recognized, codes: result.codes, mode: mode)
    }
}
