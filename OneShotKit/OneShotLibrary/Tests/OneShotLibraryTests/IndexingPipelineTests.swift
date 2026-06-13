import Foundation
import OneShotOCR
import Testing
@testable import OneShotLibrary

/// Task 9.2: index-on-capture pipeline — async OCR (per-item failure isolation),
/// heuristic auto-naming with store-backed collision handling, provenance ingest,
/// contains-code heuristic.
struct IndexingPipelineTests {
    private func input(
        path: String = "/shots/a.png",
        app: String? = nil,
        bundleID: String? = nil,
        title: String? = nil,
        url: String? = nil,
        at date: Date = fixedNow
    ) -> IndexingPipeline.CaptureInput {
        IndexingPipeline.CaptureInput(
            originalPath: path,
            provenance: CaptureProvenance(bundleID: bundleID, appName: app, windowTitle: title, url: url),
            capturedAt: date,
            timeZone: TimeZone(identifier: "UTC")!
        )
    }

    /// Spec §9.2 "Capture text becomes searchable" — OCR text is stored and the item
    /// becomes text-searchable after indexing.
    @Test func captureTextBecomesSearchable() async throws {
        let store = try LibraryStore()
        let recognizer = FakeTextRecognizer(text: "Error: webhook delivery failed with status 500")
        let pipeline = IndexingPipeline(store: store, recognizer: recognizer)

        let rec = try await pipeline.index(
            image: blankImage(),
            input: input(app: "Safari", title: "Webhooks – Stripe Dashboard")
        )
        #expect(rec.textIndexed == true)

        let hits = try await LibrarySearch(store: store).search("stripe webhook")
        #expect(hits.contains { $0.record.id == rec.id })
    }

    /// Spec §9.2 "Indexing never blocks capture" — an item with PENDING/failed OCR is
    /// still present and findable by name/provenance immediately.
    @Test func indexingNeverBlocksCapture() async throws {
        let store = try LibraryStore()
        // Recognizer that fails: the capture must still be inserted and findable.
        let recognizer = FakeTextRecognizer(error: .recognitionFailed("simulated"))
        let pipeline = IndexingPipeline(store: store, recognizer: recognizer)

        let rec = try await pipeline.index(image: blankImage(), input: input(app: "Xcode", title: "Main.swift"))
        #expect(rec.id != nil)
        #expect(rec.textIndexed == false)
        // Findable by name/provenance even with no OCR text yet.
        let hits = try await LibrarySearch(store: store).search("xcode")
        #expect(hits.contains { $0.record.id == rec.id })
    }

    /// Spec §9.2 "One bad item does not poison the queue" — a failed OCR sets
    /// text_indexed=false, never throws, and the next item indexes fine.
    @Test func oneBadItemDoesNotPoisonTheQueue() async throws {
        let store = try LibraryStore()
        let badPipeline = IndexingPipeline(
            store: store,
            recognizer: FakeTextRecognizer(error: .recognitionFailed("corrupt"))
        )
        let goodPipeline = IndexingPipeline(store: store, recognizer: FakeTextRecognizer(text: "stripe webhook error"))

        let bad = try await badPipeline.index(image: blankImage(), input: input(path: "/bad.png", app: "Preview"))
        let good = try await goodPipeline.index(image: blankImage(), input: input(path: "/good.png", app: "Safari"))

        #expect(bad.textIndexed == false)
        #expect(good.textIndexed == true)
        let hits = try await LibrarySearch(store: store).search("stripe")
        #expect(hits.contains { $0.record.id == good.id })
        #expect(!hits.contains { $0.record.id == bad.id })
    }

    /// Spec §9.2 "Meaningful name from app, title, and OCR" — the slug is built from
    /// signals, not a generic Screenshot name.
    @Test func meaningfulNameFromAppTitleAndOCR() async throws {
        let store = try LibraryStore()
        let recognizer = FakeTextRecognizer(text: "Error: webhook delivery failed with status 500")
        let pipeline = IndexingPipeline(store: store, recognizer: recognizer)

        let rec = try await pipeline.index(
            image: blankImage(),
            input: input(app: "Safari", title: "Webhooks – Stripe Dashboard")
        )
        #expect(rec.name.contains("stripe"))
        #expect(rec.name.contains("webhook"))
        #expect(!rec.name.hasPrefix("capture-"))
    }

    /// Spec §9.2 "Collision handling" — the second identical auto-name gets a
    /// deterministic numeric suffix and both remain retrievable.
    @Test func collisionHandling() async throws {
        let store = try LibraryStore()
        let recognizer = FakeTextRecognizer(text: "Webhooks Stripe Dashboard error")
        let pipeline = IndexingPipeline(store: store, recognizer: recognizer)

        let a = try await pipeline.index(
            image: blankImage(),
            input: input(path: "/a.png", app: "Safari", title: "Webhooks – Stripe Dashboard")
        )
        let b = try await pipeline.index(
            image: blankImage(),
            input: input(path: "/b.png", app: "Safari", title: "Webhooks – Stripe Dashboard")
        )

        #expect(a.name != b.name)
        #expect(b.name == a.name + "-2")
        #expect(try await store.record(id: #require(a.id)) != nil)
        #expect(try await store.record(id: #require(b.id)) != nil)
    }

