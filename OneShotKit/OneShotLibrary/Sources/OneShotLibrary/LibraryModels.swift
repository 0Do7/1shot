import Foundation

/// The kind of media a Library item references. MVP only ever produces `.image`;
/// `.video` is a forward-compatibility hook (spec: "media-type field with nullable
/// duration") that MUST remain unproduced by MVP code paths.
public enum MediaType: String, Codable, Sendable, Hashable, CaseIterable {
    case image
    case video
}

/// Provenance recorded for a capture (spec: "Provenance captured with every
/// screenshot"). Every field is optional: unavailable signals are stored as
/// `nil`, never fabricated, and a provenance gap NEVER fails the capture.
public struct CaptureProvenance: Sendable, Hashable {
    /// Source application bundle identifier, e.g. `com.apple.Safari`.
    public var bundleID: String?
    /// Source application display name, e.g. `Safari`.
    public var appName: String?
    /// Frontmost window title at capture time.
    public var windowTitle: String?
    /// Active tab URL when the source is a supported browser; otherwise nil.
    public var url: String?
    /// The display the capture was taken from (CoreGraphics display id).
    public var displayID: UInt32?

    public init(
        bundleID: String? = nil,
        appName: String? = nil,
        windowTitle: String? = nil,
        url: String? = nil,
        displayID: UInt32? = nil
    ) {
        self.bundleID = bundleID
        self.appName = appName
        self.windowTitle = windowTitle
        self.url = url
        self.displayID = displayID
    }
}

/// One row of the `captures` table as a Sendable value type. The DB is the
/// source of truth for `id`; callers build a record without one for insert and
/// receive a hydrated record (with `id`) back.
///
/// Reference-not-vault (spec): `originalPath` is the absolute path of the
/// user-visible file on disk; the Library NEVER copies or modifies it. `missing`
/// flags a file the user moved/deleted externally so the UI degrades honestly
/// instead of showing a stale thumbnail as live.
public struct CaptureRecord: Sendable, Hashable, Identifiable {
    /// Database row id; nil until inserted.
    public var id: Int64?
    /// Absolute path to the user-visible original file (never copied/owned).
    public var originalPath: String
    /// True once the referenced file is detected as gone from disk.
    public var missing: Bool
    /// Auto-generated or user-set human-meaningful name (no extension).
    public var name: String
    /// True once the user has renamed manually — re-indexing must never clobber it.
    public var nameIsManual: Bool
    public var mediaType: MediaType
    /// Video-hook (spec): always nil for image captures in MVP.
    public var durationSeconds: Double?
    public var provenance: CaptureProvenance
    public var capturedAt: Date
    /// True once OCR text has been indexed for this item. An item is present and
    /// findable by name/provenance before this flips true.
    public var textIndexed: Bool
    /// Heuristic "contains code" flag derived at index time (no AI).
    public var containsCode: Bool
    /// User "keep" flag — excludes the item from automatic retention deletion.
    public var isKept: Bool
    /// Content fingerprint of the referenced original (spec §9.6 dedup: "No
    /// duplicate entries"). Filled for auto-imported files so a re-scan, touch, or
    /// move of an already-indexed file never creates a second entry; nil for native
    /// captures (deduped by their unique originalPath instead). Identity is by file
    /// CONTENT, not path, so the same file under a new path is still recognized.
    public var contentHash: String?

    public init(
        id: Int64? = nil,
        originalPath: String,
        missing: Bool = false,
        name: String,
        nameIsManual: Bool = false,
        mediaType: MediaType = .image,
        durationSeconds: Double? = nil,
        provenance: CaptureProvenance = CaptureProvenance(),
        capturedAt: Date,
        textIndexed: Bool = false,
        containsCode: Bool = false,
        isKept: Bool = false,
        contentHash: String? = nil
    ) {
        self.id = id
        self.originalPath = originalPath
        self.missing = missing
        self.name = name
        self.nameIsManual = nameIsManual
        self.mediaType = mediaType
        self.durationSeconds = durationSeconds
        self.provenance = provenance
        self.capturedAt = capturedAt
        self.textIndexed = textIndexed
        self.containsCode = containsCode
        self.isKept = isKept
        self.contentHash = contentHash
    }
}

/// A manual tag (spec: "manual tags"). Tags are many-to-many with captures via a
/// junction table; deleting a tag removes the associations but never the items.
public struct Tag: Sendable, Hashable, Identifiable {
    public var id: Int64?
    public var name: String

    public init(id: Int64? = nil, name: String) {
        self.id = id
        self.name = name
    }
}

/// Typed Library failures (product law: "honest failure" — explicit typed
/// results, never silent garbage). Provenance/OCR gaps are NOT errors; they
/// degrade gracefully and are represented as nil/false on the record.
public enum LibraryError: Error, Equatable, Sendable {
    /// A record id was expected but not present (e.g. operating on an un-inserted
    /// record, or a row that no longer exists).
    case recordNotFound(Int64)
    /// The underlying database layer failed; carries a message for logs.
    case databaseFailed(String)
}
