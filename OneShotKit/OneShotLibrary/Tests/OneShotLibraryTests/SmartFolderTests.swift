import Foundation
import Testing
@testable import OneShotLibrary

/// Task 9.5: smart folders (saved Codable query definitions compiling to
/// SearchFilters, with built-ins) + manual tag add/remove/filter. Seeded in-memory
/// store; predicates must select the right rows and membership re-derives live.
struct SmartFolderTests {
    /// Seed a deterministic store: two apps, one code capture, varied capture dates.
    private func seedStore(now: Date = fixedNow) async throws -> LibraryStore {
        let store = try LibraryStore()
        // Xcode capture containing code, captured "now".
        _ = try await store.insert(
            CaptureRecord(
                originalPath: "/x1.png", name: "xcode-build",
                provenance: CaptureProvenance(appName: "Xcode"),
                capturedAt: now, textIndexed: true, containsCode: true
            ),
            ocrText: "func handleWebhook() { return }"
        )
        // Figma capture, no code, captured 10 days ago.
        _ = try await store.insert(
            CaptureRecord(
                originalPath: "/f1.png", name: "figma-frame",
                provenance: CaptureProvenance(appName: "Figma"),
                capturedAt: now.addingTimeInterval(-10 * 86400), textIndexed: true, containsCode: false
            ),
            ocrText: "Design system spacing tokens"
        )
        // Second Figma capture, no code, captured today.
        _ = try await store.insert(
            CaptureRecord(
                originalPath: "/f2.png", name: "figma-export",
                provenance: CaptureProvenance(appName: "Figma"),
                capturedAt: now, textIndexed: true, containsCode: false
            ),
            ocrText: "Export PNG at 2x"
        )
        return store
    }

    // MARK: - 9.5 Smart folders

    /// Spec §9.5 "Per-app smart folder" — Xcode and Figma folders each contain exactly
    /// that app's captures.
    @Test func perAppSmartFolder() async throws {
        let store = try await seedStore()
        let evaluator = SmartFolderEvaluator(store: store)

        let xcode = try await evaluator.captures(in: .perApp("Xcode"))
        #expect(xcode.count == 1)
        #expect(xcode.allSatisfy { $0.provenance.appName == "Xcode" })

        let figma = try await evaluator.captures(in: .perApp("Figma"))
        #expect(figma.count == 2)
        #expect(figma.allSatisfy { $0.provenance.appName == "Figma" })
    }

    /// Spec §9.5 "Contains-code folder" — a capture flagged containsCode at index time
    /// appears in the contains-code smart folder; prose captures do not.
    @Test func containsCodeFolder() async throws {
        let store = try await seedStore()
        let evaluator = SmartFolderEvaluator(store: store)
        let coded = try await evaluator.captures(in: .containsCode())
        let allCode = coded.allSatisfy(\.containsCode)
        #expect(coded.count == 1)
        #expect(coded.first?.name == "xcode-build")
        #expect(allCode)
    }

    /// Spec §9.5 "date-based folders (e.g. Today, This Week)" — the Today bucket selects
    /// only captures from today; the 10-days-ago Figma capture is excluded.
    @Test func dateBucketTodaySelectsOnlyToday() async throws {
        let store = try await seedStore()
        let evaluator = SmartFolderEvaluator(store: store)
        let today = try await evaluator.captures(in: .dates(.today), now: fixedNow)
        #expect(today.count == 2)
        #expect(today.allSatisfy { $0.capturedAt == fixedNow })
    }

    /// Spec §9.5 "membership SHALL update automatically as items are added" — a smart
    /// folder is a live query, so a newly inserted matching item appears on re-eval.
    @Test func smartFolderMembershipUpdatesLive() async throws {
        let store = try await seedStore()
        let evaluator = SmartFolderEvaluator(store: store)
        #expect(try await evaluator.count(in: .perApp("Safari")) == 0)

        _ = try await store.insert(CaptureRecord(
            originalPath: "/s1.png", name: "safari-tab",
            provenance: CaptureProvenance(appName: "Safari"), capturedAt: fixedNow
        ))
        #expect(try await evaluator.count(in: .perApp("Safari")) == 1)
    }

