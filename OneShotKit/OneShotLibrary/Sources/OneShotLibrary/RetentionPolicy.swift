import Foundation

/// User-configurable retention rules (spec §9.8). A pure value type, **disabled by
/// default**: a freshly-constructed `RetentionPolicy()` deletes nothing — every rule
/// is individually optional and nil means "rule off".
///
/// The policy only *describes* what would be removed. It never deletes; the planner
/// turns it into a preview and the app performs deletion explicitly afterwards.
public struct RetentionPolicy: Codable, Sendable, Hashable {
    /// Maximum total bytes the Library may occupy. Over this, the oldest non-excluded
    /// items are proposed for removal until under the cap (spec: "oldest-first").
    /// Nil = no size cap.
    public var maxTotalBytes: Int64?
    /// Items older than this many seconds are proposed for removal. Nil = no age rule.
    public var maxAgeSeconds: TimeInterval?
    /// When true, items the user marked "kept" (`isKept`) are never proposed.
    public var excludeKept: Bool
    /// When true, items carrying ANY manual tag are never proposed.
    public var excludeTagged: Bool

    public init(
        maxTotalBytes: Int64? = nil,
        maxAgeSeconds: TimeInterval? = nil,
        excludeKept: Bool = true,
        excludeTagged: Bool = false
    ) {
        self.maxTotalBytes = maxTotalBytes
        self.maxAgeSeconds = maxAgeSeconds
        self.excludeKept = excludeKept
        self.excludeTagged = excludeTagged
    }

    /// The all-off default (spec §9.8 "Retention off by default"). No size cap, no age
    /// rule — a planner given this returns an empty preview.
    public static let disabled = RetentionPolicy(maxTotalBytes: nil, maxAgeSeconds: nil)

    /// True when no rule is active, so the planner can short-circuit to "delete nothing".
    var isDisabled: Bool {
        maxTotalBytes == nil && maxAgeSeconds == nil
    }
}

/// Why a capture was proposed for removal (spec §9.8: deletions are "logged/visible …
/// never mysterious"). Both reasons can apply; the planner records the triggering one.
public enum RetentionReason: String, Codable, Sendable, Hashable {
    /// Older than the policy's max age.
    case exceededAge
    /// Evicted oldest-first to bring the Library under the size cap.
    case exceededSizeCap
}

/// One line of a retention preview: the capture id, its size, and why it is proposed.
/// The preview carries enough to render an honest "what will be removed and when" UI.
public struct RetentionPreviewEntry: Sendable, Hashable, Identifiable {
    public var id: Int64
    public var sizeBytes: Int64
    public var capturedAt: Date
    public var reason: RetentionReason

    public init(id: Int64, sizeBytes: Int64, capturedAt: Date, reason: RetentionReason) {
        self.id = id
        self.sizeBytes = sizeBytes
        self.capturedAt = capturedAt
        self.reason = reason
    }
}

/// The result of planning retention: the ordered preview plus the totals the UI needs
/// to explain the effect. NEVER a side effect — building this deletes nothing.
public struct RetentionPlan: Sendable, Hashable {
    /// Captures proposed for removal, oldest-first (the order they would be deleted).
    public var entries: [RetentionPreviewEntry]
    /// Total bytes currently held by the WHOLE Library, pre-removal — including
    /// excluded (kept/tagged) items, so the preview's "library size" is honest and
    /// matches what the size cap is measured against.
    public var totalBytesBefore: Int64
    /// Bytes that would be reclaimed by applying the whole preview.
    public var reclaimedBytes: Int64

    public init(entries: [RetentionPreviewEntry], totalBytesBefore: Int64, reclaimedBytes: Int64) {
        self.entries = entries
        self.totalBytesBefore = totalBytesBefore
        self.reclaimedBytes = reclaimedBytes
    }

    /// The bare id list, in deletion order — what the app passes to an explicit
    /// `LibraryStore.delete` loop after the user confirms the preview.
    public var ids: [Int64] {
        entries.map(\.id)
    }

    /// An empty, no-op plan (disabled policy / nothing to remove).
    public static let empty = RetentionPlan(entries: [], totalBytesBefore: 0, reclaimedBytes: 0)
}
