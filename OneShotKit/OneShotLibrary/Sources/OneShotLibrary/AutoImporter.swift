import CoreGraphics
import Foundation
import ImageIO

/// Loads a file's pixels for OCR. Injectable so the importer is headless-testable with
/// a fake (a blank image, no real decode). The production adapter uses ImageIO —
/// READ-ONLY, never writes back to the source (reference-not-vault).
public protocol ImageLoading: Sendable {
    /// Decode the image at `path`, or nil when it can't be decoded (the importer then
    /// still indexes the item by file-derived metadata with no OCR text — honest).
    func loadImage(atPath path: String) -> CGImage?
}

/// Production `ImageLoading`: ImageIO decode of the first frame. No mutation of the
/// source file. CoreGraphics/ImageIO is portability-legal here (OneShotLibrary is not
/// the portability-restricted OneShotCore/OneShotRender).
public struct ImageIOImageLoader: ImageLoading {
    public init() {}

    public func loadImage(atPath path: String) -> CGImage? {
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

/// Auto-imports external screenshots into the Library (spec §9.6). Drives the EXISTING
/// `IndexingPipeline` so imported items get the same OCR indexing + heuristic naming as
/// native captures, but with FILE-DERIVED PROVENANCE ONLY (filename → window-title-like
/// signal; mtime → capture time; no fabricated app/URL). Dedup is enforced before every
/// insert. Originals are NEVER moved, renamed, or modified — this type only reads.
///
/// Opt-in (spec "Disabled by default"): the app constructs and runs this ONLY when the
/// user has enabled auto-import. Nothing here watches or reads on its own.
public struct AutoImporter: Sendable {
    private let store: LibraryStore
    private let pipeline: IndexingPipeline
    private let scanner: any DirectoryScanning
    private let imageLoader: any ImageLoading

    public init(
        store: LibraryStore,
        pipeline: IndexingPipeline,
        scanner: any DirectoryScanning = FileManagerDirectoryScanner(),
        imageLoader: any ImageLoading = ImageIOImageLoader()
    ) {
        self.store = store
        self.pipeline = pipeline
        self.scanner = scanner
        self.imageLoader = imageLoader
    }

    /// Count importable, not-yet-indexed files across the config's folders WITHOUT
    /// importing anything (spec §9.6: "a count shown before confirmation"). Lets the
    /// first-enable UI present "Import N existing screenshots?" before any work.
    public func backfillPreviewCount(config: AutoImportConfig) async throws -> Int {
        var count = 0
        for candidate in try scanCandidates(config: config) {
            let hash = scanner.contentHash(forFileAt: candidate.path)
            if try await store.isAlreadyIndexed(path: candidate.path, contentHash: hash) { continue }
            count += 1
        }
        return count
    }

    /// One-time pre-install backfill (spec §9.6 "Pre-install history backfill"): index
    /// every not-yet-indexed importable file found in the watched folders. Files remain
    /// in place, unmodified. Per-file failure is isolated — one unreadable file never
    /// aborts the backfill (it lands in `failed`); duplicates land in `skippedDuplicates`.
    public func backfill(config: AutoImportConfig) async throws -> AutoImportResult {
        var result = AutoImportResult()
        var seenHashes: Set<String> = []
        for candidate in try scanCandidates(config: config) {
            await ingest(candidate, into: &result, seenHashes: &seenHashes)
        }
        return result
    }

    /// Live import of a single file the watcher reported as new/changed. Idempotent via
    /// dedup, so a touched/re-scanned already-indexed file produces NO second entry
    /// (spec §9.6 "No duplicate entries"). Returns the new record, or nil when the file
    /// was a duplicate, unreadable, or not an importable type.
    @discardableResult
    public func ingestFile(atPath path: String, config: AutoImportConfig) async throws -> CaptureRecord? {
        let ext = (path as NSString).pathExtension.lowercased()
        guard config.importableExtensions.contains(ext) else { return nil }
        guard let candidate = candidateMetadata(forPath: path) else { return nil }
        var result = AutoImportResult()
        var seenHashes: Set<String> = []
        await ingest(candidate, into: &result, seenHashes: &seenHashes)
        return result.imported.first
    }

    // MARK: - Internals

    /// All importable candidates across every watched folder. A folder that can't be
    /// scanned (missing/permission) is skipped rather than failing the whole pass —
    /// the watcher may report a folder that was just removed.
    private func scanCandidates(config: AutoImportConfig) throws -> [ImportCandidate] {
        var all: [ImportCandidate] = []
        for folder in config.watchedFolders {
            let found = (try? scanner.scan(folder: folder, allowedExtensions: config.importableExtensions)) ?? []
            all.append(contentsOf: found)
        }
        return all
    }

    /// Dedup → load → index ONE candidate, recording the outcome. Never throws on a
    /// per-file problem (per-item isolation): unreadable/undecodable files are recorded
    /// in `failed`/indexed-without-text, and indexing continues for the rest.
    ///
    /// Dedup is atomic in the store: the path/content-hash probe and the insert share one
    /// transaction (`indexIfNotDuplicate`), so two concurrent watcher events for the same
    /// just-arrived file can't both pass the probe and both insert. `seenHashes` is an
    /// in-pass fast path that skips a byte-identical second file (e.g. "shot copy.png")
    /// without a redundant insert attempt; the store's UNIQUE(contentHash) backstops it
    /// regardless of whether the caller threads a set through.
    private func ingest(
        _ candidate: ImportCandidate,
        into result: inout AutoImportResult,
        seenHashes: inout Set<String>
    ) async {
        let hash = scanner.contentHash(forFileAt: candidate.path)
        // In-pass content-dedup: a hash already imported earlier in THIS pass is a
        // duplicate even though the first row may not be committed/visible to a fresh
        // probe yet. Path identity is handled by the store probe (paths are unique).
        if let hash, seenHashes.contains(hash) {
            result.skippedDuplicates.append(candidate.path)
            return
        }
        do {
            let input = IndexingPipeline.CaptureInput(
                originalPath: candidate.path,
                provenance: Self.fileDerivedProvenance(forPath: candidate.path),
                capturedAt: candidate.modifiedAt,
                contentHash: hash
            )
            // A file we can't decode is still indexed (present + findable by name) with
            // no OCR text — a blank stand-in drives the same pipeline, OCR yields nothing.
            let image = imageLoader.loadImage(atPath: candidate.path) ?? Self.blankFallbackImage
            switch try await pipeline.indexIfNotDuplicate(image: image, input: input) {
            case let .indexed(record):
                if let hash { seenHashes.insert(hash) }
                result.imported.append(record)
            case .duplicate:
                result.skippedDuplicates.append(candidate.path)
            }
        } catch {
            result.failed.append(candidate.path)
        }
    }

    /// Metadata for a single path (live-import path) without a folder scan.
    private func candidateMetadata(forPath path: String) -> ImportCandidate? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        guard let attrs else { return nil }
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        guard size > 0 else { return nil }
        let modified = (attrs[.modificationDate] as? Date) ?? Date()
        return ImportCandidate(path: path, modifiedAt: modified, sizeBytes: size)
    }

    /// File-derived provenance ONLY (spec §9.6): the filename (sans extension) is the
    /// sole human signal — surfaced as the window-title slot so the existing auto-namer
    /// produces a meaningful slug. We NEVER fabricate the source app, bundle id, or URL
    /// for an imported file; those stay nil (spec: "provenance … never fabricated").
    static func fileDerivedProvenance(forPath path: String) -> CaptureProvenance {
        let base = (path as NSString).lastPathComponent
        let stem = (base as NSString).deletingPathExtension
        let title = stem.trimmingCharacters(in: .whitespacesAndNewlines)
        return CaptureProvenance(windowTitle: title.isEmpty ? nil : title)
    }

    /// A 1×1 opaque stand-in used only when a file won't decode, so the undecodable item
    /// is still inserted and findable by name. OCR over it yields nothing (textIndexed=false).
    static let blankFallbackImage: CGImage = {
        let space = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }()
}
