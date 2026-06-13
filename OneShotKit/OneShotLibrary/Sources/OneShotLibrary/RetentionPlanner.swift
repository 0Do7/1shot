import Foundation

/// Plans (but NEVER applies) retention against the live store (spec §9.8). The plan
/// is a *preview*: "before any rule deletes items, the app SHALL make the policy's
/// effect visible." This type only reads + computes; it has no delete path at all.
/// Actual deletion is a separate explicit `LibraryStore.delete` the app calls after
/// showing the preview the user confirms.
///
/// File sizes are supplied by an injected resolver so the planner stays decoupled from
/// the filesystem (and trivially testable). The default resolver reads on-disk file
/// size; a missing/unreadable file resolves to 0 bytes (it occupies no reclaimable
/// space and is still eligible under the age rule).
public struct RetentionPlanner: Sendable {
    /// Maps a capture to its on-disk byte size. `@Sendable` so the planner is `Sendable`.
    public typealias SizeResolver = @Sendable (CaptureRecord) -> Int64

    private let store: LibraryStore
    private let sizeResolver: SizeResolver

    public init(store: LibraryStore, sizeResolver: @escaping SizeResolver = RetentionPlanner.fileSize) {
        self.store = store
        self.sizeResolver = sizeResolver
    }

    /// Default resolver: the original file's byte size, or 0 when it can't be read
    /// (missing/externally deleted) — honest, never a fabricated size.
    public static func fileSize(for record: CaptureRecord) -> Int64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: record.originalPath)
        return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
    }

    /// Build the retention preview for `policy` against current store contents.
    ///
    /// Disabled policy (the default) ⇒ `.empty`: NO item is ever proposed (spec
    /// "Retention off by default"). Otherwise: items older than `maxAgeSeconds` are
    /// proposed first, then — if a `maxTotalBytes` cap is set and the surviving,
    /// non-excluded items still exceed it — the oldest survivors are evicted
    /// oldest-first until under the cap. Kept/tagged exclusions are honored throughout.
    /// This call performs no deletion.
    public func plan(_ policy: RetentionPolicy, now: Date = Date()) async throws -> RetentionPlan {
        guard !policy.isDisabled else { return .empty }

        let records = try await store.allRecords()
        let taggedIDs = policy.excludeTagged ? try await store.taggedCaptureIDs() : []
        let candidates = sizedCandidates(records, policy: policy, taggedIDs: taggedIDs)
        // The size cap measures the WHOLE library, including kept/tagged (excluded)
        // items whose bytes still occupy the cap — even though they're never evicted.
        let candidatesBytes = candidates.reduce(0) { $0 + $1.sizeBytes }
        let excludedBytes = excludedSizeBytes(records, policy: policy, taggedIDs: taggedIDs)
        let totalBefore = candidatesBytes + excludedBytes

        var proposed = ageProposals(candidates, policy: policy, now: now)
        proposed += sizeCapProposals(
            candidates, alreadyProposed: proposed, libraryBytes: totalBefore, policy: policy
        )

        // Preserve oldest-first deletion order across both rules.
        let ordered = proposed.sorted { $0.capturedAt < $1.capturedAt }
        let reclaimed = ordered.reduce(0) { $0 + $1.sizeBytes }
        return RetentionPlan(entries: ordered, totalBytesBefore: totalBefore, reclaimedBytes: reclaimed)
    }

    // MARK: - Candidate model

    /// A capture eligible for retention (passed exclusions) paired with its size.
    private struct Candidate {
        var id: Int64
        var sizeBytes: Int64
        var capturedAt: Date
    }

    /// Records that are NOT excluded by `excludeKept`/`excludeTagged`, with sizes
    /// resolved. Rows without an id (never inserted) cannot be deleted, so are skipped.
    private func sizedCandidates(
        _ records: [CaptureRecord],
        policy: RetentionPolicy,
        taggedIDs: Set<Int64>
    ) -> [Candidate] {
        records.compactMap { record in
            guard let id = record.id else { return nil }
            if policy.excludeKept, record.isKept { return nil }
            if policy.excludeTagged, taggedIDs.contains(id) { return nil }
            return Candidate(id: id, sizeBytes: sizeResolver(record), capturedAt: record.capturedAt)
        }
    }

    /// Bytes held by EXCLUDED items (kept/tagged) — never evicted, but they still
    /// occupy the size cap, so the cap baseline must account for them (spec: the cap
    /// is the whole-Library size, not just the evictable subset).
    private func excludedSizeBytes(
        _ records: [CaptureRecord],
        policy: RetentionPolicy,
        taggedIDs: Set<Int64>
    ) -> Int64 {
        records.reduce(0) { total, record in
            guard let id = record.id else { return total }
            let isExcluded = (policy.excludeKept && record.isKept)
                || (policy.excludeTagged && taggedIDs.contains(id))
            return isExcluded ? total + sizeResolver(record) : total
        }
    }

    // MARK: - Rule evaluation

    /// Candidates older than the policy's max age (spec: age-based rules).
    private func ageProposals(
        _ candidates: [Candidate],
        policy: RetentionPolicy,
        now: Date
    ) -> [RetentionPreviewEntry] {
        guard let maxAge = policy.maxAgeSeconds else { return [] }
        let cutoff = now.addingTimeInterval(-maxAge)
        return candidates
            .filter { $0.capturedAt < cutoff }
            .map { RetentionPreviewEntry(
                id: $0.id,
                sizeBytes: $0.sizeBytes,
                capturedAt: $0.capturedAt,
                reason: .exceededAge
            ) }
    }

    /// Oldest-first eviction to bring the WHOLE Library under the size cap
    /// (spec: "Size cap evicts oldest first"). `libraryBytes` is the full pre-removal
    /// size including excluded (kept/tagged) items, so the cap is measured against the
    /// real library — not just the evictable subset. Items already proposed by the age
    /// rule are excluded here (they'd be removed anyway) and their reclaimed bytes count
    /// toward getting under the cap. Only candidates are ever evicted; excluded bytes
    /// stay in `running` and can hold the library above the cap if they alone exceed it.
    private func sizeCapProposals(
        _ candidates: [Candidate],
        alreadyProposed: [RetentionPreviewEntry],
        libraryBytes: Int64,
        policy: RetentionPolicy
    ) -> [RetentionPreviewEntry] {
        guard let cap = policy.maxTotalBytes else { return [] }
        guard libraryBytes > cap else { return [] }
        let proposedIDs = Set(alreadyProposed.map(\.id))

        var running = libraryBytes
        var extra: [RetentionPreviewEntry] = []
        // Oldest first: evict candidates until the library is at or under the cap.
        for candidate in candidates.sorted(by: { $0.capturedAt < $1.capturedAt }) {
            guard running > cap else { break }
            running -= candidate.sizeBytes
            guard !proposedIDs.contains(candidate.id) else { continue }
            extra.append(RetentionPreviewEntry(
                id: candidate.id, sizeBytes: candidate.sizeBytes,
                capturedAt: candidate.capturedAt, reason: .exceededSizeCap
            ))
        }
        return extra
    }
}
