import Foundation
import GRDB
import OneShotCore

/// The Library's persistent index (design D4, spec §9.1). An actor owning a single
/// GRDB `DatabaseQueue` — file-backed in production, in-memory in tests.
///
/// Reference-not-vault: the DB stores the absolute path of each user-visible
/// original plus a `missing` flag. Originals are NEVER copied or modified here.
///
/// FTS5: a `captures_fts` virtual table indexes the searchable surface (name +
/// OCR text + tags + provenance) keyed by the captures row id. It is kept in sync
/// explicitly by the store on every write so search (§9.3) can use bm25()/snippet()
/// with prefix matching.
public actor LibraryStore {
    /// Schema version this store creates/expects. Forward migrations append; v1's
    /// reserved columns (durationSeconds, metadataJSON, embedding) stay null. v2 adds
    /// the auto-import dedup `contentHash` column (§9.6) — additive and nullable, so a
    /// v1 database opens and migrates with all existing items/names/tags/FTS preserved.
    /// v3 upgrades the contentHash index to a UNIQUE partial index so the §9.6 "No
    /// duplicate entries" guarantee is enforced at the DB level — a hard backstop for the
    /// dedup probe that closes the concurrent-watcher TOCTOU window.
    public static let schemaVersion = "v3"

    private let dbQueue: DatabaseQueue

    /// Open (and migrate) a file-backed store at `path`. Parent directory must exist.
    public init(path: String) throws {
        do {
            dbQueue = try DatabaseQueue(path: path)
        } catch {
            throw LibraryError.databaseFailed("open(\(path)): \(error)")
        }
        try Self.migrate(dbQueue)
    }

    /// Open (and migrate) an independent in-memory store (tests / ephemeral use).
    public init() throws {
        do {
            dbQueue = try DatabaseQueue()
        } catch {
            throw LibraryError.databaseFailed("openInMemory: \(error)")
        }
        try Self.migrate(dbQueue)
    }

    /// Escape hatch for the search layer (§9.3) and the indexing pipeline (§9.2),
    /// both of which live in the same package. Read access only by contract.
    func read<T: Sendable>(_ work: @Sendable (Database) throws -> T) throws -> T {
        do {
            return try dbQueue.read(work)
        } catch let error as LibraryError {
            throw error
        } catch {
            throw LibraryError.databaseFailed("\(error)")
        }
    }

    /// Test/bench support (§9.3 perf gate): bulk-insert `count` synthetic rows plus
    /// their FTS entries in ONE transaction. Not used by production code paths, which
    /// insert row-by-row via `insert`. ~1% of rows contain "stripe webhook" so a
    /// representative query returns a bounded result set against a realistic index.
    func bulkSeedForPerfTest(count: Int) throws {
        try write { db in
            for i in 0 ..< count {
                let hasTerm = i % 100 == 0
                let ocr = hasTerm
                    ? "stripe webhook delivery failed item \(i) status 500"
                    : "lorem ipsum dolor sit amet item \(i) consectetur adipiscing elit"
                try db.execute(sql: """
                INSERT INTO captures
                    (originalPath, name, mediaType, appName, capturedAt, textIndexed, ocrText)
                VALUES (?, ?, 'image', ?, ?, 1, ?)
                """, arguments: [
                    "/perf/\(i).png",
                    "capture-\(i)",
                    i % 3 == 0 ? "Safari" : "Xcode",
                    Double(1_700_000_000 + i),
                    ocr,
                ])
                try db.execute(sql: """
                INSERT INTO captures_fts(rowid, name, ocrText, tags, provenance)
                VALUES (?, ?, ?, '', ?)
                """, arguments: [db.lastInsertedRowID, "capture-\(i)", ocr, i % 3 == 0 ? "Safari" : "Xcode"])
            }
        }
    }

    // MARK: - Migrations

    private nonisolated static func migrate(_ writer: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1", migrate: Self.migrateV1)
        // v2: auto-import dedup fingerprint (§9.6). Additive nullable column + partial
        // index over the non-null hashes that the dedup probe consults. Native captures
        // leave it null (deduped by their unique originalPath); auto-imports fill it.
        migrator.registerMigration("v2") { db in
            try db.execute(sql: "ALTER TABLE captures ADD COLUMN contentHash TEXT")
            try db.execute(sql: """
            CREATE INDEX idx_captures_contentHash ON captures(contentHash)
            WHERE contentHash IS NOT NULL
            """)
        }
        // v3: make the contentHash index UNIQUE (partial, over non-null hashes only) so
        // the database itself rejects a second row for the same content. This is the hard
        // backstop behind `insertIfNotIndexed`'s dedup probe: even if two concurrent
        // watcher-driven ingests both pass the probe before either commits, the loser's
        // INSERT raises SQLITE_CONSTRAINT and is recorded as a skipped duplicate rather
        // than persisted. Native captures keep a null hash and are unconstrained here
        // (they dedup by their unique originalPath instead). NULLs are distinct in SQLite
        // unique indexes, so multiple null-hash rows remain legal.
        migrator.registerMigration("v3") { db in
            try db.execute(sql: "DROP INDEX IF EXISTS idx_captures_contentHash")
            try db.execute(sql: """
            CREATE UNIQUE INDEX idx_captures_contentHash ON captures(contentHash)
            WHERE contentHash IS NOT NULL
            """)
        }
        do {
            try migrator.migrate(writer)
        } catch {
            throw LibraryError.databaseFailed("migrate: \(error)")
        }
    }

    /// v1 base schema. Provenance is nullable (never fabricated). durationSeconds is the
    /// VIDEO hook; metadataJSON + embedding are the deferred-AI hooks — all three MUST
    /// stay null in MVP and MUST NOT be read by any MVP code path (spec: forward-
    /// compatible reserved columns).
    private nonisolated static func migrateV1(_ db: Database) throws {
        try db.execute(sql: """
        CREATE TABLE captures (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            originalPath TEXT NOT NULL,
            missing INTEGER NOT NULL DEFAULT 0,
            name TEXT NOT NULL,
            nameIsManual INTEGER NOT NULL DEFAULT 0,
            mediaType TEXT NOT NULL DEFAULT 'image',
            durationSeconds DOUBLE,
            bundleID TEXT,
            appName TEXT,
            windowTitle TEXT,
            url TEXT,
            displayID INTEGER,
            capturedAt DOUBLE NOT NULL,
            textIndexed INTEGER NOT NULL DEFAULT 0,
            containsCode INTEGER NOT NULL DEFAULT 0,
            isKept INTEGER NOT NULL DEFAULT 0,
            ocrText TEXT,
            metadataJSON TEXT,
            embedding BLOB
        )
        """)

        // Indexes that back the §9.3 filters (app / date / type) and reveal-missing.
        try db.execute(sql: "CREATE INDEX idx_captures_appName ON captures(appName)")
        try db.execute(sql: "CREATE INDEX idx_captures_capturedAt ON captures(capturedAt)")
        try db.execute(sql: "CREATE INDEX idx_captures_mediaType ON captures(mediaType)")

        // FTS5 index over the searchable surface. `prefix='2 3'` keeps prefix
        // queries (term*) fast for short partials while typing. `rowid` is the
        // captures id so we can join back cheaply.
        try db.execute(sql: """
        CREATE VIRTUAL TABLE captures_fts USING fts5(
            name,
            ocrText,
            tags,
            provenance,
            prefix = '2 3'
        )
        """)

        // tags + junction (many-to-many). Deleting a tag removes associations,
        // never the captures (ON DELETE CASCADE on the junction only).
        try db.execute(sql: """
        CREATE TABLE tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE
        )
        """)
        try db.execute(sql: """
        CREATE TABLE capture_tags (
            captureID INTEGER NOT NULL REFERENCES captures(id) ON DELETE CASCADE,
            tagID INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
            PRIMARY KEY (captureID, tagID)
        )
        """)
        try db.execute(sql: "CREATE INDEX idx_capture_tags_tagID ON capture_tags(tagID)")
    }

    // MARK: - CRUD

    /// Insert a new capture row and its FTS entry; returns the record hydrated with
    /// its assigned id. `ocrText` is the recognized text to index (nil when OCR is
    /// pending or failed — the item is still inserted and findable by name/provenance).
    @discardableResult
    public func insert(_ record: CaptureRecord, ocrText: String? = nil) throws -> CaptureRecord {
        try write { db in
            try Self.insertRow(db, record, name: record.name, ocrText: ocrText)
        }
    }

    /// Insert with deterministic auto-name collision handling resolved INSIDE the
    /// write transaction (spec §9.2 "Collision handling"): the first capture keeps
    /// `baseSlug`; the next that would collide gets `baseSlug-2`, then `-3`, … No
    /// TOCTOU window — the uniqueness probe and the insert share one transaction.
    @discardableResult
    func insertResolvingCollision(
        _ record: CaptureRecord,
        baseSlug: String,
        ocrText: String? = nil
    ) throws -> CaptureRecord {
        try write { db in
            let name = try Self.resolveName(db, baseSlug: baseSlug, excludingID: nil)
            return try Self.insertRow(db, record, name: name, ocrText: ocrText)
        }
    }

    /// Fetch one record by id, or nil when absent.
    public func record(id: Int64) throws -> CaptureRecord? {
        try read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM captures WHERE id = ?", arguments: [id]) else {
                return nil
            }
            return Self.record(from: row)
        }
    }

    /// All records, newest capture first.
    public func allRecords() throws -> [CaptureRecord] {
        try read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM captures ORDER BY capturedAt DESC")
                .map(Self.record(from:))
        }
    }

    /// Flag a record's referenced file as missing on disk (reference-not-vault:
    /// the file was moved/deleted externally; we degrade honestly, never crash).
    public func markMissing(id: Int64, missing: Bool = true) throws {
        try write { db in
            try db.execute(sql: "UPDATE captures SET missing = ? WHERE id = ?", arguments: [missing, id])
            guard db.changesCount > 0 else { throw LibraryError.recordNotFound(id) }
        }
    }

    /// Delete a Library entry (and its FTS entry + tag associations). Does NOT touch
    /// the on-disk original — the caller decides the file's fate (spec: deleting an
    /// item states what happens to the underlying file).
    public func delete(id: Int64) throws {
        try write { db in
            try db.execute(sql: "DELETE FROM captures WHERE id = ?", arguments: [id])
            guard db.changesCount > 0 else { throw LibraryError.recordNotFound(id) }
            try db.execute(sql: "DELETE FROM captures_fts WHERE rowid = ?", arguments: [id])
            // capture_tags rows cascade via the FK.
        }
    }

    // MARK: - Indexing support (§9.2)

    /// Apply OCR/index (re-index) results to an existing item. A manual rename is
    /// sticky: the re-derived name from `baseSlug` is only applied when the row's
    /// `nameIsManual` is false. Collision resolution (excluding this row) happens in
    /// the same transaction. Re-syncs FTS.
    func applyIndexResult(
        id: Int64,
        baseSlug: String,
        ocrText: String?,
        textIndexed: Bool,
        containsCode: Bool
    ) throws {
        try write { db in
            guard let manual = try Bool.fetchOne(
                db, sql: "SELECT nameIsManual FROM captures WHERE id = ?", arguments: [id]
            ) else {
                throw LibraryError.recordNotFound(id)
            }
            if !manual {
                let name = try Self.resolveName(db, baseSlug: baseSlug, excludingID: id)
                try db.execute(sql: "UPDATE captures SET name = ? WHERE id = ?", arguments: [name, id])
            }
            try db.execute(sql: """
            UPDATE captures SET ocrText = ?, textIndexed = ?, containsCode = ? WHERE id = ?
            """, arguments: [ocrText, textIndexed, containsCode, id])
            try Self.syncFTS(db, captureID: id)
        }
    }

    /// Resolve `baseSlug` to a unique name within one open transaction, using
    /// `OneShotCore.AutoNamer.resolvingCollision` with a case-insensitive DB probe.
    /// Package-internal (not `private`) so the atomic dedup-insert path in
    /// `LibraryStoreDedupSupport.swift` can resolve the name inside the same transaction.
    nonisolated static func resolveName(
        _ db: Database,
        baseSlug: String,
        excludingID: Int64?
    ) throws -> String {
        var probeError: Error?
        let resolved = AutoNamer.resolvingCollision(of: baseSlug) { candidate in
            if probeError != nil { return false }
            do {
                let sql: String
                let args: StatementArguments
                if let excludingID {
                    sql = "SELECT 1 FROM captures WHERE name = ? COLLATE NOCASE AND id <> ? LIMIT 1"
                    args = [candidate, excludingID]
                } else {
                    sql = "SELECT 1 FROM captures WHERE name = ? COLLATE NOCASE LIMIT 1"
                    args = [candidate]
                }
                return try Bool.fetchOne(db, sql: sql, arguments: args) ?? false
            } catch {
                probeError = error
                return false
            }
        }
        if let probeError { throw probeError }
        return resolved
    }

    // MARK: - Internals

    /// Package-internal write escape hatch (mirrors `read`), used by same-module
    /// extensions in other files (§9.5 tag support). Not part of the public API.
    func write<T: Sendable>(_ work: @Sendable (Database) throws -> T) throws -> T {
        do {
            return try dbQueue.write(work)
        } catch let error as LibraryError {
            throw error
        } catch {
            throw LibraryError.databaseFailed("\(error)")
        }
    }
}

