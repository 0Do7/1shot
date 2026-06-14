import Foundation
import OneShotOCR
import Testing
@testable import OneShotLibrary

/// Task 9.7: Core Spotlight donation + withdrawal. The pipeline logic is exercised with a
/// MOCK `SpotlightIndexing` so it stays headless (CoreSpotlight is macOS-only and behind
/// an injectable protocol; the real `CSSearchableIndex` adapter is thin and not unit-run).
/// Donations update on rename/re-index; withdrawals fire on delete, retention eviction,
/// and integration-disable.
struct SpotlightTests {
    /// Mock index recording the live donation set + every withdrawal, like a real index.
    actor MockSpotlightIndex: SpotlightIndexing {
        private(set) var donated: [String: SpotlightItem] = [:]
        private(set) var withdrawAllCount = 0

        func donate(_ items: [SpotlightItem]) async {
            for item in items {
                donated[item.id] = item
            }
        }

        func withdraw(identifiers: [String]) async {
            for id in identifiers {
                donated[id] = nil
            }
        }

        func withdrawAll() async {
            donated.removeAll()
            withdrawAllCount += 1
        }

        func item(for captureID: Int64) -> SpotlightItem? {
            donated[SpotlightItem.identifier(for: captureID)]
        }

        var count: Int {
            donated.count
        }

        var isEmpty: Bool {
            donated.isEmpty
        }
    }

    private func index(_ store: LibraryStore, _ mock: MockSpotlightIndex) -> SpotlightCoordinator {
        SpotlightCoordinator(store: store, index: mock)
    }

    // MARK: - Identifier round-trip

    @Test func identifierRoundTrips() {
        let id = SpotlightItem.identifier(for: 42)
        #expect(SpotlightItem.captureID(fromIdentifier: id) == 42)
        #expect(SpotlightItem.captureID(fromIdentifier: "com.other.app.item.42") == nil)
    }

    // MARK: - Donation content (spec: by name, OCR text, provenance keywords)

    @Test func donationCarriesNameOCRAndProvenanceKeywords() async throws {
        let store = try LibraryStore()
        let record = try await store.insert(
            CaptureRecord(
                originalPath: "/d/a.png",
                name: "stripe-webhook-error",
                provenance: CaptureProvenance(
                    appName: "Safari",
                    windowTitle: "Webhooks – Stripe",
                    url: "https://dashboard.stripe.com/webhooks"
                ),
                capturedAt: fixedNow
            ),
            ocrText: "stripe webhook delivery failed"
        )
        let id = try #require(record.id)
        try await store.addTag("bug-123", toCapture: id)

        let mock = MockSpotlightIndex()
        await index(store, mock).donate(captureID: id)

        let item = try #require(await mock.item(for: id))
        #expect(item.title == "stripe-webhook-error")
        #expect(item.contentDescription == "stripe webhook delivery failed")
        #expect(item.keywords.contains("Safari"))
        #expect(item.keywords.contains("dashboard.stripe.com")) // URL host
        #expect(item.keywords.contains("bug-123"))
    }

    // MARK: - Update on rename / re-index

    @Test func renameUpdatesDonation() async throws {
        let store = try LibraryStore()
        let record = try await store.insert(
            CaptureRecord(originalPath: "/d/a.png", name: "old-name", capturedAt: fixedNow)
        )
        let id = try #require(record.id)
        let mock = MockSpotlightIndex()
        let coordinator = index(store, mock)

        await coordinator.donate(captureID: id)
        #expect(await mock.item(for: id)?.title == "old-name")

        try await coordinator.rename(captureID: id, to: "new-name")
        #expect(await mock.item(for: id)?.title == "new-name")
        #expect(await mock.count == 1) // updated in place, not duplicated
    }

