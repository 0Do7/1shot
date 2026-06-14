import Foundation
import GRDB
import Testing
@testable import OneShotLibrary

/// Task 9.1: GRDB store — captures table, reserved forward-compat columns, FTS5
/// index, migrations, reference-not-vault file handling, CRUD + tags.
struct LibraryStoreTests {
    private func newStore() throws -> LibraryStore {
        try LibraryStore()
    }

    private func sampleRecord(
        path: String = "/Users/me/Screenshots/shot.png",
        name: String = "shot",
        app: String? = "Xcode"
    ) -> CaptureRecord {
        CaptureRecord(
            originalPath: path,
            name: name,
            provenance: CaptureProvenance(bundleID: "com.apple.dt.Xcode", appName: app),
            capturedAt: fixedNow
        )
    }

    // MARK: CRUD

    @Test func insertAndFetchRoundTrips() async throws {
        let store = try newStore()
        let inserted = try await store.insert(sampleRecord())
        #expect(inserted.id != nil)

        let fetched = try await store.record(id: #require(inserted.id))
        #expect(fetched?.originalPath == "/Users/me/Screenshots/shot.png")
        #expect(fetched?.provenance.appName == "Xcode")
        #expect(fetched?.missing == false)
    }

    /// Spec §9.1 "Files are user-visible" — the DB stores a reference (absolute path),
    /// never the only copy. We assert the path is stored verbatim and unmodified.
    @Test func filesAreUserVisible() async throws {
        let store = try newStore()
        let path = "/Users/me/Desktop/My Screenshot.png"
        let inserted = try await store.insert(sampleRecord(path: path))
        let fetched = try await store.record(id: #require(inserted.id))
        #expect(fetched?.originalPath == path)
    }

    /// Spec §9.1 "Externally deleted file" — markMissing flags the row; nothing crashes.
    @Test func externallyDeletedFile() async throws {
        let store = try newStore()
        let inserted = try await store.insert(sampleRecord())
        try await store.markMissing(id: #require(inserted.id))
        let fetched = try await store.record(id: #require(inserted.id))
        #expect(fetched?.missing == true)

        // ...and the dangling entry can be removed without affecting other rows.
        try await store.delete(id: #require(inserted.id))
        #expect(try await store.record(id: #require(inserted.id)) == nil)
    }

    @Test func deleteMissingRowThrowsTyped() async throws {
        let store = try newStore()
        await #expect(throws: LibraryError.recordNotFound(999)) {
            try await store.delete(id: 999)
        }
    }

    // MARK: Schema / forward-compat

    /// Spec §9.1 "Reserved columns exist and stay null" — durationSeconds (video hook),
    /// metadataJSON + embedding (deferred-AI hooks) exist after v1 and are null for
    /// image captures produced by MVP code paths.
    @Test func reservedColumnsExistAndStayNull() async throws {
        let store = try newStore()
        let inserted = try await store.insert(sampleRecord())
        let id = try #require(inserted.id)

        let probe = try await store.read { db -> ReservedColumnProbe in
            let columns = try db.columns(in: "captures").map(\.name)
            func isNull(_ column: String) throws -> Bool {
                try Bool.fetchOne(
                    db,
                    sql: "SELECT \(column) IS NULL FROM captures WHERE id = ?",
                    arguments: [id]
                ) ?? false
            }
            return try ReservedColumnProbe(
                columns: Set(columns),
                durationNull: isNull("durationSeconds"),
                metadataNull: isNull("metadataJSON"),
                embeddingNull: isNull("embedding")
            )
        }
        #expect(probe.columns.isSuperset(of: ["durationSeconds", "metadataJSON", "embedding"]))
        #expect(probe.durationNull)
        #expect(probe.metadataNull)
        #expect(probe.embeddingNull)
    }

    /// Read-transaction result for `reservedColumnsExistAndStayNull`, replacing a
    /// 4-tuple so each reserved column's presence + null-ness is named.
    private struct ReservedColumnProbe {
        var columns: Set<String>
        var durationNull: Bool
        var metadataNull: Bool
        var embeddingNull: Bool
    }

    /// Spec §9.1 "Migration path from v1" — opening an existing DB file again applies
    /// no further migrations and preserves items, names, tags, and OCR index entries.
    @Test func migrationPathFromV1() async throws {
        let dir = NSTemporaryDirectory() + "oneshot-lib-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let path = dir + "/library.sqlite"

        let id: Int64
        do {
            let store = try LibraryStore(path: path)
            let inserted = try await store.insert(
                sampleRecord(name: "stripe-webhook-error"),
                ocrText: "stripe webhook error"
            )
            id = try #require(inserted.id)
            try await store.addTag("bug-123", toCapture: id)
        }

        // Reopen the same file: migration is idempotent; data survives.
        let reopened = try LibraryStore(path: path)
        let fetched = try await reopened.record(id: id)
        #expect(fetched?.name == "stripe-webhook-error")
        #expect(try await reopened.tags(forCapture: id) == ["bug-123"])
        let hits = try await LibrarySearch(store: reopened).search("stripe webhook")
        #expect(hits.contains { $0.record.id == id })

        // Each registered migration is applied exactly once (no double-migration): v1
        // (base schema) + v2 (additive auto-import contentHash column, §9.6) + v3
        // (UNIQUE partial index on contentHash — the dedup backstop, §9.6).
        let applied = try await reopened.read { db in
            try String.fetchAll(db, sql: "SELECT identifier FROM grdb_migrations ORDER BY identifier")
        }
        #expect(applied == ["v1", "v2", "v3"])
    }

    // MARK: Atomic dedup + insert (§9.6 "No duplicate entries")

    /// `insertIfNotIndexed` does the dedup probe and the insert in one transaction: the
    /// first call inserts; a second call with the SAME content hash (even at a new path)
    /// returns `.duplicate` and leaves exactly one row.
    @Test func insertIfNotIndexedDedupesByContentHash() async throws {
        let store = try newStore()
        var record = sampleRecord(path: "/a.png", name: "shot")
        record.contentHash = "shared-hash"

        guard case .inserted = try await store.insertIfNotIndexed(record, baseSlug: "shot") else {
            Issue.record("first insert should succeed")
            return
        }

        var moved = sampleRecord(path: "/b.png", name: "shot")
        moved.contentHash = "shared-hash" // same bytes, different path
        guard case .duplicate = try await store.insertIfNotIndexed(moved, baseSlug: "shot") else {
            Issue.record("second insert with same hash should be a duplicate")
            return
        }
        #expect(try await store.allRecords().count == 1)
    }

    /// Hard DB backstop: the UNIQUE partial index on contentHash rejects a second row for
    /// the same content even when written through the raw `insert` path (which does NOT
    /// probe). A null hash is unconstrained, so native captures still coexist freely.
    @Test func uniqueContentHashIndexRejectsDuplicateRow() async throws {
        let store = try newStore()
        var a = sampleRecord(path: "/a.png", name: "a")
        a.contentHash = "dup"
        _ = try await store.insert(a)

        var b = sampleRecord(path: "/b.png", name: "b")
        b.contentHash = "dup"
        await #expect(throws: LibraryError.self) {
            _ = try await store.insert(b)
        }
        #expect(try await store.allRecords().count == 1)

        // Two null-hash rows (native captures) remain legal under the partial index.
        _ = try await store.insert(sampleRecord(path: "/c.png", name: "c"))
        _ = try await store.insert(sampleRecord(path: "/d.png", name: "d"))
        #expect(try await store.allRecords().count == 3)
    }

    // MARK: Tags

    /// Spec §9.x "Manual tagging" — a tag round-trips and is idempotent.
    @Test func addTagIsIdempotent() async throws {
        let store = try newStore()
        let inserted = try await store.insert(sampleRecord())
        let id = try #require(inserted.id)
        try await store.addTag("bug-123", toCapture: id)
        try await store.addTag("bug-123", toCapture: id) // no duplicate
        #expect(try await store.tags(forCapture: id) == ["bug-123"])
    }

    /// Spec "Tag deletion is non-destructive" — deleting a tag removes it from items
    /// without deleting any item.
    @Test func tagDeletionIsNonDestructive() async throws {
        let store = try newStore()
        let a = try try await #require(store.insert(sampleRecord(path: "/a.png", name: "a")).id)
        let b = try try await #require(store.insert(sampleRecord(path: "/b.png", name: "b")).id)
        try await store.addTag("bug-123", toCapture: a)
        try await store.addTag("bug-123", toCapture: b)

        try await store.deleteTag("bug-123")

        #expect(try await store.record(id: a) != nil)
        #expect(try await store.record(id: b) != nil)
        #expect(try await store.tags(forCapture: a).isEmpty)
        #expect(try await store.tags(forCapture: b).isEmpty)
    }

    /// Deleting a capture cascades its tag associations but never the tags table rows
    /// that other captures still use is irrelevant here — assert the junction clears.
    @Test func deleteCaptureCascadesTagAssociations() async throws {
        let store = try newStore()
        let id = try try await #require(store.insert(sampleRecord()).id)
        try await store.addTag("keep", toCapture: id)
        try await store.delete(id: id)
        let orphans = try await store.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM capture_tags WHERE captureID = ?", arguments: [id]) ?? -1
        }
        #expect(orphans == 0)
    }
}
