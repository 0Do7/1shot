import Foundation

/// Capture context a template renders against (task 2.7, spec:output-destinations
/// "Filename templates"). Capture type is a string here; the typed capture enum
/// lives in OneShotCapture (design D2) and stringifies at the boundary.
public struct TemplateContext: Sendable {
    public var date: Date
    public var timeZone: TimeZone
    public var captureType: String?
    public var appName: String?
    public var windowTitle: String?
    /// Sequential counter, managed by the caller (e.g. per-day from settings).
    public var counter: Int
    /// The Library auto-name (AutoNamer output), when available.
    public var autoName: String?

    public init(
        date: Date,
        timeZone: TimeZone = .current,
        captureType: String? = nil,
        appName: String? = nil,
        windowTitle: String? = nil,
        counter: Int = 1,
        autoName: String? = nil
    ) {
        self.date = date
        self.timeZone = timeZone
        self.captureType = captureType
        self.appName = appName
        self.windowTitle = windowTitle
        self.counter = counter
        self.autoName = autoName
    }
}

/// Renders user-editable filename templates. Token set is the spec minimum:
/// `{date}` `{time}` `{type}` `{app}` `{title}` `{counter}` `{autoname}`.
/// Unknown tokens render literally so the live preview exposes typos instead
/// of hiding them. Output is sanitized for macOS AND Windows-portable
/// filesystems; collision suffixing happens at write time (FileDestination).
public enum FilenameTemplate {
    public static let defaultTemplate = "{autoname}"
    /// Conservative cross-filesystem cap (bytes are what HFS+/APFS limit, but
    /// 120 characters keeps us safely under 255 bytes even in UTF-8 worst cases).
    public static let maxLength = 120

    public static let knownTokens = ["date", "time", "type", "app", "title", "counter", "autoname"]

    public static func render(_ template: String, context: TemplateContext) -> String {
        var rendered = template
        for (token, value) in values(for: context) {
            rendered = rendered.replacingOccurrences(of: "{\(token)}", with: value)
        }
        return sanitize(rendered, fallbackDate: context.date, timeZone: context.timeZone)
    }

    private static func values(for context: TemplateContext) -> [(String, String)] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = context.timeZone

        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.string(from: context.date)
        // Dots, not colons — colons are reserved (and macOS screenshot convention).
        formatter.dateFormat = "HH.mm.ss"
        let time = formatter.string(from: context.date)

        return [
            ("date", date),
            ("time", time),
            ("type", context.captureType ?? ""),
            ("app", context.appName ?? ""),
            ("title", context.windowTitle ?? ""),
            ("counter", String(context.counter)),
            ("autoname", context.autoName ?? ""),
        ]
    }

    /// Strip characters invalid on macOS or Windows (`/ \ : * ? " < > |` and
    /// control characters), collapse separator runs left by empty tokens, trim
    /// edges, clamp length. Never returns an empty string.
    static func sanitize(_ name: String, fallbackDate: Date, timeZone: TimeZone) -> String {
        let reserved = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters)
        var cleaned = String(name.unicodeScalars.map { reserved.contains($0) ? "-" : Character($0) })

        // Empty tokens and reserved-char replacement leave runs like "--" or "- -".
        while cleaned.contains("--") {
            cleaned = cleaned.replacingOccurrences(of: "--", with: "-")
        }
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }
        cleaned = cleaned.replacingOccurrences(of: "- ", with: "-")
        cleaned = cleaned.replacingOccurrences(of: " -", with: "-")
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "-_ ."))

        if cleaned.count > maxLength {
            cleaned = String(cleaned.prefix(maxLength)).trimmingCharacters(in: CharacterSet(charactersIn: "-_ ."))
        }
        guard !cleaned.isEmpty else {
            // All tokens empty and no literals — same fallback family as AutoNamer.
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = timeZone
            formatter.dateFormat = "yyyy-MM-dd-'at'-HH-mm-ss"
            return "capture-\(formatter.string(from: fallbackDate))"
        }
        return cleaned
    }
}
