import CoreGraphics
import Foundation
import Vision

/// Real `VNDetectBarcodesRequest`-backed QR/barcode detector (task 8.3).
/// On-device, no network (Vision is an OS framework). Headless: input is a
/// `CGImage`, so it runs in tests and needs no screen-recording permission.
///
/// Stateless value type; `Sendable` (holds no mutable state).
public struct VisionBarcodeDetector: BarcodeDetecting {
    public init() {}

    public func detectCodes(in image: CGImage) throws -> [DetectedCode] {
        let request = VNDetectBarcodesRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw RecognitionError.recognitionFailed(error.localizedDescription)
        }

        let observations = request.results ?? []
        return observations.compactMap { observation in
            guard let payload = observation.payloadStringValue else { return nil }
            return DetectedCode(
                symbology: observation.symbology.rawValue,
                payload: payload,
                boundingBox: NormalizedRect(
                    x: Double(observation.boundingBox.origin.x),
                    y: Double(observation.boundingBox.origin.y),
                    width: Double(observation.boundingBox.size.width),
                    height: Double(observation.boundingBox.size.height)
                )
            )
        }
    }
}
