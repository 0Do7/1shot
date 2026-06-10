import AppKit
import Foundation
import OneShotCore
import Testing
@testable import OneShotDestinations

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("oneshot-dest-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private let pngPayload = DestinationPayload.image(
    data: Data([0x89, 0x50, 0x4E, 0x47]),
    utType: "public.png",
    suggestedFileName: "stripe-webhook-error.png"
)

// Spec: Save then reveal — file lands at the configured location with the
// suggested name; receipt carries the URL for "Reveal in Finder".
@Test func fileDestination_savesWithSuggestedName_andReportsURLForReveal() async throws {
    let dir = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let receipt = try await FileDestination().deliver(
        pngPayload,
        configuration: [FileDestination.configDirectoryKey: dir.path]
    )
    let saved = try #require(receipt.materializedFileURL)
    #expect(saved.lastPathComponent == "stripe-webhook-error.png")
    #expect(FileManager.default.fileExists(atPath: saved.path))
}

@Test func fileDestination_resolvesNameCollisionsDeterministically() async throws {
    let dir = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    let config = [FileDestination.configDirectoryKey: dir.path]

    let first = try await FileDestination().deliver(pngPayload, configuration: config)
    let second = try await FileDestination().deliver(pngPayload, configuration: config)
    let third = try await FileDestination().deliver(pngPayload, configuration: config)

    #expect(first.materializedFileURL?.lastPathComponent == "stripe-webhook-error.png")
    #expect(second.materializedFileURL?.lastPathComponent == "stripe-webhook-error-2.png")
    #expect(third.materializedFileURL?.lastPathComponent == "stripe-webhook-error-3.png")
}

@Test func fileDestination_missingFolder_failsWithTypedError() async {
    await #expect(throws: DestinationError(
        code: .targetMissing,
        destinationName: "Save to Files",
        reason: "folder /nonexistent/oneshot-nowhere does not exist"
    )) {
        _ = try await FileDestination().deliver(
            pngPayload,
            configuration: [FileDestination.configDirectoryKey: "/nonexistent/oneshot-nowhere"]
        )
    }
}

@Test func fileDestination_noConfiguration_failsWithTypedError() async {
    do {
        _ = try await FileDestination().deliver(pngPayload, configuration: [:])
        Issue.record("expected throw")
    } catch let error as DestinationError {
        #expect(error.code == .invalidConfiguration)
        #expect(error.userMessage.contains("Save to Files"))
    } catch {
        Issue.record("untyped error: \(error)")
    }
}

// Spec: Copy writes nothing to disk
@Test func clipboardDestination_putsImageOnPasteboard_writesNothingToDisk() async throws {
    let name = NSPasteboard.Name("oneshot-test-\(UUID().uuidString)")
    let destination = ClipboardDestination(pasteboardName: name)

    let receipt = try await destination.deliver(pngPayload, configuration: [:])
    #expect(receipt.materializedFileURL == nil) // nothing on disk
    let data = await MainActor.run {
        NSPasteboard(name: name).data(forType: NSPasteboard.PasteboardType("public.png"))
    }
    #expect(data == Data([0x89, 0x50, 0x4E, 0x47]))
}

@Test func clipboardDestination_putsTextOnPasteboard() async throws {
    let name = NSPasteboard.Name("oneshot-test-\(UUID().uuidString)")
    _ = try await ClipboardDestination(pasteboardName: name).deliver(
        .text("ocr result"),
        configuration: [:]
    )
    let text = await MainActor.run { NSPasteboard(name: name).string(forType: .string) }
    #expect(text == "ocr result")
}

@Test func clipboardDestination_rejectsFileURLPayload() async {
    let name = NSPasteboard.Name("oneshot-test-\(UUID().uuidString)")
    await #expect(throws: DestinationError(
        code: .unsupportedPayload,
        destinationName: "Clipboard",
        reason: "does not accept fileURL payloads"
    )) {
        _ = try await ClipboardDestination(pasteboardName: name).deliver(
            .fileURL(URL(fileURLWithPath: "/tmp/x.png")),
            configuration: [:]
        )
    }
}

/// Both built-ins register cleanly and surface through the registry contract.
@Test func builtIns_registerAndDiscoverThroughRegistry() async throws {
    let registry = DestinationRegistry()
    try await registry.register(ClipboardDestination())
    try await registry.register(FileDestination())

    let imageDescriptors = await registry.descriptors(accepting: .image)
    #expect(imageDescriptors.map(\.id) == ["oneshot.clipboard", "oneshot.file"])
    let fileURLDescriptors = await registry.descriptors(accepting: .fileURL)
    #expect(fileURLDescriptors.map(\.id) == ["oneshot.file"])
}