// MARK: - Naming + Tags

public extension LibraryStore {
    /// Record a user's manual rename. Sets `nameIsManual = 1` so re-indexing can
    /// never overwrite it (spec: "Manual rename is sticky").
    func rename(id: Int64, to name: String) throws {
        try write { db in
            try db.execute(
                sql: "UPDATE captures SET name = ?, nameIsManual = 1 WHERE id = ?",
                arguments: [name, id]
            )
            guard db.changesCount > 0 else { throw LibraryError.recordNotFound(id) }
            try Self.syncFTS(db, captureID: id)
        }
    }

    /// Add a tag (creating it if new) to a capture. Idempotent. Re-syncs FTS so the
    /// tag becomes searchable (spec: "tag terms included in search").
    func addTag(_ tagName: String, toCapture captureID: Int64) throws {
        try write { db in
            guard try Bool.fetchOne(db, sql: "SELECT 1 FROM captures WHERE id = ?", arguments: [captureID]) ?? false
            else {
                throw LibraryError.recordNotFound(captureID)
            }
            try db.execute(sql: "INSERT OR IGNORE INTO tags(name) VALUES (?)", arguments: [tagName])
            let tagID = try Int64.fetchOne(db, sql: "SELECT id FROM tags WHERE name = ?", arguments: [tagName])!
            try db.execute(
                sql: "INSERT OR IGNORE INTO capture_tags(captureID, tagID) VALUES (?, ?)",
                arguments: [captureID, tagID]
            )
            try Self.syncFTS(db, captureID: captureID)
        }
    }

