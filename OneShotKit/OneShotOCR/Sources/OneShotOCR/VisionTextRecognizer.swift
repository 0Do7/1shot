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
            // are forced. We leave `recognitionLanguages` unset. Vision does not
            // report which language(s) it actually applied, so the run's
            // `languages` stays empty (see the result assembly below).
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

        let languages: [String] = switch options.languages {
        case let .explicit(identifiers):
            // Explicit mode: these identifiers WERE the ones applied to the run,
            // so they honor RecognizedText.languages' "actually applied" contract.
            identifiers
        case .automatic:
            // Vision does not report the per-run detected language(s), and the
            // supported set (all ~30 recognizable languages) is NOT what was
            // applied — surfacing it would let the toast claim a German-only
            // capture "detected" 30 languages. The contract permits empty when
            // the recognizer auto-detected without reporting, so report empty.
            []
        }

        return RecognizedText(lines: ordered, languages: languages)
    }
}
