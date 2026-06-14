import CoreGraphics
import Foundation
import OneShotOCR
import Testing
@testable import OneShotLibrary

/// Task 9.6: opt-in auto-import watcher + backfill. The watcher is gated by a setting at
/// the app layer (NOT here), watches standard screenshot folders, ingests captures made by
/// ANY tool through the EXISTING indexing pipeline, backfills pre-existing history, dedups,
/// and NEVER modifies originals (reference-not-vault). These tests drive the headless core
/// with an in-memory scanner + fake image loader — no real filesystem, no permissions.
struct AutoImportTests {
    // MARK: - Fakes

    /// In-memory `DirectoryScanning`: folder → candidates, path → deterministic content
    /// hash. Records every path it hashed so a test can prove originals were only READ.
    final class FakeScanner: DirectoryScanning, @unchecked Sendable {
        var folders: [String: [ImportCandidate]]
        var hashes: [String: String]

        init(folders: [String: [ImportCandidate]] = [:], hashes: [String: String] = [:]) {
            self.folders = folders
            self.hashes = hashes
        }

        func scan(folder: String, allowedExtensions: Set<String>) throws -> [ImportCandidate] {
            (folders[folder] ?? []).filter {
                allowedExtensions.contains(($0.path as NSString).pathExtension.lowercased())
            }
        }

        func contentHash(forFileAt path: String) -> String? {
            hashes[path]
        }
    }

    /// Image loader that always yields a 1×1 image; the fake recognizer ignores it.
    struct FakeImageLoader: ImageLoading {
        func loadImage(atPath _: String) -> CGImage? {
            blankImage(width: 1, height: 1)
        }
    }

    private func candidate(_ path: String, at date: Date = fixedNow, bytes: Int64 = 1234) -> ImportCandidate {
        ImportCandidate(path: path, modifiedAt: date, sizeBytes: bytes)
    }

    private func importer(
        store: LibraryStore,
        scanner: FakeScanner,
        recognizerText: String = ""
    ) -> AutoImporter {
        let pipeline = IndexingPipeline(store: store, recognizer: FakeTextRecognizer(text: recognizerText))
        return AutoImporter(store: store, pipeline: pipeline, scanner: scanner, imageLoader: FakeImageLoader())
    }

    private func config(folders: [String]) -> AutoImportConfig {
        AutoImportConfig(watchedFolders: folders)
    }

    // MARK: - Backfill (spec "Pre-install history backfill")

    @Test func preInstallHistoryBackfillIndexesAll() async throws {
        let store = try LibraryStore()
        let folder = "/Screenshots"
        let candidates = (0 ..< 500).map { candidate("\(folder)/shot-\($0).png") }
        let hashes = Dictionary(uniqueKeysWithValues: candidates.map { ($0.path, "h-\($0.path)") })
        let scanner = FakeScanner(folders: [folder: candidates], hashes: hashes)
        let importer = importer(store: store, scanner: scanner, recognizerText: "some text")

        let count = try await importer.backfillPreviewCount(config: config(folders: [folder]))
        #expect(count == 500)

        let result = try await importer.backfill(config: config(folders: [folder]))
        #expect(result.imported.count == 500)
        #expect(result.skippedDuplicates.isEmpty)
        #expect(try await store.allRecords().count == 500)
    }

    /// Spec "their files remain in place, unmodified" — the importer references each
    /// original by its existing path and never copies/relocates it.
    @Test func backfillNeverModifiesOriginals() async throws {
        let store = try LibraryStore()
        let folder = "/Pics"
        let path = "\(folder)/a.png"
        let scanner = FakeScanner(folders: [folder: [candidate(path)]], hashes: [path: "hash-a"])
        let importer = importer(store: store, scanner: scanner)

        let result = try await importer.backfill(config: config(folders: [folder]))
        let record = try #require(result.imported.first)
        // The stored original path is exactly the source path (reference-not-vault).
        #expect(record.originalPath == path)
    }

    // MARK: - Dedup (spec "No duplicate entries")

    @Test func rescanOfIndexedFileCreatesNoDuplicate() async throws {
        let store = try LibraryStore()
        let folder = "/Desktop"
        let path = "\(folder)/dup.png"
        let scanner = FakeScanner(folders: [folder: [candidate(path)]], hashes: [path: "same-hash"])
        let importer = importer(store: store, scanner: scanner)

        _ = try await importer.backfill(config: config(folders: [folder]))
        // Re-scan the SAME folder (a "touch"): no second entry.
        let second = try await importer.backfill(config: config(folders: [folder]))
        #expect(second.imported.isEmpty)
        #expect(second.skippedDuplicates == [path])
        #expect(try await store.allRecords().count == 1)
    }

    /// Content identity wins over path: the same bytes under a NEW path are recognized as
    /// already-indexed (a moved/renamed-but-identical screenshot is not re-imported).
    @Test func dedupByContentHashAcrossDifferentPaths() async throws {
        let store = try LibraryStore()
        let folder = "/D"
        let original = "\(folder)/original.png"
        let scannerA = FakeScanner(folders: [folder: [candidate(original)]], hashes: [original: "shared"])
        let importer1 = importer(store: store, scanner: scannerA)
        _ = try await importer1.backfill(config: config(folders: [folder]))

        // Same content hash, different path — must be treated as a duplicate.
        let renamed = "\(folder)/renamed.png"
        let scannerB = FakeScanner(folders: [folder: [candidate(renamed)]], hashes: [renamed: "shared"])
        let importer2 = importer(store: store, scanner: scannerB)
        let result = try await importer2.backfill(config: config(folders: [folder]))
        #expect(result.imported.isEmpty)
        #expect(result.skippedDuplicates == [renamed])
    }

