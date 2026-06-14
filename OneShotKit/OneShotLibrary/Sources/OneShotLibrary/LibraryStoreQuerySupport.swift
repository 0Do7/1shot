import Foundation
import GRDB

/// Store helpers backing smart folders (§9.5) and the retention planner (§9.8). Kept
/// in their own file so `LibraryStore.swift` stays within the file-length budget; the
/// public tag-management API (`addTag`/`deleteTag`/`rename`) remains in the main file.
public extension LibraryStore {
    /// Remove a single tag from ONE capture (spec §9.5 "expose add/remove"). Leaves
    /// the tag on every other capture and never deletes the capture. The tag row
    /// itself survives even when this was its last association — `deleteTag` is the
    /// explicit way to retire a tag globally. Re-syncs FTS so the tag stops matching
    /// this capture in search. Idempotent: a no-op when the association is absent.
    func removeTag(_ tagName: String, fromCapture captureID: Int64) throws {
        try write { db in
            guard let tagID = try Int64.fetchOne(db, sql: "SELECT id FROM tags WHERE name = ?", arguments: [tagName])
            else {
                return // tag doesn't exist — nothing to remove
            }
            try db.execute(
                sql: "DELETE FROM capture_tags WHERE captureID = ? AND tagID = ?",
                arguments: [captureID, tagID]
            )
            try Self.syncFTS(db, captureID: captureID)
        }
    }

    /// Distinct source-application display names present in the store, alphabetical.
    /// Backs the per-app smart-folder enumeration (§9.5). Apps without a recorded
    /// `appName` are omitted (provenance is never fabricated).
    func distinctAppNames() throws -> [String] {
        try read { db in
            try String.fetchAll(db, sql: """
            SELECT DISTINCT appName FROM captures WHERE appName IS NOT NULL ORDER BY appName COLLATE NOCASE
            """)
        }
    }

    /// The set of capture ids that carry at least one manual tag. Backs the retention
    /// planner's `excludeTagged` rule (§9.8) in one query instead of N per-row lookups.
    func taggedCaptureIDs() throws -> Set<Int64> {
        try read { db in
            try Set(Int64.fetchAll(db, sql: "SELECT DISTINCT captureID FROM capture_tags"))
        }
    }

    /// The recognized OCR text stored for a capture, or nil when none is indexed yet.
    /// The `CaptureRecord` value type intentionally omits the (potentially large) OCR
    /// blob; the Spotlight donation builder (§9.7) reads it here on demand.
    func ocrText(forCapture captureID: Int64) throws -> String? {
        try read { db in
            try String.fetchOne(db, sql: "SELECT ocrText FROM captures WHERE id = ?", arguments: [captureID])
        }
    }

    /// Auto-import dedup probe (§9.6 "No duplicate entries"). True when ANY indexed
    /// item already references this exact `path` OR already carries this content
    /// `hash`. Content identity wins over path so a moved/renamed-but-identical file
    /// is recognized; the path branch catches a re-scan before any hash was computed.
    /// Passing a nil hash falls back to a path-only check.
    func isAlreadyIndexed(path: String, contentHash hash: String?) throws -> Bool {
        try read { db in
            if try Bool.fetchOne(
                db, sql: "SELECT 1 FROM captures WHERE originalPath = ? LIMIT 1", arguments: [path]
            ) ?? false {
                return true
            }
            guard let hash else { return false }
            return try Bool.fetchOne(
                db, sql: "SELECT 1 FROM captures WHERE contentHash = ? LIMIT 1", arguments: [hash]
            ) ?? false
        }
    }
}
