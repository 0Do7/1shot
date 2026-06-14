import Foundation
import Testing
@testable import OneShotLibrary

/// Task 9.8: retention controls — OFF BY DEFAULT. A RetentionPolicy value type and a
/// planner that PREVIEWS the ids that would be deleted. The planner never deletes;
/// disabled policy ⇒ empty preview; size cap evicts oldest-first; kept/tagged items
/// are excludable.
struct RetentionTests {
    /// Inject deterministic per-capture sizes by path so tests don't touch the disk.
    private func sizeResolver(_ sizes: [String: Int64]) -> RetentionPlanner.SizeResolver {
        { record in sizes[record.originalPath] ?? 0 }
    }

    /// Seed `count` captures spaced one day apart, oldest first, each 1 GB by default.
    @discardableResult
    private func seedAged(
        _ store: LibraryStore,
        count: Int,
        now: Date = fixedNow,
        kept: Set<Int> = [],
        eachBytes _: Int64 = 1_000_000_000
    ) async throws -> [Int64] {
        var ids: [Int64] = []
        for i in 0 ..< count {
            // index 0 = oldest.
            let age = TimeInterval((count - i) * 86400)
            let rec = try await store.insert(CaptureRecord(
                originalPath: "/r\(i).png", name: "r\(i)",
                provenance: CaptureProvenance(appName: "Xcode"),
                capturedAt: now.addingTimeInterval(-age),
                isKept: kept.contains(i)
            ))
            try ids.append(#require(rec.id))
        }
        return ids
    }

    private func sizes(forCount count: Int, each: Int64 = 1_000_000_000) -> [String: Int64] {
        var map: [String: Int64] = [:]
        for i in 0 ..< count {
            map["/r\(i).png"] = each
        }
        return map
    }

    // MARK: - Off by default

    /// Spec §9.8 "Retention off by default" — the default policy proposes NOTHING.
    @Test func retentionOffByDefault() async throws {
        let store = try LibraryStore()
        try await seedAged(store, count: 5)
        let planner = RetentionPlanner(store: store, sizeResolver: sizeResolver(sizes(forCount: 5)))

        let plan = try await planner.plan(RetentionPolicy())
        #expect(plan.entries.isEmpty)
        #expect(plan.ids.isEmpty)
        #expect(plan == .empty)

        // .disabled convenience is equivalent.
        #expect(try await planner.plan(.disabled).entries.isEmpty)
    }

    /// The planner is a pure preview: building a non-empty plan must NOT delete any
    /// row from the store (preview-before-delete is the spec requirement).
    @Test func plannerNeverDeletes() async throws {
        let store = try LibraryStore()
        let ids = try await seedAged(store, count: 5)
        let planner = RetentionPlanner(store: store, sizeResolver: sizeResolver(sizes(forCount: 5)))

        // A 2 GB cap over 5 GB ⇒ a non-empty preview.
        let plan = try await planner.plan(RetentionPolicy(maxTotalBytes: 2_000_000_000))
        #expect(!plan.entries.isEmpty)

        // Every seeded row is STILL present — the planner did not delete.
        for id in ids {
            #expect(try await store.record(id: id) != nil)
        }
        #expect(try await store.allRecords().count == 5)
    }

    // MARK: - Size cap

    /// Spec §9.8 "Size cap evicts oldest first" — with a 2 GB cap over 5 × 1 GB, the
    /// three oldest are proposed (in oldest-first order) leaving the library at 2 GB.
    @Test func sizeCapEvictsOldestFirst() async throws {
        let store = try LibraryStore()
        let ids = try await seedAged(store, count: 5) // r0 oldest … r4 newest
        let planner = RetentionPlanner(store: store, sizeResolver: sizeResolver(sizes(forCount: 5)))

        let plan = try await planner.plan(RetentionPolicy(maxTotalBytes: 2_000_000_000))
        // Need to drop 3 GB worth ⇒ the three oldest (r0, r1, r2).
        #expect(plan.ids == [ids[0], ids[1], ids[2]])
        #expect(plan.entries.allSatisfy { $0.reason == .exceededSizeCap })
        #expect(plan.reclaimedBytes == 3_000_000_000)
        #expect(plan.totalBytesBefore == 5_000_000_000)
    }

    /// Under the cap ⇒ nothing proposed (honest no-op).
    @Test func sizeCapUnderLimitProposesNothing() async throws {
        let store = try LibraryStore()
        try await seedAged(store, count: 3)
        let planner = RetentionPlanner(store: store, sizeResolver: sizeResolver(sizes(forCount: 3)))
        let plan = try await planner.plan(RetentionPolicy(maxTotalBytes: 10_000_000_000))
        #expect(plan.entries.isEmpty)
    }

    /// Spec §9.8: the size cap measures the WHOLE Library. A kept (excluded) item's
    /// bytes still occupy the cap, so eviction of non-excluded items must continue
    /// until the *whole* library is under the cap — not just the evictable subset.
    /// Kept K=3 GB (excluded) + non-excluded A=1 GB(old) + B=1 GB(new); cap 4 GB.
    /// Real library = 5 GB > 4 GB ⇒ evict the oldest non-excluded item (A) to reach 4 GB.
    @Test func sizeCapAccountsForKeptBytes() async throws {
        let store = try LibraryStore()
        // r0 (oldest, kept, 3 GB), r1 (A, 1 GB), r2 (newest, B, 1 GB).
        let ids = try await seedAged(store, count: 3, kept: [0])
        let resolver = sizeResolver(["/r0.png": 3_000_000_000, "/r1.png": 1_000_000_000, "/r2.png": 1_000_000_000])
        let planner = RetentionPlanner(store: store, sizeResolver: resolver)

        let plan = try await planner.plan(RetentionPolicy(maxTotalBytes: 4_000_000_000, excludeKept: true))
        // Only A (r1, oldest non-excluded) is evicted; that alone brings the library to 4 GB.
        #expect(plan.ids == [ids[1]])
        #expect(plan.entries.allSatisfy { $0.reason == .exceededSizeCap })
        #expect(plan.reclaimedBytes == 1_000_000_000)
        // totalBytesBefore reflects the WHOLE library (incl. the kept 3 GB), not just candidates.
        #expect(plan.totalBytesBefore == 5_000_000_000)
    }

    /// If excluded (kept) bytes alone exceed the cap, all non-excluded candidates are
    /// evicted but the library stays over the cap — the planner never deletes a kept
    /// item. Kept K=5 GB; non-excluded A=1 GB; cap 4 GB ⇒ evict A, library still 5 GB.
    @Test func sizeCapNeverEvictsKeptEvenIfStillOverCap() async throws {
        let store = try LibraryStore()
        let ids = try await seedAged(store, count: 2, kept: [0]) // r0 kept (5 GB), r1 candidate (1 GB)
        let resolver = sizeResolver(["/r0.png": 5_000_000_000, "/r1.png": 1_000_000_000])
        let planner = RetentionPlanner(store: store, sizeResolver: resolver)

        let plan = try await planner.plan(RetentionPolicy(maxTotalBytes: 4_000_000_000, excludeKept: true))
        #expect(plan.ids == [ids[1]]) // the one evictable candidate
        #expect(plan.totalBytesBefore == 6_000_000_000)
    }

    // MARK: - Age rule + exclusions

    /// Spec §9.8 "Kept items survive age rules" — an age rule that would catch a kept
    /// item does not propose it.
    @Test func keptItemsSurviveAgeRules() async throws {
        let store = try LibraryStore()
        // 4 captures aged 4,3,2,1 days; r0 (4 days old) is marked kept.
        let ids = try await seedAged(store, count: 4, kept: [0])
        let planner = RetentionPlanner(store: store, sizeResolver: sizeResolver(sizes(forCount: 4)))

        // maxAge 2.5 days ⇒ r0 (4d) and r1 (3d) qualify by age, but r0 is kept.
        let plan = try await planner.plan(
            RetentionPolicy(maxAgeSeconds: 2.5 * 86400, excludeKept: true),
            now: fixedNow
        )
        #expect(plan.ids == [ids[1]]) // only the non-kept aged item
        #expect(plan.entries.first?.reason == .exceededAge)
    }

    /// Spec §9.8 "Manually tagged … items SHALL be excludable" — excludeTagged drops
    /// tagged items from the age proposal.
    @Test func taggedItemsExcludableFromAgeRule() async throws {
        let store = try LibraryStore()
        let ids = try await seedAged(store, count: 3) // r0 oldest
        try await store.addTag("keep-me", toCapture: ids[0])
        let planner = RetentionPlanner(store: store, sizeResolver: sizeResolver(sizes(forCount: 3)))

        // Without excludeTagged, both r0 and r1 (older than 1.5d) qualify.
        let withTagged = try await planner.plan(
            RetentionPolicy(maxAgeSeconds: 1.5 * 86400, excludeTagged: false), now: fixedNow
        )
        #expect(Set(withTagged.ids) == Set([ids[0], ids[1]]))

        // With excludeTagged, the tagged r0 is spared.
        let excluded = try await planner.plan(
            RetentionPolicy(maxAgeSeconds: 1.5 * 86400, excludeTagged: true), now: fixedNow
        )
        #expect(excluded.ids == [ids[1]])
    }

    /// Age + size cap combine: age-removed bytes count toward the cap so the size rule
    /// only proposes what's still needed, and reasons are recorded per entry.
    @Test func ageAndSizeCapCombine() async throws {
        let store = try LibraryStore()
        let ids = try await seedAged(store, count: 5) // r0..r4, 1 GB each
        let planner = RetentionPlanner(store: store, sizeResolver: sizeResolver(sizes(forCount: 5)))

        // Age rule catches r0 (5d) and r1 (4d). Cap 2 GB over 5 GB needs 3 GB freed:
        // the two age items free 2 GB, the size rule adds the next-oldest (r2).
        let plan = try await planner.plan(
            RetentionPolicy(maxTotalBytes: 2_000_000_000, maxAgeSeconds: 3.5 * 86400),
            now: fixedNow
        )
        #expect(plan.ids == [ids[0], ids[1], ids[2]])
        let byID = Dictionary(uniqueKeysWithValues: plan.entries.map { ($0.id, $0.reason) })
        #expect(byID[ids[0]] == .exceededAge)
        #expect(byID[ids[1]] == .exceededAge)
        #expect(byID[ids[2]] == .exceededSizeCap)
    }
}
