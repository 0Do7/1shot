import Foundation
import OneShotCore
import Testing
@testable import OneShotDestinations

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("oneshot-handoff-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private let pngPayload = DestinationPayload.image(
    data: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]),
    utType: "public.png",
    suggestedFileName: "stripe-webhook-error.png"
)

/// Records what the injected opener was handed, so tests assert behavior without
/// launching real apps. @unchecked Sendable: mutation is serialized by the
/// single in-test deliver() call (no concurrent access).
private final class OpenSpy: @unchecked Sendable {
    private(set) var openedFile: URL?
    private(set) var openedApplication: URL?
    let result: AppHandoffDestination.OpenResult

    init(result: AppHandoffDestination.OpenResult) {
        self.result = result
    }

    var opener: AppHandoffDestination.Opener {
        { [self] file, application in
            openedFile = file
            openedApplication = application
            return result
        }
    }
}

/// Spec ("Hand off to a pinned app"): the capture opens in the chosen app, and
/// the file passed to it is materialized at hand-off time reflecting the active
/// (already-encoded) payload.
@Test func handOffToAPinnedApp_materializesFileAndOpensInApp() async throws {
    let dir = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    let spy = OpenSpy(result: .opened)
    let destination = AppHandoffDestination(materializationDirectory: dir, opener: spy.opener)

    let appPath = "/Applications/Preview.app"
    let receipt = try await destination.deliver(
        pngPayload,
        configuration: [AppHandoffDestination.configApplicationPathKey: appPath]
    )

    // File materialized at hand-off time with the suggested (format-bearing) name…
    let materialized = try #require(receipt.materializedFileURL)
    #expect(materialized.lastPathComponent == "stripe-webhook-error.png")
    #expect(FileManager.default.fileExists(atPath: materialized.path))
    // …and exactly that file was handed to exactly the pinned app.
    #expect(spy.openedFile == materialized)
    #expect(spy.openedApplication?.path == appPath)
    let staged = try Data(contentsOf: materialized)
    #expect(staged == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]))
}

/// Spec ("Hand-off target missing"): an uninstalled pinned app yields an
/// explicit error naming the missing app (caller then offers the picker).
@Test func handOffTargetMissing_failsWithExplicitNamedError() async throws {
    let dir = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    let spy = OpenSpy(result: .targetMissing)
    let destination = AppHandoffDestination(materializationDirectory: dir, opener: spy.opener)

    do {
        _ = try await destination.deliver(
            pngPayload,
            configuration: [AppHandoffDestination.configApplicationPathKey: "/Applications/GhostEditor.app"]
        )
        Issue.record("expected throw")
    } catch let error as DestinationError {
        #expect(error.code == .targetMissing)
        #expect(error.destinationName == "Open With…")
        #expect(error.reason.contains("GhostEditor.app")) // names the missing app
        #expect(error.userMessage.contains("Open With…"))
    } catch {
        Issue.record("untyped error: \(error)")
    }

    // No staged file is left behind for a doomed open.
    let leftovers = try FileManager.default.contentsOfDirectory(atPath: dir.path)
    #expect(leftovers.isEmpty)
}

/// An open that fails for a reason *other* than a missing app (Gatekeeper denial,
/// quarantined/corrupt bundle, a `.fileURL` whose backing file was deleted) must
/// surface as an I/O failure carrying the real cause — not the misleading
/// "missing app — choose a replacement" message, which would route the user to
/// re-pick an app that is installed and fine.
@Test func handOffOpenFailsButAppPresent_failsAsIOWithRealReason() async throws {
    let dir = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    let underlyingReason = "operation not permitted (Gatekeeper)"
    let spy = OpenSpy(result: .openFailed(reason: underlyingReason))
    let destination = AppHandoffDestination(materializationDirectory: dir, opener: spy.opener)

    do {
        _ = try await destination.deliver(
            pngPayload,
            configuration: [AppHandoffDestination.configApplicationPathKey: "/Applications/Preview.app"]
        )
        Issue.record("expected throw")
    } catch let error as DestinationError {
        #expect(error.code == .io)
        #expect(error.code != .targetMissing) // not the dishonest "missing app" path
        #expect(error.reason.contains(underlyingReason)) // carries the real cause
        #expect(error.reason.contains("Preview.app"))
        #expect(!error.reason.contains("is missing"))
        #expect(error.userMessage.contains("Open With…"))
    } catch {
        Issue.record("untyped error: \(error)")
    }

    // No staged file is left behind for a doomed open.
    let leftovers = try FileManager.default.contentsOfDirectory(atPath: dir.path)
    #expect(leftovers.isEmpty)
}

@Test func handOff_noApplicationConfigured_failsWithTypedError() async throws {
    let dir = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    let destination = AppHandoffDestination(materializationDirectory: dir, opener: OpenSpy(result: .opened).opener)

    do {
        _ = try await destination.deliver(pngPayload, configuration: [:])
        Issue.record("expected throw")
    } catch let error as DestinationError {
        #expect(error.code == .invalidConfiguration)
        #expect(error.userMessage.contains("Open With…"))
    } catch {
        Issue.record("untyped error: \(error)")
    }
}

/// A fileURL payload is handed off directly (no copy) — the file already exists.
@Test func handOff_fileURLPayload_handsOffSourceDirectly() async throws {
    let dir = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    let source = dir.appendingPathComponent("existing.png")
    try Data([0x01, 0x02]).write(to: source)

    let spy = OpenSpy(result: .opened)
    let destination = AppHandoffDestination(materializationDirectory: dir, opener: spy.opener)
    let receipt = try await destination.deliver(
        .fileURL(source),
        configuration: [AppHandoffDestination.configApplicationPathKey: "/Applications/Preview.app"]
    )
    #expect(receipt.materializedFileURL == source)
    #expect(spy.openedFile == source)
}

/// The hand-off destination registers and surfaces through the registry contract.
@Test func handOff_registersAndDiscoversThroughRegistry() async throws {
    let registry = DestinationRegistry()
    try await registry.register(AppHandoffDestination(opener: OpenSpy(result: .opened).opener))
    let descriptors = await registry.descriptors(accepting: .image)
    #expect(descriptors.map(\.id) == ["oneshot.apphandoff"])
    #expect(descriptors.first?.capabilities.requiresNetwork == false)
}
