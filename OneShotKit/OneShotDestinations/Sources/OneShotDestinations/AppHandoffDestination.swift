import AppKit
import Foundation
import OneShotCore
import UniformTypeIdentifiers

/// App hand-off destination (task 11.1, spec:output-destinations "App hand-off
/// destination"): materializes a file only at hand-off time, then opens it in a
/// user-chosen application via the standard open-with mechanism.
///
/// The launch side effect sits behind an injectable `Opener` closure (defaults
/// to the real `NSWorkspace.open`) so the destination's logic — file
/// materialization, target-missing detection, typed errors — is unit-testable
/// without launching real apps.
///
/// OneShotDestinations is outside the portability law, so `import AppKit` is
/// permitted here; the side effect is injected to keep tests app-free.
public struct AppHandoffDestination: CaptureDestination {
    /// Configuration key carrying the target application's path (e.g. the
    /// `.app` bundle the user pinned). Empty/absent → the app presents its
    /// open-with picker (out of package scope) before delivery.
    public static let configApplicationPathKey = "applicationPath"

    /// Outcome of an open attempt: `.opened` on success; `.targetMissing` when
    /// the pinned app no longer exists (drives the spec's explicit error +
    /// "offer the picker" recovery).
    public enum OpenResult: Equatable, Sendable {
        case opened
        case targetMissing
    }

    /// Injected open side effect: given the materialized file URL and the pinned
    /// application URL, returns the outcome. Default = real `NSWorkspace.open`.
    public typealias Opener = @Sendable (_ file: URL, _ application: URL) async -> OpenResult

    public let descriptor = DestinationDescriptor(
        id: "oneshot.apphandoff",
        displayName: "Open With…",
        icon: "arrow.up.forward.app",
        acceptedPayloads: [.image, .fileURL, .text],
        configurationSchema: [
            ConfigurationField(
                key: configApplicationPathKey,
                label: "Application",
                kind: .string,
                isRequired: true
            ),
        ]
    )

    private let opener: Opener
    private let materializationDirectory: URL

    /// Default initializer: real NSWorkspace launch, temp-dir materialization.
    public init() {
        self.init(
            materializationDirectory: FileManager.default.temporaryDirectory,
            opener: AppHandoffDestination.workspaceOpener
        )
    }

    /// Test/host seam: inject the open side effect and where files materialize.
    public init(
        materializationDirectory: URL = FileManager.default.temporaryDirectory,
        opener: @escaping Opener
    ) {
        self.materializationDirectory = materializationDirectory
        self.opener = opener
    }

    public func deliver(
        _ payload: DestinationPayload,
        configuration: DestinationConfiguration
    ) async throws -> DeliveryReceipt {
        try requireAccepts(payload)

        guard let appPath = configuration[Self.configApplicationPathKey], !appPath.isEmpty else {
            throw DestinationError(
                code: .invalidConfiguration,
                destinationName: descriptor.displayName,
                reason: "no hand-off application chosen"
            )
        }
        let applicationURL = URL(fileURLWithPath: (appPath as NSString).expandingTildeInPath)

        // Materialize the file only now, at hand-off time.
        let fileURL = try materialize(payload)

        let result = await opener(fileURL, applicationURL)
        switch result {
        case .opened:
            return DeliveryReceipt(materializedFileURL: fileURL)
        case .targetMissing:
            // Best-effort cleanup of the file we materialized for a doomed open.
            try? FileManager.default.removeItem(at: fileURL)
            throw DestinationError(
                code: .targetMissing,
                destinationName: descriptor.displayName,
                reason: "application \(applicationURL.lastPathComponent) is missing — choose a replacement"
            )
        }
    }

    // MARK: Materialization

    private func materialize(_ payload: DestinationPayload) throws -> URL {
        switch payload {
        case let .image(data, _, suggestedFileName):
            try write(data, preferredName: suggestedFileName)
        case let .text(string):
            try write(Data(string.utf8), preferredName: "capture.txt")
        case let .fileURL(source):
            // Already a file on disk — hand it off directly, no copy.
            source
        }
    }

    private func write(_ data: Data, preferredName: String) throws -> URL {
        let baseName = (preferredName as NSString).deletingPathExtension
        let ext = (preferredName as NSString).pathExtension
        let resolved = AutoNamer.resolvingCollision(of: baseName) { candidate in
            FileManager.default.fileExists(
                atPath: materializationDirectory.appendingPathComponent(candidate).appendingPathExtension(ext).path
            )
        }
        let url = materializationDirectory.appendingPathComponent(resolved).appendingPathExtension(ext)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw DestinationError(
                code: .io,
                destinationName: descriptor.displayName,
                reason: "could not stage \(url.lastPathComponent): \(error.localizedDescription)"
            )
        }
        return url
    }

    // MARK: Real launch

    /// The production opener: detect a missing app first (honest failure), then
    /// open the file with it via NSWorkspace.
    private static let workspaceOpener: Opener = { file, application in
        guard FileManager.default.fileExists(atPath: application.path) else {
            return .targetMissing
        }
        return await withCheckedContinuation { continuation in
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open(
                [file],
                withApplicationAt: application,
                configuration: configuration
            ) { _, error in
                continuation.resume(returning: error == nil ? .opened : .targetMissing)
            }
        }
    }
}
