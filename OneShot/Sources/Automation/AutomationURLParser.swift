import Foundation
import OneShotCapture

/// The x-callback-url return hooks a caller may attach (spec:automation: "Callbacks
/// (x-callback-url style success/error returns) SHALL be supported so callers can
/// receive results"). Both are optional — a fire-and-forget call supplies neither.
struct AutomationCallbacks: Equatable {
    /// Invoked on success; the action's result is appended as documented params.
    var success: URL?
    /// Invoked on failure with `errorCode` + `errorMessage` params.
    var error: URL?

    var isEmpty: Bool {
        success == nil && error == nil
    }
}

/// A fully-parsed, validated scheme request: the typed action plus its callbacks
/// and an optional per-call confirm override. Produced by `AutomationURLParser`
/// and consumed by the gate + dispatcher; carries no live state, so it is the
/// natural unit for the URL round-trip tests.
struct ParsedAutomationRequest: Equatable {
    var action: AutomationAction
    var callbacks: AutomationCallbacks
    /// `confirm=1` forces a confirmation prompt for this one call even under
    /// silent mode; absent means "use the configured per-action posture".
    var forceConfirm: Bool
}

/// PURE parser/serializer for the versioned `oneshot://` URL surface (§13.5,
/// spec:automation "Documented URL-scheme surface"). No AppKit, no engines — it
/// turns a `URL` into a typed request and back, so the documented round-trip
/// ("behavior matches the published documentation") and the fail-safe path
/// ("Malformed request fails safely … no action and no crash") are unit-tested.
///
/// Surface shape (v1):  `oneshot://<host>[?param=value&…]`
///   host = the action verb; query carries action params + the x-callback hooks.
/// Unknown hosts and out-of-range params throw `AutomationError.malformedRequest`
/// so the dispatcher never guesses.
enum AutomationURLParser {
    /// The registered scheme. Mirrors the bundle id tail so it is unambiguous and
    /// unlikely to collide (`com.sidequests.oneshot` → `oneshot`).
    static let scheme = "oneshot"

    /// The surface version, surfaced in docs and pinnable by callers via
    /// `oneshot://version`. Bumped on any breaking host/param change.
    static let version = 1

    // Reserved query keys (not action params).
    private static let successKey = "x-success"
    private static let errorKey = "x-error"
    private static let confirmKey = "confirm"

    /// Parse a scheme URL into a typed request. Throws `.malformedRequest` for any
    /// unknown action, missing required parameter, or invalid scheme — never
    /// returns a partial/garbage request.
    static func parse(_ url: URL) throws -> ParsedAutomationRequest {
        guard url.scheme?.lowercased() == scheme else {
            throw AutomationError.malformedRequest("unexpected scheme \"\(url.scheme ?? "")\"")
        }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host?.lowercased(), !host.isEmpty
        else {
            throw AutomationError.malformedRequest("missing action")
        }
        let params = queryDictionary(components.queryItems)
        let action = try action(forHost: host, params: params)
        return ParsedAutomationRequest(
            action: action,
            callbacks: callbacks(from: params),
            forceConfirm: boolFlag(params[confirmKey])
        )
    }