    @Test func reindexCanRefreshDonation() async throws {
        let store = try LibraryStore()
        let pipeline = IndexingPipeline(store: store, recognizer: FakeTextRecognizer(text: "first text"))
        let rec = try await pipeline.index(
            image: blankImage(),
            input: IndexingPipeline.CaptureInput(originalPath: "/d/a.png", provenance: CaptureProvenance(appName: "X"))
        )
        let id = try #require(rec.id)
        let mock = MockSpotlightIndex()
        let coordinator = index(store, mock)
        await coordinator.donate(captureID: id)
        #expect(await mock.item(for: id)?.contentDescription == "first text")

        // Re-index with new OCR, then re-donate (the app calls donate after reindex).
        let rePipeline = IndexingPipeline(store: store, recognizer: FakeTextRecognizer(text: "updated text"))
        try await rePipeline.reindex(image: blankImage(), id: id)
        await coordinator.donate(captureID: id)
        #expect(await mock.item(for: id)?.contentDescription == "updated text")
    }

    // MARK: - Withdrawal on delete (spec "Deletion removes the donation")

    @Test func deleteWithdrawsDonation() async throws {
        let store = try LibraryStore()
        let record = try await store.insert(
            CaptureRecord(originalPath: "/d/a.png", name: "doomed", capturedAt: fixedNow)
        )
        let id = try #require(record.id)
        let mock = MockSpotlightIndex()
        let coordinator = index(store, mock)
        await coordinator.donate(captureID: id)
        #expect(await mock.item(for: id) != nil)

        try await coordinator.delete(captureID: id)
        #expect(await mock.item(for: id) == nil) // donation withdrawn
        #expect(try await store.record(id: id) == nil) // row deleted
    }

    // MARK: - Withdrawal on retention eviction

    @Test func retentionEvictionWithdrawsDonations() async throws {
        let store = try LibraryStore()
        let a = try #require(try await store.insert(
            CaptureRecord(originalPath: "/d/a.png", name: "a", capturedAt: fixedNow)
        ).id)
        let b = try #require(try await store.insert(
            CaptureRecord(originalPath: "/d/b.png", name: "b", capturedAt: fixedNow)
        ).id)
        let mock = MockSpotlightIndex()
        let coordinator = index(store, mock)
        await coordinator.donate(captureIDs: [a, b])
        #expect(await mock.count == 2)

        // The app deletes the evicted rows after the retention preview is confirmed, then
        // tells the coordinator which ids were evicted so their donations are withdrawn.
        try await store.delete(id: a)
        await coordinator.withdrawEvicted(captureIDs: [a])
        #expect(await mock.item(for: a) == nil)
        #expect(await mock.item(for: b) != nil) // survivor keeps its donation
    }

    // MARK: - Withdraw-all on disable

    @Test func disableIntegrationWithdrawsEverything() async throws {
        let store = try LibraryStore()
        let a = try #require(try await store.insert(
            CaptureRecord(originalPath: "/d/a.png", name: "a", capturedAt: fixedNow)
        ).id)
        let b = try #require(try await store.insert(
            CaptureRecord(originalPath: "/d/b.png", name: "b", capturedAt: fixedNow)
        ).id)
        let mock = MockSpotlightIndex()
        let coordinator = index(store, mock)
        await coordinator.donate(captureIDs: [a, b])
        #expect(await mock.count == 2)

        await coordinator.disableIntegration()
        #expect(await mock.isEmpty)
        #expect(await mock.withdrawAllCount == 1)

        // After disable, further donations are no-ops until re-enabled (swapped to noop).
        await coordinator.donate(captureID: a)
        #expect(await mock.isEmpty)
    }

    /// A record without an id can't be donated (no stable identifier) ⇒ builder returns nil.
    @Test func unsavedRecordYieldsNoDonation() {
        let record = CaptureRecord(originalPath: "/d/a.png", name: "x", capturedAt: fixedNow)
        #expect(SpotlightDonationBuilder.item(for: record, ocrText: nil, tags: []) == nil)
    }
}
