import Foundation
import OneShotCapture
import Testing
@testable import OneShot

// Pure URL-scheme parser/serializer coverage (§13.5, spec:automation "Documented
// URL-scheme surface"). The runtime Apple-Event handler is runner-only; these
// tests own the parse + round-trip contract.

// MARK: Documented call parses as documented (spec: "Documented call works as documented")

@Test func parse_captureArea_yieldsCaptureAreaAction() throws {
    let request = try AutomationURLParser.parse(url("oneshot://capture-area"))
    #expect(request.action == .capture(.area))
    #expect(request.callbacks.isEmpty)
}

@Test func parse_everyCaptureVerb_mapsToItsMode() throws {
    #expect(try AutomationURLParser.parse(url("oneshot://capture-window")).action == .capture(.window))
    #expect(try AutomationURLParser.parse(url("oneshot://capture-fullscreen")).action == .capture(.fullscreen))
    #expect(try AutomationURLParser.parse(url("oneshot://capture-repeat")).action == .capture(.repeatArea))
    #expect(try AutomationURLParser.parse(url("oneshot://capture-freeze")).action == .capture(.freezeScreen))
    #expect(try AutomationURLParser.parse(url("oneshot://capture-scrolling")).action == .capture(.scrolling))
}

@Test func parse_search_extractsQuery() throws {
    let request = try AutomationURLParser.parse(url("oneshot://search?q=stripe%20webhook"))
    #expect(request.action == .search(query: "stripe webhook"))
}

@Test func parse_search_acceptsQueryAlias() throws {
    let request = try AutomationURLParser.parse(url("oneshot://search?query=invoice"))
    #expect(request.action == .search(query: "invoice"))
}

@Test func parse_settings_namedPane() throws {
    let request = try AutomationURLParser.parse(url("oneshot://settings?pane=automation"))
    #expect(request.action == .openSettings(pane: .automation))
}

@Test func parse_settings_defaultsToGeneralWhenPaneOmitted() throws {
    let request = try AutomationURLParser.parse(url("oneshot://settings"))
    #expect(request.action == .openSettings(pane: .general))
}

@Test func parse_ocrImage_expandsTildePath() throws {
    let request = try AutomationURLParser.parse(url("oneshot://ocr-image?path=~/shot.png"))
    if case let .ocrImage(path) = request.action {
        #expect(!path.hasPrefix("~"))
        #expect(path.hasSuffix("/shot.png"))
    } else {
        Issue.record("expected ocrImage action")
    }
}

@Test func parse_pin_withoutPath_usesPasteboard() throws {
    let request = try AutomationURLParser.parse(url("oneshot://pin"))
    #expect(request.action == .pin(path: nil))
}

@Test func parse_pinsToggle() throws {
    #expect(try AutomationURLParser.parse(url("oneshot://pins-toggle")).action == .hideShowAllPins)
}

// MARK: Callbacks + confirm flag

@Test func parse_capturesXCallbackURLs() throws {
    let request = try AutomationURLParser.parse(url(
        "oneshot://ocr-region?x-success=myapp://done&x-error=myapp://fail"
    ))
    #expect(request.action == .ocrRegion)
    #expect(request.callbacks.success == URL(string: "myapp://done"))
    #expect(request.callbacks.error == URL(string: "myapp://fail"))
}

@Test func parse_confirmFlag_isHonored() throws {
    #expect(try AutomationURLParser.parse(url("oneshot://capture-fullscreen?confirm=1")).forceConfirm)
    #expect(try AutomationURLParser.parse(url("oneshot://capture-fullscreen?confirm=true")).forceConfirm)
    #expect(try !(AutomationURLParser.parse(url("oneshot://capture-fullscreen")).forceConfirm))
}

// MARK: Malformed requests fail safely (spec: "Malformed request fails safely")

@Test func parse_unknownAction_throwsMalformed() {
    #expect(throws: AutomationError.self) {
        try AutomationURLParser.parse(url("oneshot://teleport"))
    }
}

@Test func parse_wrongScheme_throwsMalformed() {
    #expect(throws: AutomationError.self) {
        try AutomationURLParser.parse(url("http://capture-area"))
    }
}

@Test func parse_ocrImage_missingPath_throwsMalformed() {
    #expect(throws: AutomationError.self) {
        try AutomationURLParser.parse(url("oneshot://ocr-image"))
    }
}

@Test func parse_settings_unknownPane_throwsMalformed() {
    #expect(throws: AutomationError.self) {
        try AutomationURLParser.parse(url("oneshot://settings?pane=nope"))
    }
}

@Test func parse_missingHost_throwsMalformed() throws {
    // "oneshot:" with no host is not a valid action request.
    #expect(throws: AutomationError.self) {
        try AutomationURLParser.parse(#require(URL(string: "oneshot:")))
    }
}

// MARK: Round-trip (serialize then parse is identity for param-bearing actions)

@Test func roundTrip_preservesActionAndParams() throws {
    let actions: [AutomationAction] = [
        .capture(.area),
        .capture(.fullscreen),
        .ocrRegion,
        .ocrImage(path: "/tmp/a.png"),
        .pin(path: "/tmp/b.png"),
        .pin(path: nil),
        .hideShowAllPins,
        .search(query: "github webhook"),
        .search(query: ""),
        .openSettings(pane: .destinations),
    ]
    for action in actions {
        let built = AutomationURLParser.url(for: action)
        let parsed = try AutomationURLParser.parse(built)
        #expect(parsed.action == action, "round-trip failed for \(action) → \(built)")
    }
}

@Test func roundTrip_preservesCallbacks() throws {
    let callbacks = AutomationCallbacks(
        success: URL(string: "caller://ok"),
        error: URL(string: "caller://err")
    )
    let built = AutomationURLParser.url(for: .search(query: "logs"), callbacks: callbacks)
    let parsed = try AutomationURLParser.parse(built)
    #expect(parsed.callbacks == callbacks)
}

// MARK: Helpers

private func url(_ string: String) -> URL {
    URL(string: string)!
}
