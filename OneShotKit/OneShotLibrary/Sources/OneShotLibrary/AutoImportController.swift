import Foundation

/// Orchestrates opt-in auto-import (spec §9.6): owns the watcher lifecycle, performs the
/// one-time backfill on first enable, and ingests files reported by the watcher — all
/// deduped through `AutoImporter`. An actor so its enabled-state and first-enable bit are
/// race-free across the watcher's arbitrary callback queue and the app's calls.
///
/// SURVIVES LAUNCH (spec): the "backfill already done" bit is supplied/persisted by the
/// app (e.g. a settings flag) and passed in, so re-launching with auto-import already on
/// resumes watching WITHOUT re-running the one-time backfill. The controller never reads
/// settings itself — the app gates construction on `AppSettings.autoImportEnabled`.
public actor AutoImportController {
    private let importer: AutoImporter
    private let watcher: any FileSystemWatching
    private var config: AutoImportConfig
    private var isWatching = false

    /// Fires after a live (watcher-driven) ingest pass with that pass's result, so the
    /// app can refresh the Library view / Spotlight donations. Optional; nil = no-op.
    private let onLiveImport: (@Sendable (AutoImportResult) -> Void)?

    public init(
        importer: AutoImporter,
        watcher: any FileSystemWatching = DispatchSourceFolderWatcher(),
        config: AutoImportConfig,
        onLiveImport: (@Sendable (AutoImportResult) -> Void)? = nil
    ) {
        self.importer = importer
        self.watcher = watcher
        self.config = config
        self.onLiveImport = onLiveImport
    }

    /// Count of importable, not-yet-indexed existing files — for the "Import N existing
    /// screenshots?" confirmation BEFORE the backfill runs (spec §9.6).
    public func backfillPreviewCount() async throws -> Int {
        try await importer.backfillPreviewCount(config: config)
    }

    /// Enable auto-import. On FIRST enable (`alreadyBackfilled == false`) the one-time
    /// backfill runs and its result is returned so the app can persist the "done" bit and
    /// show the count; on a subsequent launch (`alreadyBackfilled == true`) backfill is
    /// skipped and only live watching starts. Either way the watcher begins after this.
    @discardableResult
    public func enable(alreadyBackfilled: Bool) async throws -> AutoImportResult {
        let result: AutoImportResult = if alreadyBackfilled {
            AutoImportResult()
        } else {
            try await importer.backfill(config: config)
        }
        startWatching()
        return result
    }

    /// Disable auto-import: stop watching and release all OS resources (spec: disabling
    /// truly stops the watcher). Already-indexed items are untouched.
    public func disable() {
        watcher.stop()
        isWatching = false
    }

    /// Replace the watched-folder/extension config (e.g. user added a folder). Re-arms the
    /// watcher on the new set if currently enabled. Does not re-backfill — the app calls
    /// `enable(alreadyBackfilled:)` semantics separately if a new folder needs a backfill.
    public func updateConfig(_ newConfig: AutoImportConfig) {
        config = newConfig
        if isWatching { startWatching() }
    }

    // MARK: - Internals

    private func startWatching() {
        isWatching = true
        watcher.start(folders: config.watchedFolders) { [weak self] changedFolder in
            // Hop onto the actor; the watcher callback runs on an arbitrary queue.
            Task { await self?.handleFolderChange(changedFolder) }
        }
    }

    /// A watcher event means "something in this folder changed" (vnode events don't name
    /// the file). Re-scan the folder and ingest anything new; dedup makes the re-scan of
    /// already-indexed files a no-op (spec "No duplicate entries"). Per-file failures are
    /// isolated inside the importer.
    private func handleFolderChange(_ folder: String) async {
        let folderConfig = AutoImportConfig(
            watchedFolders: [folder],
            importableExtensions: config.importableExtensions
        )
        guard let result = try? await importer.backfill(config: folderConfig) else { return }
        if !result.imported.isEmpty { onLiveImport?(result) }
    }
}
