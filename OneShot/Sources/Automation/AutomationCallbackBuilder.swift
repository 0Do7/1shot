import Foundation

/// The result an action produces that a success callback can carry back. Kept
/// minimal and stringly-typed because x-callback-url is a string transport; the
/// dispatcher maps engine outputs into one of these before the URL is built.
enum AutomationResult: Equatable {
    /// OCR returned recognized text (spec: "the caller receives … the recognized
    /// text"). Empty string is a valid honest "no text found" result.
    case text(String)
    /// A capture/pin completed and produced a file the caller can reference.
    case file(path: String)
    /// The action completed with nothing to return (toggle, open settings, …).
    case ok
}

/// PURE builder for x-callback-url returns (spec:automation "Caller receives
/// results" / "descriptive error callback"). Given the caller's success/error
/// URLs and an outcome, it produces the URL to open back — appending result or
/// error params WITHOUT clobbering params the caller already put on its callback.
/// No engines, no AppKit: the exact query the caller will receive is unit-tested.
enum AutomationCallbackBuilder {
    /// Standard x-callback-url result key names.
    private static let textKey = "text"
    private static let filePathKey = "filePath"
    private static let errorCodeKey = "errorCode"
    private static let errorMessageKey = "errorMessage"

    /// The success callback to open for `result`, or nil if the caller supplied no
    /// success URL (fire-and-forget). Existing query params on the callback are
    /// preserved (x-callback-url callers commonly thread their own state through).
    static func successURL(for result: AutomationResult, callbacks: AutomationCallbacks) -> URL? {
        guard let base = callbacks.success else { return nil }
        switch result {
        case let .text(text):
            return appending([URLQueryItem(name: textKey, value: text)], to: base)
        case let .file(path):
            return appending([URLQueryItem(name: filePathKey, value: path)], to: base)
        case .ok:
            return base
        }
    }

    /// The error callback to open for `error`, or nil if the caller supplied no
    /// error URL. Always carries the stable `errorCode` plus the human message.
    static func errorURL(for error: AutomationError, callbacks: AutomationCallbacks) -> URL? {
        guard let base = callbacks.error else { return nil }
        return appending(
            [
                URLQueryItem(name: errorCodeKey, value: error.code),
                URLQueryItem(name: errorMessageKey, value: error.message),
            ],
            to: base
        )
    }

    /// Append query items to a URL, preserving any it already carries. Returns the
    /// untouched base if the URL can't be decomposed (degrade, never crash).
    private static func appending(_ items: [URLQueryItem], to base: URL) -> URL {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return base }
        components.queryItems = (components.queryItems ?? []) + items
        return components.url ?? base
    }
}
