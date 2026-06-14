import CryptoKit
import Foundation

/// Configuration for the opt-in auto-import watcher (spec §9.6). The watcher is
/// DISABLED by default at the app layer (`AppSettings.autoImportEnabled == false`):
/// nothing is constructed, no folder is watched, no file is read until the user opts
/// in. This value type carries only WHICH folders to watch and WHICH file types count
/// as importable — the enable/disable gate lives in settings, not here.
public struct AutoImportConfig: Sendable, Hashable {
    /// Absolute paths of folders to watch + backfill. Typically the system screenshot
    /// location and `~/Desktop`, plus any user-added folders.
    public var watchedFolders: [String]
    /// Lowercased file extensions that count as importable images (no leading dot).
    public var importableExtensions: Set<String>

    public init(
        watchedFolders: [String],
        importableExtensions: Set<String> = AutoImportConfig.defaultImageExtensions
    ) {
        self.watchedFolders = watchedFolders
        self.importableExtensions = importableExtensions
    }

    /// The image types the macOS screenshot tools (and the common third-party tools)
    /// write. Deliberately image-only: video/`.1shot` bundles are NOT auto-imported.
    public static let defaultImageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "gif", "webp"]
}

/// Resolves the standard macOS screenshot locations to watch by default (spec §9.6:
/// "the configured system screenshot folder, Desktop default"). The system screenshot
/// path lives in the `com.apple.screencapture` `location` default; it is read READ-ONLY
/// (we never write that domain — house rule: guide+verify, never mutate system settings).
public enum ScreenshotFolderResolver {
    /// The standard folders to watch: the user-configured system screenshot location (if
    /// set and distinct) plus `~/Desktop` (the OS default sink). Deduped, tilde-expanded,
    /// absolute. `defaults` is injectable so this is testable without touching the real
    /// user domain.
    public static func standardFolders(
        defaults: UserDefaults? = UserDefaults(suiteName: "com.apple.screencapture"),
        homeDirectory: String = NSHomeDirectory()
    ) -> [String] {
        let desktop = (homeDirectory as NSString).appendingPathComponent("Desktop")
        var folders = [desktop]
        if let configured = defaults?.string(forKey: "location") {
            let expanded = (configured as NSString).expandingTildeInPath
            if !expanded.isEmpty, !folders.contains(expanded) {
                folders.insert(expanded, at: 0)
            }
        }
        return folders
    }
}

/// One file the scanner found in a watched folder, with the metadata the importer
/// needs to dedup and ingest it WITHOUT modifying the original (reference-not-vault).
public struct ImportCandidate: Sendable, Hashable {
    /// Absolute path of the user-visible original (never moved/renamed/modified).
    public var path: String
    /// File modification time — used as the capture timestamp (file-derived
    /// provenance only; we never fabricate an app/window/URL for an imported file).
    public var modifiedAt: Date
    /// Byte size, used to keep the content hash cheap and to skip empty files.
    public var sizeBytes: Int64

    public init(path: String, modifiedAt: Date, sizeBytes: Int64) {
        self.path = path
        self.modifiedAt = modifiedAt
        self.sizeBytes = sizeBytes
    }
}

/// Outcome of a backfill or a single live import pass (spec §9.6). `imported` are the
/// newly indexed records; `skippedDuplicates` are files already in the Library;
/// `failed` are paths that could not be read/indexed (honest: surfaced, never silently
/// dropped). A backfill confirmation UI shows `imported.count` after the user accepts.
public struct AutoImportResult: Sendable {
    public var imported: [CaptureRecord]
    public var skippedDuplicates: [String]
    public var failed: [String]

    public init(
        imported: [CaptureRecord] = [],
        skippedDuplicates: [String] = [],
        failed: [String] = []
    ) {
        self.imported = imported
        self.skippedDuplicates = skippedDuplicates
        self.failed = failed
    }
}

// MARK: - Directory scanning (injectable; FS-backed by default)

/// Enumerates importable files in a folder and fingerprints their content. Injectable
/// so the importer's dedup/backfill logic is headless-testable with an in-memory fake
/// — no real filesystem, no permissions, deterministic. The real adapter only ever
/// READS (reference-not-vault: originals are never moved, renamed, or modified).
public protocol DirectoryScanning: Sendable {
    /// Importable image candidates directly inside `folder` (non-recursive — screenshot
    /// folders are flat; recursion would sweep unrelated trees). Order is unspecified.
    func scan(folder: String, allowedExtensions: Set<String>) throws -> [ImportCandidate]

    /// Content fingerprint for the file at `path` (for dedup). Returns nil when the
    /// file can't be read — the importer then degrades to path-only dedup, never crashes.
    func contentHash(forFileAt path: String) -> String?
}

/// Production `DirectoryScanning`: FileManager enumeration + SHA-256 streamed over the
/// file. READ-ONLY by construction. Streaming the hash in fixed chunks keeps memory
/// bounded for large screenshots; an unreadable file yields a nil hash (honest fallback).
public struct FileManagerDirectoryScanner: DirectoryScanning {
    public init() {}

    public func scan(folder: String, allowedExtensions: Set<String>) throws -> [ImportCandidate] {
        // `FileManager.default` is the documented thread-safe singleton for these
        // read-only enumeration calls; using it directly keeps the scanner `Sendable`.
        let url = URL(fileURLWithPath: folder, isDirectory: true)
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]
        let entries: [URL]
        do {
            entries = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            )
        } catch {
            throw LibraryError.databaseFailed("scan(\(folder)): \(error)")
        }

        return entries.compactMap { entry in
            guard allowedExtensions.contains(entry.pathExtension.lowercased()) else { return nil }
            let values = try? entry.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile == true else { return nil }
            let size = Int64(values?.fileSize ?? 0)
            guard size > 0 else { return nil }
            return ImportCandidate(
                path: entry.path,
                modifiedAt: values?.contentModificationDate ?? Date(),
                sizeBytes: size
            )
        }
    }

    public func contentHash(forFileAt path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        let chunkSize = 1 << 18 // 256 KiB
        while let chunk = try? handle.read(upToCount: chunkSize), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
