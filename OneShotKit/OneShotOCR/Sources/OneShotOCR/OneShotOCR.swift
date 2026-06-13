/// OneShotOCR — on-device Vision text/QR recognition + indent/linebreak
/// post-processing (design D9, spec:ocr-capture). All recognition runs through
/// OS frameworks (Vision/Foundation) on a `CGImage`; no network, no AI/LLM.
///
/// Public surface:
/// - `TextRecognizing` / `VisionTextRecognizer` — text recognition (task 8.1).
/// - `LayoutProcessor` / `LayoutMode` — three layout modes (task 8.2).
/// - `LinkDetector`, `BarcodeDetecting` / `VisionBarcodeDetector` — links & codes.
/// - `OCRPipeline` → `OCRResult` — composition + product laws (task 8.3).
///
/// The hotkey → region → toast UI is the app layer's job, not this package's.
public enum OneShotOCRInfo {
    public static let packageName = "OneShotOCR"
}