    /// A smart folder is a portable saved query: encode -> decode round-trips its
    /// predicates so persistence keeps the rule, not a frozen membership list.
    @Test func smartFolderCodableRoundTrips() throws {
        let folder = SmartFolder(
            id: "user.1", name: "Xcode code today",
            predicates: [.sourceApp("Xcode"), .containsCode(true), .dateBucket(.today), .tag("bug")]
        )
        let data = try JSONEncoder().encode(folder)
        let decoded = try JSONDecoder().decode(SmartFolder.self, from: data)
        #expect(decoded == folder)
    }

    /// Built-ins ship with zero setup: one folder per app present, contains-code, and
    /// the date buckets — derived live from store contents.
    @Test func builtInFoldersCoverAppsCodeAndDates() async throws {
        let store = try await seedStore()
        let evaluator = SmartFolderEvaluator(store: store)
        let folders = try await evaluator.builtInFolders()
        let names = Set(folders.map(\.name))
        let allBuiltIn = folders.allSatisfy(\.isBuiltIn)
        #expect(names.isSuperset(of: ["Xcode", "Figma", "Contains Code", "Today", "This Week"]))
        #expect(allBuiltIn)
    }

    /// Multiple predicates are ANDed: Figma + contains-code selects nothing (the only
    /// code capture is from Xcode), proving the compiled filters intersect.
    @Test func andedPredicatesIntersect() async throws {
        let store = try await seedStore()
        let evaluator = SmartFolderEvaluator(store: store)
        let folder = SmartFolder(
            id: "user.2", name: "Figma code",
            predicates: [.sourceApp("Figma"), .containsCode(true)]
        )
        #expect(try await evaluator.captures(in: folder).isEmpty)
    }

    // MARK: - 9.5 Manual tags (add / remove / filter)

    /// Spec §9.5 "Manual tagging and filter" — tag three items "bug-123" and a
    /// tag-predicate smart folder returns exactly those three.
    @Test func manualTaggingAndFilter() async throws {
        let store = try await seedStore()
        let ids = try await store.allRecords().compactMap(\.id)
        for id in ids {
            try await store.addTag("bug-123", toCapture: id)
        }

        let evaluator = SmartFolderEvaluator(store: store)
        let folder = SmartFolder(id: "user.3", name: "bug-123", predicates: [.tag("bug-123")])
        let tagged = try await evaluator.captures(in: folder)
        #expect(tagged.count == 3)
    }

    /// Spec §9.5 "expose add/remove + filter" — removeTag detaches the tag from ONE
    /// capture only; the others keep it and no capture is deleted.
    @Test func removeTagDetachesOneCaptureOnly() async throws {
        let store = try await seedStore()
        let ids = try await store.allRecords().compactMap(\.id)
        for id in ids {
            try await store.addTag("shared", toCapture: id)
        }

        let first = try #require(ids.first)
        try await store.removeTag("shared", fromCapture: first)

        #expect(try await store.tags(forCapture: first).isEmpty)
        #expect(try await store.record(id: first) != nil) // capture survives
        for other in ids.dropFirst() {
            #expect(try await store.tags(forCapture: other) == ["shared"])
        }

        let evaluator = SmartFolderEvaluator(store: store)
        let folder = SmartFolder(id: "user.4", name: "shared", predicates: [.tag("shared")])
        #expect(try await evaluator.captures(in: folder).count == ids.count - 1)
    }

    /// Spec §9.5 "Tag deletion is non-destructive" — deleting a tag removes it from all
    /// items without deleting any item, and the tag folder then matches nothing.
    @Test func tagDeletionIsNonDestructive() async throws {
        let store = try await seedStore()
        let ids = try await store.allRecords().compactMap(\.id)
        for id in ids {
            try await store.addTag("bug-123", toCapture: id)
        }

        try await store.deleteTag("bug-123")

        for id in ids {
            #expect(try await store.record(id: id) != nil) // items remain
            #expect(try await store.tags(forCapture: id).isEmpty) // tag gone
        }
        let evaluator = SmartFolderEvaluator(store: store)
        let folder = SmartFolder(id: "user.5", name: "bug-123", predicates: [.tag("bug-123")])
        #expect(try await evaluator.captures(in: folder).isEmpty)
    }
}
