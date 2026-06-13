import CoreGraphics
import Foundation

/// One decoded machine-readable code (QR or barcode) found in a region (task 8.3,
/// spec: "QR code detection"). Surfaced as a *distinct* toast action — PRODUCT
/// LAW: a QR payload MUST NOT silently replace the recognized text on the
/// clipboard (see `OCRPipeline`).
public struct DetectedCode: Hashable, Sendable {
    /// Symbology family. String-backed so new symbologies don't break the
    /// portable model; the app maps these from `VNBarcodeSymbology`.
    public var symbology: String
    /// The decoded payload string (e.g. a URL, vCard, or arbitrary text).
    public var payload: String
    /// Normalized bounding box (Vision convention: bottom-left origin).
    public var boundingBox: NormalizedRect

    public init(symbology: String, payload: String, boundingBox: NormalizedRect) {
        self.symbology = symbology
        self.payload = payload
        self.boundingBox = boundingBox
    }

    /// The payload as an openable URL when it is one (toast "open" action).
    /// Returns nil for non-URL payloads — never fabricated. Requires either a
    /// recognized openable scheme or a `scheme://authority` shape, so structured
    /// payloads (vCard, plain text with a stray colon) are NOT mistaken for URLs.
    public var urlPayload: URL? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        // Reject multi-line / structured payloads outright.
        guard !trimmed.contains("\n"), let url = URL(string: trimmed) else { return nil }
        let scheme = url.scheme?.lowercased()
        let openableSchemes: Set = ["http", "https", "mailto", "tel", "sms", "geo", "ftp"]
        if let scheme, openableSchemes.contains(scheme) { return url }
        // Otherwise only treat as a URL if it has an explicit authority.
        if url.host != nil, trimmed.contains("://") { return url }
        return nil
    }
}

/// Seam between the OCR pipeline and the OS barcode detector. Real impl is
/// `VNDetectBarcodesRequest`-backed; tests use a deterministic fake so the
/// "QR alongside text" product law is verified without rendering a real QR.
public protocol BarcodeDetecting: Sendable {
    func detectCodes(in image: CGImage) throws -> [DetectedCode]
}
