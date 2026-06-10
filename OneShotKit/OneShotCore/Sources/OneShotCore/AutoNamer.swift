import Foundation

/// Raw signals available when a capture is indexed (task 2.4, spec:library
/// "Heuristic auto-naming without AI"). Absent fields stay nil — never fabricated.
public struct CaptureNamingSignals: Sendable {
    public var appName: String?
    public var windowTitle: String?
    /// Recognized text from the capture (OneShotOCR output), if any.
    public var ocrText: String?
    public var capturedAt: Date
    /// Injectable for deterministic tests; fallback names are local-time based.
    public var timeZone: TimeZone

    public init(
        appName: String? = nil,
        windowTitle: String? = nil,
        ocrText: String? = nil,
        capturedAt: Date,
        timeZone: TimeZone = .current
    ) {
        self.appName = appName
        self.windowTitle = windowTitle
        self.ocrText = ocrText
        self.capturedAt = capturedAt
        self.timeZone = timeZone
    }
}

/// Purely heuristic filename generation: app + window title + top OCR tokens →
/// filesystem-safe kebab slug. No LLM, no generative model, ever — the "NO AI"
/// constraint is a locked product decision, not a placeholder.
///
/// This type is pure; manual-rename stickiness ("a user's rename is never
/// overwritten by re-indexing") is enforced by the Library store, which simply
/// never calls this for items whose name the user has set.
public enum AutoNamer {
    /// Maximum slug length in characters (truncated at token boundaries).
    public static let maxLength = 60
    private static let maxTitleTokens = 4
    private static let maxOCRTokens = 2

    /// Generate the slug (no path extension). Falls back to a timestamp-based
    /// name when no usable signal exists — never empty.
    public static func slug(for signals: CaptureNamingSignals) -> String {
        var tokens: [String] = []

        // App name leads when it carries signal (browsers and shells are chrome,
        // not content — the spec example names the *site*, not "safari").
        if let app = signals.appName {
            let appTokens = tokenize(app).filter { !Self.chromeApps.contains($0) }
            tokens.append(contentsOf: appTokens.prefix(2))
        }

        if let title = signals.windowTitle {
            tokens.append(contentsOf: titleTokens(from: title, appTokens: tokens))
        }

        let ocrTokens = topOCRTokens(from: signals.ocrText, excluding: tokens)
        tokens.append(contentsOf: ocrTokens)

        tokens = dedupe(tokens)
        guard !tokens.isEmpty else {
            return timestampSlug(for: signals.capturedAt, in: signals.timeZone)
        }

        var slug = ""
        for token in tokens {
            let candidate = slug.isEmpty ? token : "\(slug)-\(token)"
            if candidate.count > maxLength { break }
            slug = candidate
        }
        return slug.isEmpty ? timestampSlug(for: signals.capturedAt, in: signals.timeZone) : slug
    }

    /// Deterministic collision resolution: `name`, `name-2`, `name-3`, …
    /// `isTaken` is the caller's view of existing names (case-insensitive
    /// comparison is the caller's responsibility if its filesystem needs it).
    public static func resolvingCollision(of slug: String, isTaken: (String) -> Bool) -> String {
        guard isTaken(slug) else { return slug }
        var suffix = 2
        while isTaken("\(slug)-\(suffix)") {
            suffix += 1
        }
        return "\(slug)-\(suffix)"
    }

    // MARK: Title handling

    /// Split a window title into segments on common separators, drop segments
    /// that are pure app chrome, then tokenize the rest in reading order.
    private static func titleTokens(from title: String, appTokens: [String]) -> [String] {
        let separators = ["—", "–", "|", "·", "•", "::", " - ", ": "]
        var segments = [title]
        for separator in separators {
            segments = segments.flatMap { $0.components(separatedBy: separator) }
        }
        let appSet = Set(appTokens)
        var result: [String] = []
        for segment in segments {
            let words = tokenize(segment)
            // A segment that is nothing but chrome/app words names the app, not the content.
            guard words.contains(where: { !chromeApps.contains($0) && !appSet.contains($0) }) else { continue }
            result.append(contentsOf: words.filter { !chromeApps.contains($0) })
        }
        return Array(result.prefix(maxTitleTokens))
    }

    // MARK: OCR handling

    /// Highest-signal OCR tokens: frequent, distinctive (≥4 chars, not a
    /// stopword, not numeric), ranked by frequency then first appearance.
    private static func topOCRTokens(from text: String?, excluding chosen: [String]) -> [String] {
        guard let text, !text.isEmpty else { return [] }
        let chosenSet = Set(chosen)
        var frequency: [String: Int] = [:]
        var firstIndex: [String: Int] = [:]
        for (index, token) in tokenize(text).enumerated() {
            guard token.count >= 4, !chosenSet.contains(token),
                  // near-duplicates of already-chosen tokens add noise, not signal
                  !chosen.contains(where: { $0.contains(token) || token.contains($0) })
            else { continue }
            frequency[token, default: 0] += 1
            if firstIndex[token] == nil { firstIndex[token] = index }
        }
        return frequency.keys
            .sorted {
                if frequency[$0] != frequency[$1] { return frequency[$0]! > frequency[$1]! }
                return firstIndex[$0]! < firstIndex[$1]!
            }
            .prefix(maxOCRTokens)
            .map(\.self)
    }

    // MARK: Tokenizing & sanitizing

    /// Lowercased, diacritic-stripped, ASCII-safe word tokens; stopwords and
    /// pure numbers removed. Non-Latin scripts that survive transliteration are
    /// kept; anything unrepresentable is dropped (fallback covers the rest).
    private static func tokenize(_ text: String) -> [String] {
        let folded = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        let parts = folded.components(separatedBy: allowedCharacters.inverted)
        return parts.filter { token in
            !token.isEmpty
                && token.count >= 2
                && !stopwords.contains(token)
                && token.rangeOfCharacter(from: .decimalDigits.inverted) != nil // not numbers-only
        }
    }

    private static let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789")

    private static func dedupe(_ tokens: [String]) -> [String] {
        var seen = Set<String>()
        return tokens.filter { seen.insert($0).inserted }
    }

    private static func timestampSlug(for date: Date, in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd-'at'-HH-mm-ss"
        return "capture-\(formatter.string(from: date))"
    }

    /// Apps whose names are chrome, not content (the capture is *of* something
    /// inside them). Lowercase tokens, compared post-tokenization.
    private static let chromeApps: Set<String> = [
        "safari", "chrome", "google", "firefox", "arc", "edge", "microsoft",
        "brave", "opera", "finder", "preview", "quicklook",
    ]

    /// English + UI-noise stopwords. Deliberately small: over-filtering destroys
    /// signal, and the fallback handles empty results.
    private static let stopwords: Set<String> = [
        "a", "an", "and", "are", "as", "at", "be", "by", "for", "from", "has",
        "in", "is", "it", "its", "of", "on", "or", "that", "the", "this", "to",
        "was", "were", "will", "with", "you", "your",
        "untitled", "window", "tab", "new", "page", "document", "screenshot",
        "home", "dashboard", "app", "application",
        "com", "www", "http", "https", "html",
    ]
}
