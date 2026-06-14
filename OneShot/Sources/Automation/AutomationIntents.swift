import AppIntents
import Foundation
import OneShotCapture
import OneShotLibrary

// AppIntents action catalog (§13.4, spec:automation "AppIntents action
// catalog"): the app's core actions exposed to Shortcuts and Spotlight. Every
// intent funnels through the shared `AutomationDispatcher`, so the gate
// (licensing, permission) and the engine wiring are identical to the URL scheme
// — there is no second policy here.
//
// AppIntents are user-initiated (Shortcuts/Spotlight), so they pass
// `source: .appIntent`: not gated by the URL-scheme master switch and not
// subject to the per-scheme confirmation prompt. They ARE gated by licensing and
// permission (spec: "enforce the same trial/license capture rules").
//
// The runtime invocation (Shortcuts running these) is runner-only, matching
// every interactive surface; the dispatch/gate logic they delegate to is the
// unit-tested part.

/// Shared helper: resolve the live dispatcher or fail with an honest error.
@MainActor
private func requireDispatcher() throws -> AutomationDispatcher {
    guard let dispatcher = AutomationRegistrar.shared.dispatcher else {
        throw AutomationError.malformedRequest("1shot is not ready to accept automation yet.")
    }
    return dispatcher
}

// MARK: - Capture intents

@available(macOS 13.0, *)
struct CaptureAreaIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture Area"
    static let description =
        IntentDescription("Select a screen region to capture, following your normal chip and output settings.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = try await requireDispatcher().run(.capture(.area), source: .appIntent)
        return .result()
    }
}

@available(macOS 13.0, *)
struct CaptureWindowIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture Window"
    static let description = IntentDescription("Pick a window to capture.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = try await requireDispatcher().run(.capture(.window), source: .appIntent)
        return .result()
    }
}

@available(macOS 13.0, *)
struct CaptureFullscreenIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture Fullscreen"
    static let description = IntentDescription("Capture the current display in full.")

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = try await requireDispatcher().run(.capture(.fullscreen), source: .appIntent)
        return .result()
    }
}

@available(macOS 13.0, *)
struct RepeatLastAreaIntent: AppIntent {
    static let title: LocalizedStringResource = "Repeat Last Area"
    static let description = IntentDescription("Re-capture the most recent area selection.")

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = try await requireDispatcher().run(.capture(.repeatArea), source: .appIntent)
        return .result()
    }
}

@available(macOS 13.0, *)
struct StartScrollingCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Scrolling Capture"
    static let description = IntentDescription("Begin a scrolling capture session.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = try await requireDispatcher().run(.capture(.scrolling), source: .appIntent)
        return .result()
    }
}

// MARK: - OCR intents

@available(macOS 13.0, *)
struct OCRRegionIntent: AppIntent {
    static let title: LocalizedStringResource = "Extract Text from Region"
    static let description =
        IntentDescription("Select a screen region and return its recognized text. Runs entirely on-device.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = try await requireDispatcher().run(.ocrRegion, source: .appIntent)
        return .result(value: result.textValue)
    }
}

@available(macOS 13.0, *)
struct OCRImageIntent: AppIntent {
    static let title: LocalizedStringResource = "Extract Text from Image"
    static let description =
        IntentDescription("Recognize the text in an image file and return it as a string. Runs entirely on-device.")

    @Parameter(title: "Image File")
    var file: IntentFile

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // AppIntents hands us a temporary file URL for the dropped image.
        let path = try resolvedPath()
        let result = try await requireDispatcher().run(.ocrImage(path: path), source: .appIntent)
        return .result(value: result.textValue)
    }

    private func resolvedPath() throws -> String {
        if let url = file.fileURL { return url.path }
        throw AutomationError.fileNotReadable(file.filename)
    }
}

// MARK: - Pin intents (surface defined; engine deferred to §10.5)

@available(macOS 13.0, *)
struct PinImageIntent: AppIntent {
    static let title: LocalizedStringResource = "Pin Image"
    static let description = IntentDescription("Float an image on top of the screen as a pin.")

    @Parameter(title: "Image File")
    var file: IntentFile

