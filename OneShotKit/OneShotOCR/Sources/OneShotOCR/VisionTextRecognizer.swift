import CoreGraphics
import Foundation
import Vision

/// Real `VNRecognizeTextRequest`-backed recognizer (task 8.1). On-device, no
/// network (Vision is an OS framework — the "no AI/no network" law holds, see
/// design D9). Input is a `CGImage`, so it is screen-recording-permission-free and
/// can be exercised by the tolerant integration tests with a Core Text-rendered
/// image.
///
/// Stateless value type; `Sendable` because it holds no mutable state — each call
/// builds and runs its own request handler.
public struct VisionTextRecognizer: TextRecognizing {
    public init() {}

    public func recognizeText(in image: CGImage, options: RecognitionOptions) throws -> RecognizedText {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = options.level == .accurate ? .accurate : .fast
        request.usesLanguageCorrection = options.usesLanguageCorrection

        // Language posture (spec: automatic is the default; explicit is opt-in).
        switch options.languages {
        case .automatic:
            // VNRecognizeTextRequest auto-detects from its supported set; on the
            // OS versions we target, automatic detection is on when no languages
            // are forced. We leave `recognitionLanguages` unset and ask Vision to
            // include the languages it actually used so we can surface them.
            if #available(macOS 13.0, *) {
                request.automaticallyDetectsLanguage = true
            }
        case let .explicit(identifiers):
            if #available(macOS 13.0, *) {
                request.automaticallyDetectsLanguage = false
            }
            request.recognitionLanguages = identifiers
        }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw RecognitionError.recognitionFailed(error.localizedDescription)
        }

        let observations = request.results ?? []
        let lines: [RecognizedTextLine] = observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return RecognizedTextLine(
                text: candidate.string,
                boundingBox: NormalizedRect(
                    x: Double(observation.boundingBox.origin.x),
                    y: Double(observation.boundingBox.origin.y),
                    width: Double(observation.boundingBox.size.width),
                    height: Double(observation.boundingBox.size.height)
                ),
                confidence: Double(candidate.confidence)
            )
        }

        // Vision returns observations bottom-to-top in normalized space; sort into
        // reading order (top line first) so downstream layout is deterministic.
        let ordered = lines.sorted { $0.boundingBox.midY > $1.boundingBox.midY }

        var languages: [String] = []
        switch options.languages {
        case let .explicit(identifiers):
            languages = identifiers
        case .automatic:
            // Best-effort surfacing of what Vision could use; the recognizer does
            // not report the per-run detected language directly, so we expose the
            // supported set it considered. Empty is acceptable (see RecognizedText).
            languages = (try? request.supportedRecognitionLanguages()) ?? []
        }

        return RecognizedText(lines: ordered, languages: languages)
    }
}
