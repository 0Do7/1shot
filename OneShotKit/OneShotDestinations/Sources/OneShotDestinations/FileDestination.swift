import Foundation
import OneShotCore

/// Built-in file destination (spec:output-destinations "File destination").
/// Saves the payload into the configured directory; the receipt's
/// `materializedFileURL` drives "Reveal in Finder". Save-location presets and
/// filename templates layer on top via configuration (task 2.7).
public struct FileDestination: CaptureDestination {
    public static let configDirectoryKey = "directory"

    public let descriptor = DestinationDescriptor(
        id: "oneshot.file",
        displayName: "Save to Files",
        icon: "folder",
        acceptedPayloads: [.image, .fileURL, .text],
        configurationSchema: [
            ConfigurationField(key: configDirectoryKey, label: "Folder", kind: .url, isRequired: true),
        ]
    )

    public init() {}

    public func deliver(
        _ payload: DestinationPayload,
        configuration: DestinationConfiguration
    ) async throws -> DeliveryReceipt {
        try requireAccepts(payload)
        guard let directoryPath = configuration[Self.configDirectoryKey], !directoryPath.isEmpty else {
            throw DestinationError(
                code: .invalidConfiguration,
                destinationName: descriptor.displayName,
                reason: "no destination folder configured"
            )
        }
        let directory = URL(fileURLWithPath: (directoryPath as NSString).expandingTildeInPath, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw DestinationError(
                code: .targetMissing,
                destinationName: descriptor.displayName,
                reason: "folder \(directory.path) does not exist"
            )
        }

        let data: Data
        let preferredName: String
        switch payload {
        case let .image(imageData, _, suggestedFileName):
            data = imageData
            preferredName = suggestedFileName
        case let .text(string):
            data = Data(string.utf8)
            preferredName = "capture.txt"
        case let .fileURL(source):
            data = try readData(at: source)
            preferredName = source.lastPathComponent
        }

        let url = uniqueURL(in: directory, preferredName: preferredName)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw DestinationError(
                code: .io,
                destinationName: descriptor.displayName,
                reason: "could not write \(url.lastPathComponent): \(error.localizedDescription)"
            )
        }
        return DeliveryReceipt(materializedFileURL: url)
    }

    private func readData(at source: URL) throws -> Data {
        do {
            return try Data(contentsOf: source)
        } catch {
            throw DestinationError(
                code: .targetMissing,
                destinationName: descriptor.displayName,
                reason: "source file \(source.lastPathComponent) is unreadable"
            )
        }
    }

    /// Deterministic collision handling via the shared naming rule (name-2, name-3, …).
    private func uniqueURL(in directory: URL, preferredName: String) -> URL {
        let baseName = (preferredName as NSString).deletingPathExtension
        let ext = (preferredName as NSString).pathExtension
        let resolved = AutoNamer.resolvingCollision(of: baseName) { candidate in
            FileManager.default.fileExists(
                atPath: directory.appendingPathComponent(candidate).appendingPathExtension(ext).path
            )
        }
        return directory.appendingPathComponent(resolved).appendingPathExtension(ext)
    }
}
