import Foundation

/// A link or email found inside recognized text (task 8.3, spec: "Link detection
/// in recognized text"). Surfaced as an actionable toast item; the verbatim text
/// also stays in the clipboard string (the spec is explicit on this).
public struct DetectedLink: Hashable, Sendable {
    public enum Kind: Sendable, Hashable {
        case url
        case email
    }

    public var kind: Kind
    /// The exact substring as it appears in the recognized text.
    public var value: String
    /// A normalized destination suitable for opening (https URL or mailto:).
    /// Distinct from `value`, which is preserved verbatim for the clipboard.
    public var openTarget: URL?

    public init(kind: Kind, value: String, openTarget: URL?) {
        self.kind = kind
        self.value = value
        self.openTarget = openTarget
    }
}

/// Detects URLs and email addresses in recognized text with `NSDataDetector`
/// (on-device Foundation; no network). Pure and deterministic over a string, so
/// it is unit-tested directly without any OCR.
public enum LinkDetector {
    public static func detectLinks(in text: String) -> [DetectedLink] {
        guard !text.isEmpty else { return [] }
        let types = NSTextCheckingResult.CheckingType.link.rawValue
        guard let detector = try? NSDataDetector(types: types) else { return [] }

        let nsRange = NSRange(text.startIndex ..< text.endIndex, in: text)
        var results: [DetectedLink] = []
        var seen = Set<String>()

        detector.enumerateMatches(in: text, range: nsRange) { match, _, _ in
            guard let match, let range = Range(match.range, in: text) else { return }
            let value = String(text[range])
            guard let url = match.url else { return }

            let kind: DetectedLink.Kind = url.scheme?.lowercased() == "mailto" ? .email : .url
            // Dedupe on the verbatim substring so the toast doesn't list repeats.
            guard seen.insert(value).inserted else { return }
            results.append(DetectedLink(kind: kind, value: value, openTarget: url))
        }
        return results
    }
}