    @MainActor
    func perform() async throws -> some IntentResult {
        let path = file.fileURL?.path
        _ = try await requireDispatcher().run(.pin(path: path), source: .appIntent)
        return .result()
    }
}

@available(macOS 13.0, *)
struct ToggleAllPinsIntent: AppIntent {
    static let title: LocalizedStringResource = "Hide or Show All Pins"
    static let description = IntentDescription("Toggle the visibility of every pinned image.")

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = try await requireDispatcher().run(.hideShowAllPins, source: .appIntent)
        return .result()
    }
}

// MARK: - Library search intent

@available(macOS 13.0, *)
struct SearchLibraryIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Library"
    static let description =
        IntentDescription(
            "Search the 1shot Library by text and return matching items. Works regardless of license state."
        )

    @Parameter(title: "Query")
    var query: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[LibrarySearchEntity]> {
        // Search is never gated (data is never held hostage), so it can run the
        // engine directly to return structured results to the launcher/Shortcut,
        // while ALSO opening the in-app results UI via the dispatcher.
        let hits = try await AutomationRegistrar.shared.searchLibrary(query)
        _ = try? await requireDispatcher().run(.search(query: query), source: .appIntent)
        return .result(value: hits.map(LibrarySearchEntity.init))
    }
}

/// A search hit projected into an AppIntents entity so Shortcuts/Spotlight (and
/// the Raycast/Alfred extensions, §13.6) can display and open results headlessly
/// (spec: "Launcher Library search" returns items "that can be displayed and
/// opened from the launcher").
@available(macOS 13.0, *)
struct LibrarySearchEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "1shot Library Item")
    static let defaultQuery = LibrarySearchEntityQuery()

    /// `String` so it satisfies `EntityIdentifierConvertible`; the underlying
    /// Library row id is stringified (and back-parseable) without a new type.
    var id: String
    var name: String
    var path: String
    var snippet: String?

    init(hit: SearchHit) {
        id = String(hit.record.id ?? -1)
        name = hit.record.name
        path = hit.record.originalPath
        snippet = hit.snippet
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: snippet.map { "\($0)" })
    }
}

/// Minimal entity query so `LibrarySearchEntity` is a valid AppEntity. Identifier
/// lookup is unsupported in MVP (results flow forward from the search intent), so
/// it returns empty — Shortcuts only ever displays the freshly returned hits.
@available(macOS 13.0, *)
struct LibrarySearchEntityQuery: EntityQuery {
    func entities(for _: [String]) async throws -> [LibrarySearchEntity] {
        []
    }

    func suggestedEntities() async throws -> [LibrarySearchEntity] {
        []
    }
}

// MARK: - App Shortcuts provider (Spotlight surfacing)

/// Surfaces the headline intents as App Shortcuts so they appear in Spotlight and
/// the Shortcuts app without the user wiring them up (spec: "Spotlight action
/// invocation"). The phrases are what Spotlight matches on.
@available(macOS 13.0, *)
struct OneShotShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureAreaIntent(),
            phrases: ["Capture area with \(.applicationName)", "\(.applicationName) capture area"],
            shortTitle: "Capture Area",
            systemImageName: "selection.pin.in.out"
        )
        AppShortcut(
            intent: CaptureFullscreenIntent(),
            phrases: ["Capture fullscreen with \(.applicationName)", "\(.applicationName) capture screen"],
            shortTitle: "Capture Fullscreen",
            systemImageName: "rectangle.dashed"
        )
        AppShortcut(
            intent: OCRRegionIntent(),
            phrases: ["Extract text with \(.applicationName)", "\(.applicationName) OCR"],
            shortTitle: "Extract Text",
            systemImageName: "text.viewfinder"
        )
        AppShortcut(
            intent: SearchLibraryIntent(),
            phrases: ["Search \(.applicationName) library", "Find in \(.applicationName)"],
            shortTitle: "Search Library",
            systemImageName: "magnifyingglass"
        )
    }
}

private extension AutomationResult {
    /// The recognized text for an OCR result; empty for non-text results.
    var textValue: String {
        if case let .text(text) = self { return text }
        return ""
    }
}