    /// Best-effort extraction of the x-callback hooks from a URL WITHOUT resolving
    /// the action, so the handler can still fire a descriptive x-error callback when
    /// action resolution itself throws (spec §13.6/§13.5: "if a callback URL was
    /// supplied, the caller receives a descriptive error callback" — true even for
    /// an unknown action or bad param, as long as the URL decomposes). Returns empty
    /// callbacks for a URL that `URLComponents` genuinely can't decompose.
    static func callbacks(in url: URL) -> AutomationCallbacks {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return AutomationCallbacks()
        }
        return callbacks(from: queryDictionary(components.queryItems))
    }

    // MARK: - Host → action

    // swiftlint:disable:next cyclomatic_complexity
    private static func action(forHost host: String, params: [String: String]) throws -> AutomationAction {
        switch host {
        case "capture-area": .capture(.area)
        case "capture-window": .capture(.window)
        case "capture-fullscreen": .capture(.fullscreen)
        case "capture-repeat": .capture(.repeatArea)
        case "capture-freeze": .capture(.freezeScreen)
        case "capture-scrolling": .capture(.scrolling)
        case "ocr-region": .ocrRegion
        case "ocr-image": try .ocrImage(path: requirePath(params))
        case "pin": .pin(path: nonEmptyPath(params))
        case "pins-toggle": .hideShowAllPins
        case "search": .search(query: params["q"] ?? params["query"] ?? "")
        case "settings": try .openSettings(pane: settingsPane(params))
        default:
            throw AutomationError.malformedRequest("unknown action \"\(host)\"")
        }
    }

    private static func requirePath(_ params: [String: String]) throws -> String {
        guard let path = nonEmptyPath(params) else {
            throw AutomationError.malformedRequest("missing required \"path\" parameter")
        }
        return path
    }

    private static func nonEmptyPath(_ params: [String: String]) -> String? {
        guard let raw = params["path"], !raw.isEmpty else { return nil }
        return (raw as NSString).expandingTildeInPath
    }

    private static func settingsPane(_ params: [String: String]) throws -> SettingsPane {
        guard let raw = params["pane"] else { return .general }
        guard let pane = SettingsPane(rawValue: raw.lowercased()) else {
            throw AutomationError.malformedRequest("unknown settings pane \"\(raw)\"")
        }
        return pane
    }

    // MARK: - Callbacks

    private static func callbacks(from params: [String: String]) -> AutomationCallbacks {
        AutomationCallbacks(
            success: params[successKey].flatMap(URL.init(string:)),
            error: params[errorKey].flatMap(URL.init(string:))
        )
    }

    private static func boolFlag(_ value: String?) -> Bool {
        guard let value = value?.lowercased() else { return false }
        return value == "1" || value == "true" || value == "yes"
    }

    /// Last-value-wins, lowercased keys. Empty/absent query → empty dictionary.
    private static func queryDictionary(_ items: [URLQueryItem]?) -> [String: String] {
        var result: [String: String] = [:]
        for item in items ?? [] {
            result[item.name.lowercased()] = item.value ?? ""
        }
        return result
    }

    // MARK: - Serialization (round-trip / docs examples)

    /// Build the canonical URL for an action — the inverse of `parse` for actions
    /// whose parameters survive a round trip. Used by the docs examples and the
    /// round-trip tests so the published surface is provably self-consistent.
    static func url(for action: AutomationAction, callbacks: AutomationCallbacks = AutomationCallbacks()) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host(for: action)
        var items = actionQueryItems(for: action)
        if let success = callbacks
            .success { items.append(URLQueryItem(name: successKey, value: success.absoluteString)) }
        if let errorURL = callbacks.error { items.append(URLQueryItem(name: errorKey, value: errorURL.absoluteString)) }
        components.queryItems = items.isEmpty ? nil : items
        // `URLComponents` always yields a valid URL for our controlled inputs.
        return components.url!
    }

    private static func host(for action: AutomationAction) -> String {
        switch action {
        case let .capture(mode): captureHost(mode)
        case .ocrRegion: "ocr-region"
        case .ocrImage: "ocr-image"
        case .pin: "pin"
        case .hideShowAllPins: "pins-toggle"
        case .search: "search"
        case .openSettings: "settings"
        }
    }

    private static func captureHost(_ mode: CaptureMode) -> String {
        switch mode {
        case .area: "capture-area"
        case .window: "capture-window"
        case .fullscreen: "capture-fullscreen"
        case .repeatArea: "capture-repeat"
        case .delayed: "capture-fullscreen" // delayed has no distinct scheme verb
        case .freezeScreen: "capture-freeze"
        case .scrolling: "capture-scrolling"
        }
    }

    private static func actionQueryItems(for action: AutomationAction) -> [URLQueryItem] {
        switch action {
        case let .ocrImage(path): [URLQueryItem(name: "path", value: path)]
        case let .pin(path): path.map { [URLQueryItem(name: "path", value: $0)] } ?? []
        case let .search(query): query.isEmpty ? [] : [URLQueryItem(name: "q", value: query)]
        case let .openSettings(pane): [URLQueryItem(name: "pane", value: pane.rawValue)]
        case .capture, .ocrRegion, .hideShowAllPins: []
        }
    }
}
