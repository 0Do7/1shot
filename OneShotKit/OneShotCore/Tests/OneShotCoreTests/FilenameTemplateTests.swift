import Foundation
import Testing
@testable import OneShotCore

private let june9 = Date(timeIntervalSince1970: 1_781_001_296) // 2026-06-09 10:34:56 UTC
private let utc = TimeZone(identifier: "UTC")!

// Spec: Template renders with capture context — `{app}-{date}-{counter}` →
// `Safari-2026-06-09-3` (case preserved; this is NOT the AutoNamer slug path)
@Test func template_rendersAppDateCounter() throws {
    let context = try TemplateContext(
        date: Date(timeIntervalSince1970: 1_780_990_000), // 2026-06-09 in LA
        timeZone: #require(TimeZone(identifier: "America/Los_Angeles")),
        appName: "Safari",
        counter: 3
    )
    #expect(FilenameTemplate.render("{app}-{date}-{counter}", context: context) == "Safari-2026-06-09-3")
}

// Spec: Invalid characters sanitized (macOS + Windows reserved set)
@Test func template_sanitizesReservedCharacters() {
    let context = TemplateContext(date: june9, timeZone: utc, windowTitle: "Bug: crash / restart?")
    let rendered = FilenameTemplate.render("{title}", context: context)
    #expect(rendered == "Bug-crash-restart")
    for character in "/\\:*?\"<>|" {
        #expect(!rendered.contains(character), "reserved '\(character)' survived")
    }
}

@Test func template_allTokensRender() {
    let context = TemplateContext(
        date: june9,
        timeZone: utc,
        captureType: "area",
        appName: "Xcode",
        windowTitle: "Build Log",
        counter: 7,
        autoName: "xcode-build-log"
    )
    let rendered = FilenameTemplate.render(
        "{type} {app} {title} {counter} {autoname} {date} {time}",
        context: context
    )
    #expect(rendered == "area Xcode Build Log 7 xcode-build-log 2026-06-09 10.34.56")
}

@Test func template_unknownTokenRendersLiterally_forPreviewDebuggability() {
    let context = TemplateContext(date: june9, timeZone: utc, appName: "Safari")
    #expect(FilenameTemplate.render("{app}-{nope}", context: context) == "Safari-{nope}")
}

@Test func template_missingValues_collapseSeparators() {
    let context = TemplateContext(date: june9, timeZone: utc) // no app, no title
    #expect(FilenameTemplate.render("{app}-{date}-{title}", context: context) == "2026-06-09")
}

@Test func template_emptyResult_fallsBackToTimestampName() {
    let context = TemplateContext(date: june9, timeZone: utc)
    #expect(FilenameTemplate.render("{app}", context: context) == "capture-2026-06-09-at-10-34-56")
}

@Test func template_clampsLengthAtCharacterBoundary() {
    let context = TemplateContext(
        date: june9,
        timeZone: utc,
        windowTitle: String(repeating: "long title ", count: 30)
    )
    let rendered = FilenameTemplate.render("{title}", context: context)
    #expect(rendered.count <= FilenameTemplate.maxLength)
    #expect(!rendered.hasSuffix("-") && !rendered.hasSuffix(" "))
}

// Spec: Capture type routes to its preset
@Test func routing_captureTypeRoutesToAssignedPreset() {
    let docs = OutputPreset(name: "Docs", directoryPath: "~/Docs/shots", downscaleRetinaTo1x: true)
    let desktop = OutputPreset(name: "Default", directoryPath: "~/Desktop")
    let routing = OutputRouting(
        defaultPresetID: desktop.id,
        presetIDByCaptureType: ["scrolling": docs.id]
    )

    let scrolling = OutputPresetResolver.preset(
        forCaptureType: "scrolling",
        presets: [docs, desktop],
        routing: routing
    )
    #expect(scrolling?.id == docs.id)
    #expect(scrolling?.downscaleRetinaTo1x == true)

    let area = OutputPresetResolver.preset(forCaptureType: "area", presets: [docs, desktop], routing: routing)
    #expect(area?.id == desktop.id) // unrouted type → default
    let untyped = OutputPresetResolver.preset(forCaptureType: nil, presets: [docs, desktop], routing: routing)
    #expect(untyped?.id == desktop.id)
}

@Test func routing_danglingRouteOrDefault_degradesGracefully() {
    let only = OutputPreset(name: "Only", directoryPath: "~/Desktop")
    let routing = OutputRouting(
        defaultPresetID: UUID(), // dangling default
        presetIDByCaptureType: ["area": UUID()] // dangling route
    )
    #expect(OutputPresetResolver.preset(forCaptureType: "area", presets: [only], routing: routing)?.id == only.id)
    #expect(OutputPresetResolver.preset(forCaptureType: nil, presets: [], routing: routing) == nil)
}

// Spec: Missing destination folder falls back (+ notification signal)
@Test func saveLocation_missingFolder_fallsBackToDefaultAndFlags() {
    let docs = OutputPreset(name: "Docs", directoryPath: "~/Docs/shots")
    let desktop = OutputPreset(name: "Default", directoryPath: "~/Desktop")

    let resolved = OutputPresetResolver.resolveSaveLocation(
        for: docs,
        defaultPreset: desktop,
        directoryExists: { $0 == "~/Desktop" } // docs folder is gone
    )
    #expect(resolved.directoryPath == "~/Desktop")
    #expect(resolved.usedFallback)
    #expect(resolved.unavailablePath == "~/Docs/shots")
    #expect(resolved.preset.id == docs.id) // format/template still come from the preset

    let healthy = OutputPresetResolver.resolveSaveLocation(
        for: docs,
        defaultPreset: desktop,
        directoryExists: { _ in true }
    )
    #expect(!healthy.usedFallback)
    #expect(healthy.directoryPath == "~/Docs/shots")
}

@Test func outputPreset_roundTripsThroughCodable() throws {
    let preset = OutputPreset(
        name: "Docs",
        directoryPath: "~/Docs/shots",
        format: .webp,
        downscaleRetinaTo1x: true,
        template: "{app}-{date}-{counter}"
    )
    let decoded = try JSONDecoder().decode(OutputPreset.self, from: JSONEncoder().encode(preset))
    #expect(decoded == preset)
    #expect(ImageFormat.allCases.map(\.pathExtension) == ["png", "jpeg", "webp", "heic"])
}