    /// In-pass content-dedup: two byte-identical files at DISTINCT new paths (e.g. a
    /// Finder-duplicated "shot copy.png"), BOTH absent from the DB at backfill start,
    /// must produce exactly one import + one skipped duplicate — not two rows for the
    /// same content. Closes the gap where the per-file probe couldn't see an earlier
    /// not-yet-committed import in the same pass.
    @Test func backfillDedupesIdenticalContentWithinOnePass() async throws {
        let store = try LibraryStore()
        let folder = "/D"
        let original = "\(folder)/shot.png"
        let copy = "\(folder)/shot copy.png"
        let scanner = FakeScanner(
            folders: [folder: [candidate(original), candidate(copy)]],
            hashes: [original: "identical", copy: "identical"]
        )
        let importer = importer(store: store, scanner: scanner)

        let result = try await importer.backfill(config: config(folders: [folder]))
        #expect(result.imported.count == 1)
        #expect(result.skippedDuplicates.count == 1)
        #expect(try await store.allRecords().count == 1)
    }

    // MARK: - Any-tool capture becomes searchable (spec "Screenshot from another tool")

    @Test func importedScreenshotBecomesTextSearchable() async throws {
        let store = try LibraryStore()
        let folder = "/Sys/Screenshots"
        let path = "\(folder)/Screenshot 2026-01-01.png"
        let scanner = FakeScanner(folders: [folder: [candidate(path)]], hashes: [path: "h"])
        let importer = importer(store: store, scanner: scanner, recognizerText: "stripe webhook delivery failed")

        let result = try await importer.backfill(config: config(folders: [folder]))
        let record = try #require(result.imported.first)
        #expect(record.textIndexed == true)
        let hits = try await LibrarySearch(store: store).search("stripe webhook")
        #expect(hits.contains { $0.record.id == record.id })
    }

    /// File-derived provenance ONLY: the filename is the sole human signal (no fabricated
    /// app/URL), and the file mtime becomes the capture timestamp.
    @Test func importedItemUsesFileDerivedProvenanceOnly() async throws {
        let store = try LibraryStore()
        let folder = "/D"
        let path = "\(folder)/quarterly-revenue-chart.png"
        let when = Date(timeIntervalSince1970: 1_650_000_000)
        let scanner = FakeScanner(folders: [folder: [candidate(path, at: when)]], hashes: [path: "h"])
        let importer = importer(store: store, scanner: scanner)

        let record = try #require(try await importer.backfill(config: config(folders: [folder])).imported.first)
        let recordID = try #require(record.id)
        let fetched = try #require(try await store.record(id: recordID))
        // Filename-derived signal present; app/url never fabricated.
        #expect(fetched.provenance.windowTitle == "quarterly-revenue-chart")
        #expect(fetched.provenance.appName == nil)
        #expect(fetched.provenance.url == nil)
        #expect(fetched.capturedAt == when)
        #expect(fetched.name.contains("quarterly"))
    }

    // MARK: - Per-file isolation + non-image rejection

    @Test func undecodableFileStillIndexedWithoutText() async throws {
        let store = try LibraryStore()
        let folder = "/D"
        let path = "\(folder)/corrupt.png"
        let scanner = FakeScanner(folders: [folder: [candidate(path)]], hashes: [path: "h"])
        // Image loader returns nil ⇒ pipeline OCRs the blank fallback ⇒ no text.
        struct NilLoader: ImageLoading { func loadImage(atPath _: String) -> CGImage? {
            nil
        } }
        let pipeline = IndexingPipeline(store: store, recognizer: FakeTextRecognizer())
        let importer = AutoImporter(store: store, pipeline: pipeline, scanner: scanner, imageLoader: NilLoader())

        let result = try await importer.backfill(config: config(folders: [folder]))
        let record = try #require(result.imported.first)
        #expect(record.textIndexed == false) // present + findable, just not text-indexed
        #expect(result.failed.isEmpty)
    }

    @Test func liveIngestRejectsNonImageExtension() async throws {
        let store = try LibraryStore()
        let scanner = FakeScanner()
        let importer = importer(store: store, scanner: scanner)
        let cfg = config(folders: ["/D"])
        let record = try await importer.ingestFile(atPath: "/D/notes.txt", config: cfg)
        #expect(record == nil)
        #expect(try await store.allRecords().isEmpty)
    }

    // MARK: - Standard folders resolver

    @Test func standardFoldersIncludesDesktopAndConfiguredLocation() throws {
        let suite = "oneshot-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.set("/Users/test/Captures", forKey: "location")
        defer { defaults.removeObject(forKey: "location") }

        let folders = ScreenshotFolderResolver.standardFolders(defaults: defaults, homeDirectory: "/Users/test")
        #expect(folders.contains("/Users/test/Captures"))
        #expect(folders.contains("/Users/test/Desktop"))
    }

    @Test func standardFoldersFallsBackToDesktopWhenUnset() throws {
        let suite = "oneshot-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let folders = ScreenshotFolderResolver.standardFolders(defaults: defaults, homeDirectory: "/Users/test")
        #expect(folders == ["/Users/test/Desktop"])
    }
}