    /// Delete a tag everywhere. Non-destructive: associated captures remain (spec:
    /// "Tag deletion is non-destructive"). Re-syncs FTS for affected captures.
    func deleteTag(_ tagName: String) throws {
        try write { db in
            guard let tagID = try Int64.fetchOne(db, sql: "SELECT id FROM tags WHERE name = ?", arguments: [tagName])
            else {
                return // already absent — nothing to do
            }
            let affected = try Int64.fetchAll(
                db, sql: "SELECT captureID FROM capture_tags WHERE tagID = ?", arguments: [tagID]
            )
            try db.execute(sql: "DELETE FROM tags WHERE id = ?", arguments: [tagID]) // cascades junction
            for captureID in affected {
                try Self.syncFTS(db, captureID: captureID)
            }
        }
    }

    /// Tags assigned to a capture, alphabetical.
    func tags(forCapture captureID: Int64) throws -> [String] {
        try read { db in
            try String.fetchAll(db, sql: """
            SELECT t.name FROM tags t
            JOIN capture_tags ct ON ct.tagID = t.id
            WHERE ct.captureID = ?
            ORDER BY t.name
            """, arguments: [captureID])
        }
    }
}

// MARK: - FTS + row hydration helpers

extension LibraryStore {
    /// Rebuild the FTS row for one capture from its current columns + tags. Called
    /// inside the same transaction as the originating write so the index never drifts.
    nonisolated static func syncFTS(_ db: Database, captureID: Int64) throws {
        guard let row = try Row.fetchOne(
            db, sql: "SELECT name, ocrText, appName, windowTitle, url, bundleID FROM captures WHERE id = ?",
            arguments: [captureID]
        ) else { return }

        let tags = try String.fetchAll(db, sql: """
        SELECT t.name FROM tags t JOIN capture_tags ct ON ct.tagID = t.id WHERE ct.captureID = ?
        """, arguments: [captureID]).joined(separator: " ")

        let provenance = [
            row["appName"] as String?,
            row["windowTitle"] as String?,
            row["url"] as String?,
            row["bundleID"] as String?,
        ].compactMap(\.self).joined(separator: " ")

        // FTS5 has no UPSERT; delete-then-insert keyed on rowid keeps it in sync.
        try db.execute(sql: "DELETE FROM captures_fts WHERE rowid = ?", arguments: [captureID])
        try db.execute(sql: """
        INSERT INTO captures_fts(rowid, name, ocrText, tags, provenance) VALUES (?, ?, ?, ?, ?)
        """, arguments: [
            captureID,
            (row["name"] as String?) ?? "",
            (row["ocrText"] as String?) ?? "",
            tags,
            provenance,
        ])
    }

    /// Hydrate a `CaptureRecord` value from a `captures` row.
    nonisolated static func record(from row: Row) -> CaptureRecord {
        CaptureRecord(
            id: row["id"],
            originalPath: row["originalPath"],
            missing: row["missing"],
            name: row["name"],
            nameIsManual: row["nameIsManual"],
            mediaType: MediaType(rawValue: row["mediaType"]) ?? .image,
            durationSeconds: row["durationSeconds"],
            provenance: CaptureProvenance(
                bundleID: row["bundleID"],
                appName: row["appName"],
                windowTitle: row["windowTitle"],
                url: row["url"],
                displayID: (row["displayID"] as Int64?).map { UInt32(truncatingIfNeeded: $0) }
            ),
            capturedAt: Date(timeIntervalSince1970: row["capturedAt"]),
            textIndexed: row["textIndexed"],
            containsCode: row["containsCode"],
            isKept: row["isKept"],
            contentHash: row["contentHash"]
        )
    }
}
