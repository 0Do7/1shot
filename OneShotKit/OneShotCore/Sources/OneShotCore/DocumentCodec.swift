import Foundation

public enum DocumentCodecError: Error, Equatable, Sendable {
    /// Document was written by a newer app version; we never guess at unknown formats.
    case schemaNewerThanSupported(found: Int, supported: Int)
    /// Pre-1 or corrupted version field.
    case invalidSchemaVersion(found: Int)
}

/// Serialization + forward migration for `AnnotationDocument` JSON (design D3).
/// Old documents MUST open in newer app versions, migrated forward, never refused
/// or rasterized (spec: re-editable annotation document).
public enum DocumentCodec {
    public static func encode(_ document: AnnotationDocument) throws -> Data {
        let encoder = JSONEncoder()
        // Stable output: golden fixtures and bundle diffs depend on key order.
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try encoder.encode(document)
    }

    public static func decode(_ data: Data) throws -> AnnotationDocument {
        let version = try schemaVersion(of: data)
        guard version >= 1 else {
            throw DocumentCodecError.invalidSchemaVersion(found: version)
        }
        guard version <= AnnotationDocument.currentSchemaVersion else {
            throw DocumentCodecError.schemaNewerThanSupported(
                found: version,
                supported: AnnotationDocument.currentSchemaVersion
            )
        }
        let migrated = try migrate(data, from: version)
        return try JSONDecoder().decode(AnnotationDocument.self, from: migrated)
    }

    /// Reads only the version field, so migration can run before full decoding.
    public static func schemaVersion(of data: Data) throws -> Int {
        struct VersionProbe: Decodable {
            let schemaVersion: Int
        }
        return try JSONDecoder().decode(VersionProbe.self, from: data).schemaVersion
    }

    /// Applies each migration step in sequence (1→2, 2→3, …) until current.
    /// Steps transform raw JSON so old payload shapes never need live Swift types.
    private static func migrate(_ data: Data, from version: Int) throws -> Data {
        var current = data
        var v = version
        while v < AnnotationDocument.currentSchemaVersion {
            switch v {
            // case 1: current = try migrateV1toV2(current)  — first real migration lands here
            default:
                assertionFailure("missing migration step \(v)→\(v + 1); currentSchemaVersion bumped without one")
            }
            v += 1
        }
        return current
    }
}