    /// Spec §9.2 "Manual rename is sticky" — a user's name survives re-indexing.
    @Test func manualRenameIsSticky() async throws {
        let store = try LibraryStore()
        let pipeline = IndexingPipeline(store: store, recognizer: FakeTextRecognizer(text: "alpha beta gamma"))
        let rec = try await pipeline.index(image: blankImage(), input: input(app: "Xcode"))
        let id = try #require(rec.id)

        try await store.rename(id: id, to: "my-special-name")

        // Re-index with different OCR — the manual name must NOT be overwritten.
        let rePipeline = IndexingPipeline(store: store, recognizer: FakeTextRecognizer(text: "delta epsilon zeta"))
        try await rePipeline.reindex(image: blankImage(), id: id)

        let after = try await store.record(id: id)
        #expect(after?.name == "my-special-name")
    }

    /// Spec §9.2 "Signal-free capture" — no app/title/OCR yields a timestamp fallback,
    /// never empty.
    @Test func signalFreeCapture() async throws {
        let store = try LibraryStore()
        let pipeline = IndexingPipeline(store: store, recognizer: FakeTextRecognizer()) // empty OCR
        let rec = try await pipeline.index(image: blankImage(), input: input())
        #expect(rec.name.hasPrefix("capture-"))
        #expect(!rec.name.isEmpty)
        #expect(rec.textIndexed == false)
    }

    /// Spec §9.2 "Browser capture records the URL" — provenance (app, title, URL) is
    /// ingested as recorded.
    @Test func browserCaptureRecordsTheURL() async throws {
        let store = try LibraryStore()
        let pipeline = IndexingPipeline(store: store, recognizer: FakeTextRecognizer())
        let rec = try await pipeline.index(image: blankImage(), input: input(
            app: "Safari",
            bundleID: "com.apple.Safari",
            title: "Webhooks – Stripe Dashboard",
            url: "https://dashboard.stripe.com/webhooks"
        ))
        let fetched = try await store.record(id: #require(rec.id))
        #expect(fetched?.provenance.appName == "Safari")
        #expect(fetched?.provenance.windowTitle == "Webhooks – Stripe Dashboard")
        #expect(fetched?.provenance.url == "https://dashboard.stripe.com/webhooks")
    }

    /// Spec §9.2 "Provenance is null, not guessed" — absent fields stay nil and the
    /// capture still completes.
    @Test func provenanceIsNullNotGuessed() async throws {
        let store = try LibraryStore()
        let pipeline = IndexingPipeline(store: store, recognizer: FakeTextRecognizer(text: "some visible text here"))
        let rec = try await pipeline.index(image: blankImage(), input: input(app: "Safari", title: nil, url: nil))
        let fetched = try await store.record(id: #require(rec.id))
        #expect(fetched?.provenance.windowTitle == nil)
        #expect(fetched?.provenance.url == nil)
        #expect(fetched?.id != nil) // capture completed normally
    }

    /// Spec §9.x "Contains-code folder" — a terminal/source capture flips containsCode.
    @Test func containsCodeFolder() async throws {
        let store = try LibraryStore()
        let code = """
        func handleWebhook(_ event: Event) throws {
            guard let payload = event.payload else { return }
            let status = try await client.post(url, body: payload)
            if status != 200 { throw WebhookError.delivery(status) }
        }
        """
        let pipeline = IndexingPipeline(store: store, recognizer: FakeTextRecognizer(text: code))
        let rec = try await pipeline.index(image: blankImage(), input: input(app: "Terminal"))
        #expect(rec.containsCode == true)
    }

    /// Prose must NOT be flagged as code (heuristic guardrail).
    @Test func proseIsNotFlaggedAsCode() async throws {
        let store = try LibraryStore()
        let prose = """
        The quick brown fox jumps over the lazy dog.
        Stripe webhook delivery failed earlier today.
        Please review the dashboard and retry the request.
        """
        let pipeline = IndexingPipeline(store: store, recognizer: FakeTextRecognizer(text: prose))
        let rec = try await pipeline.index(image: blankImage(), input: input(app: "Notes"))
        #expect(rec.containsCode == false)
    }

    /// Realistic prose that DOES contain common English words once treated as code
    /// keywords (if/let/return/for/case) must still NOT be flagged — the detector no
    /// longer counts ubiquitous words as code signals.
    @Test func proseWithCommonKeywordsIsNotCode() async throws {
        let store = try LibraryStore()
        let prose = """
        If you have questions let me know.
        Return the form by Friday for review.
        In case the meeting runs long we will continue.
        """
        let pipeline = IndexingPipeline(store: store, recognizer: FakeTextRecognizer(text: prose))
        let rec = try await pipeline.index(image: blankImage(), input: input(app: "Mail"))
        #expect(rec.containsCode == false)
    }

    /// Prose mentioning a product name (camelCase) and a domain (dotted token) must
    /// NOT be flagged — a bare camelCase/dotted token in prose is not a code signal.
    @Test func proseWithDomainsAndProductNamesIsNotCode() async throws {
        let store = try LibraryStore()
        let prose = """
        Please check iPhone settings today.
        Visit apple.com for details now.
        Our JavaScript guide is helpful here.
        """
        let pipeline = IndexingPipeline(store: store, recognizer: FakeTextRecognizer(text: prose))
        let rec = try await pipeline.index(image: blankImage(), input: input(app: "Messages"))
        #expect(rec.containsCode == false)
    }

    /// A Python source capture (structural keywords + punctuation) still flips
    /// containsCode — trimming the keyword set didn't break real code detection.
    @Test func pythonSourceIsCode() async throws {
        let store = try LibraryStore()
        let code = """
        def handle(event):
            payload = event.get("payload")
            if payload is None:
                return None
            return client.post(url, body=payload)
        """
        let pipeline = IndexingPipeline(store: store, recognizer: FakeTextRecognizer(text: code))
        let rec = try await pipeline.index(image: blankImage(), input: input(app: "Terminal"))
        #expect(rec.containsCode == true)
    }
}
