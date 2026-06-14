import Foundation
import GRDB

/// Atomic auto-import dedup + insert (spec §9.6 "No duplicate entries"). Split out of
/// `LibraryStore.swift` so that file stays within the file-length budget; the shared
/// `insertRow` helper used by the public insert paths lives here too. All members are
/// `internal` by contract — only the indexing pipeline (same package) drives them.
extension LibraryStore {
    /// Outcome of an atomic dedup-and-insert (`insertIfNotIndexed`): either the newly
    /// inserted record, or a signal that an equivalent item was already present so the
    /// caller can record a skipped duplicate.
    enum DedupInsertOutcome: Sendable {
        case inserted(CaptureRecord)
        case duplicate
    }

    /// The dedup probe (path OR content hash) and the collision-resolving insert run in
    /// ONE write transaction, eliminating the read-then-write TOCTOU window: concurrent
    /// watcher-driven ingests for the same new file can no longer both pass the probe and
    /// both insert, because the `DatabaseQueue` serializes writes and the probe now lives
    /// inside the write.
    ///
    /// Defense in depth: should a probe ever miss (e.g. a future multi-connection pool),
    /// the UNIQUE partial index on `contentHash` (schema v3) rejects the second insert
    /// with SQLITE_CONSTRAINT, which is caught here and mapped to `.duplicate` rather
    /// than surfaced as a hard failure. Either way exactly one row survives per content.
    func insertIfNotIndexed(
        _ record: CaptureRecord,
        baseSlug: String,
        ocrText: String? = nil
    ) throws -> DedupInsertOutcome {
        try write { db in
            if try Self.isIndexed(db, path: record.originalPath, contentHash: record.contentHash) {
                return .duplicate
            }
            let name = try Self.resolveName(db, baseSlug: baseSlug, excludingID: nil)
            do {
                return .inserted(try Self.insertRow(db, record, name: name, ocrText: ocrText))
            } catch let error as DatabaseError where error.resultCode.primaryResultCode == .SQLITE_CONSTRAINT {
                // UNIQUE(contentHash) backstop: a concurrent writer landed the same
                // content between the probe and this insert. The INSERT failed atomically
                // (no partial row), so the transaction stays consistent — report a
                // duplicate instead of failing the ingest. Single-process writes are
                // serialized by the DatabaseQueue, so this is purely defense in depth.
                return .duplicate
            }
        }
    }

    /// Insert the `captures` row + FTS entry for `record` under `name`, returning the
    /// hydrated record. Shared by the collision-resolving insert paths; assumes it runs
    /// inside an open write transaction.
    nonisolated static func insertRow(
        _ db: Database,
        _ record: CaptureRecord,
        name: String,
        ocrText: String?
    ) throws -> CaptureRecord {
        try db.execute(sql: """
        INSERT INTO captures
            (originalPath, missing, name, nameIsManual, mediaType, durationSeconds,
             bundleID, appName, windowTitle, url, displayID, capturedAt,
             textIndexed, containsCode, isKept, ocrText, contentHash)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, arguments: [
            record.originalPath,
            record.missing,
            name,
            record.nameIsManual,
            record.mediaType.rawValue,
            record.durationSeconds,
            record.provenance.bundleID,
            record.provenance.appName,
            record.provenance.windowTitle,
            record.provenance.url,
            record.provenance.displayID.map { Int64($0) },
            record.capturedAt.timeIntervalSince1970,
            record.textIndexed,
            record.containsCode,
            record.isKept,
            ocrText,
            record.contentHash,
        ])
        let id = db.lastInsertedRowID
        try Self.syncFTS(db, captureID: id)
        var hydrated = record
        hydrated.id = id
        hydrated.name = name
        return hydrated
    }

    /// Synchronous dedup probe used INSIDE an open transaction (path OR content hash).
    /// Mirrors `isAlreadyIndexed` but takes an open `Database` so the probe and a
    /// subsequent insert share one transaction (no TOCTOU). A nil hash falls back to a
    /// path-only check (native captures dedup by their unique path).
    nonisolated static func isIndexed(_ db: Database, path: String, contentHash hash: String?) throws -> Bool {
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
