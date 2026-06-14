import CoreGraphics
import Foundation
import OneShotOCR
import Testing
@testable import OneShotLibrary

/// Task 9.6 (orchestration): the controller performs the one-time backfill on first
/// enable, survives launch (skips backfill when already done), reacts to watcher events by
/// re-scanning + ingesting (deduped), and stops watching on disable. Driven with a fake
/// watcher that fires synthetic folder-change events — no real FSEvents, deterministic.
struct AutoImportControllerTests {
    /// Fake `FileSystemWatching`: captures the onChange callback so a test can fire
    /// synthetic folder-change events, and records start/stop for lifecycle assertions.
    final class FakeWatcher: FileSystemWatching, @unchecked Sendable {
        private let lock = NSLock()
        private var onChange: (@Sendable (String) -> Void)?
        private(set) var startCount = 0
        private(set) var stopCount = 0
        private(set) var watchedFolders: [String] = []

        func start(folders: [String], onChange: @escaping @Sendable (String) -> Void) {
            lock.lock(); defer { lock.unlock() }
            startCount += 1
            watchedFolders = folders
            self.onChange = onChange
        }

        func stop() {
            lock.lock(); defer { lock.unlock() }
            stopCount += 1
            onChange = nil
        }

        /// Fire a synthetic change for `folder` (as the OS would on a new file).
        func fire(_ folder: String) {
            lock.lock(); let callback = onChange; lock.unlock()
            callback?(folder)
        }
    }

    final class MutableScanner: DirectoryScanning, @unchecked Sendable {
        private let lock = NSLock()
        private var folders: [String: [ImportCandidate]]
        private var hashes: [String: String]

        init(folders: [String: [ImportCandidate]] = [:], hashes: [String: String] = [:]) {
            self.folders = folders
            self.hashes = hashes
        }

        func add(_ path: String, to folder: String, hash: String) {
            lock.lock(); defer { lock.unlock() }
            folders[folder, default: []].append(ImportCandidate(path: path, modifiedAt: fixedNow, sizeBytes: 10))
            hashes[path] = hash
        }

        func scan(folder: String, allowedExtensions: Set<String>) throws -> [ImportCandidate] {
            lock.lock(); defer { lock.unlock() }
            return (folders[folder] ?? []).filter {
                allowedExtensions.contains(($0.path as NSString).pathExtension.lowercased())
            }
        }

        func contentHash(forFileAt path: String) -> String? {
            lock.lock(); defer { lock.unlock() }
            return hashes[path]
        }
    }

    struct FakeImageLoader: ImageLoading {
        func loadImage(atPath _: String) -> CGImage? {
            blankImage(width: 1, height: 1)
        }
    }

    private func makeController(
        store: LibraryStore,
        scanner: MutableScanner,
        watcher: FakeWatcher,
        folder: String
    ) -> AutoImportController {
        let pipeline = IndexingPipeline(store: store, recognizer: FakeTextRecognizer(text: "text"))
        let importer = AutoImporter(store: store, pipeline: pipeline, scanner: scanner, imageLoader: FakeImageLoader())
        return AutoImportController(
            importer: importer,
            watcher: watcher,
            config: AutoImportConfig(watchedFolders: [folder])
        )
    }

    /// First enable runs the backfill (existing history imported) and starts watching.
    @Test func firstEnableBackfillsAndStartsWatching() async throws {
        let store = try LibraryStore()
        let scanner = MutableScanner()
        let watcher = FakeWatcher()
        scanner.add("/D/old1.png", to: "/D", hash: "h1")
        scanner.add("/D/old2.png", to: "/D", hash: "h2")
        let controller = makeController(store: store, scanner: scanner, watcher: watcher, folder: "/D")

        let result = try await controller.enable(alreadyBackfilled: false)
        #expect(result.imported.count == 2)
        #expect(watcher.startCount == 1)
        #expect(try await store.allRecords().count == 2)
    }

    /// Survives launch: enabling when the backfill bit is already set skips the backfill
    /// (no re-import of existing history) but still resumes live watching.
    @Test func enableWhenAlreadyBackfilledSkipsBackfillButWatches() async throws {
        let store = try LibraryStore()
        let scanner = MutableScanner()
        let watcher = FakeWatcher()
        scanner.add("/D/old.png", to: "/D", hash: "h")
        let controller = makeController(store: store, scanner: scanner, watcher: watcher, folder: "/D")

        let result = try await controller.enable(alreadyBackfilled: true)
        #expect(result.imported.isEmpty) // backfill skipped
        #expect(watcher.startCount == 1) // still watching
        #expect(try await store.allRecords().isEmpty)
    }

    /// A watcher event triggers a re-scan that ingests the newly appeared file — this is
    /// the "screenshot from another tool gets indexed" path.
    @Test func watcherEventIngestsNewFile() async throws {
        let store = try LibraryStore()
        let scanner = MutableScanner()
        let watcher = FakeWatcher()
        let controller = makeController(store: store, scanner: scanner, watcher: watcher, folder: "/D")
        _ = try await controller.enable(alreadyBackfilled: true)
        #expect(try await store.allRecords().isEmpty)

        // A new screenshot lands, then the OS fires a change for the folder.
        scanner.add("/D/new.png", to: "/D", hash: "new-hash")
        watcher.fire("/D")

        try await pollUntil { try await store.allRecords().count == 1 }
        #expect(try await store.allRecords().count == 1)
    }

    /// Repeated watcher events over the same file do not create duplicates (dedup).
    @Test func repeatedWatcherEventsDoNotDuplicate() async throws {
        let store = try LibraryStore()
        let scanner = MutableScanner()
        let watcher = FakeWatcher()
        let controller = makeController(store: store, scanner: scanner, watcher: watcher, folder: "/D")
        _ = try await controller.enable(alreadyBackfilled: true)

        scanner.add("/D/x.png", to: "/D", hash: "x")
        watcher.fire("/D")
        try await pollUntil { try await store.allRecords().count == 1 }
        watcher.fire("/D") // same file again — no new entry
        watcher.fire("/D")
        // Give any spurious ingest a chance to (incorrectly) land before asserting.
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(try await store.allRecords().count == 1)
    }

    /// Disable stops the watcher and releases it (spec: disabling truly stops watching).
    @Test func disableStopsWatcher() async throws {
        let store = try LibraryStore()
        let scanner = MutableScanner()
        let watcher = FakeWatcher()
        let controller = makeController(store: store, scanner: scanner, watcher: watcher, folder: "/D")
        _ = try await controller.enable(alreadyBackfilled: true)
        await controller.disable()
        #expect(watcher.stopCount == 1)
    }

    /// Poll an async condition with a bounded timeout so the actor-hop ingest has time to
    /// land without an arbitrary fixed sleep.
    private func pollUntil(
        timeout: TimeInterval = 2.0,
        _ condition: @Sendable () async throws -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if try await condition() { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        Issue.record("condition not met within \(timeout)s")
    }
}
