import Foundation

/// Keeps system-search donations in sync with the Library (spec §9.7). Sits BETWEEN the
/// app and the store so the store stays pure (no CoreSpotlight coupling) and the donation
/// logic stays headless-testable with a mock `SpotlightIndexing`. The app routes the
/// Spotlight-relevant mutations (donate-after-index, rename, delete, retention eviction)
/// through here; everything else still goes straight to the store.
///
/// Best-effort by contract: a donation/withdrawal failure never propagates — the
/// underlying store mutation has already committed and Spotlight is an enhancement, not a
/// gate (a failed capture/delete because Spotlight hiccuped would violate the trust posture).
public actor SpotlightCoordinator {
    private let store: LibraryStore
    private var index: any SpotlightIndexing

    public init(store: LibraryStore, index: any SpotlightIndexing) {
        self.store = store
        self.index = index
    }

    /// Donate (or update) the donation for one capture id, pulling its current name,
    /// OCR text, and tags from the store. Idempotent — safe to call after the initial
    /// index AND after every rename/re-index (§9.7 "updated on rename/re-index").
    /// Silently no-ops for an unknown/absent id.
    public func donate(captureID: Int64) async {
        guard let item = try? await spotlightItem(forCaptureID: captureID) else { return }
        await index.donate([item])
    }

    /// Donate a batch (e.g. after a backfill). Skips ids that can't be built.
    public func donate(captureIDs ids: [Int64]) async {
        var items: [SpotlightItem] = []
        for id in ids {
            if let item = try? await spotlightItem(forCaptureID: id) { items.append(item) }
        }
        await index.donate(items)
    }

    /// Delete a Library item AND withdraw its donation (§9.7 "Deletion removes the
    /// donation"). The store delete runs first; the donation is withdrawn whether or not
    /// the row existed, so a redundant withdraw is harmless. Does NOT touch the on-disk
    /// original (reference-not-vault — the caller decides the file's fate).
    public func delete(captureID id: Int64) async throws {
        try await store.delete(id: id)
        await index.withdraw(identifiers: [SpotlightItem.identifier(for: id)])
    }

    /// Withdraw donations for items removed by a retention pass (§9.7 withdrawal fires on
    /// "retention-eviction"). The caller has already deleted these rows (the retention
    /// planner previews; the app deletes after confirmation); here we just drop their
    /// donations. Accepts the evicted ids directly so it works regardless of how they
    /// were deleted.
    public func withdrawEvicted(captureIDs ids: [Int64]) async {
        guard !ids.isEmpty else { return }
        await index.withdraw(identifiers: ids.map(SpotlightItem.identifier(for:)))
    }

    /// Rename through the coordinator so the donation is refreshed atomically with the UI
    /// action (§9.7 "updated on rename"). Delegates the sticky-rename semantics to the store.
    public func rename(captureID id: Int64, to name: String) async throws {
        try await store.rename(id: id, to: name)
        await donate(captureID: id)
    }

    /// User disabled Spotlight integration — withdraw EVERY donation this app owns and
    /// swap to a no-op index so nothing is re-donated until re-enabled (§9.7 "withdrawn
    /// entirely if the user disables Spotlight integration").
    public func disableIntegration() async {
        await index.withdrawAll()
        index = NoopSpotlightIndex()
    }

    /// Re-enable integration with a live index (e.g. after `disableIntegration`). Callers
    /// then re-donate the current library via `donate(captureIDs:)`.
    public func enableIntegration(_ liveIndex: any SpotlightIndexing) {
        index = liveIndex
    }

    // MARK: - Internals

    /// Build the donation for a capture id from the store's current state (name, OCR text,
    /// tags). Reads OCR text directly (the record value type doesn't carry it).
    private func spotlightItem(forCaptureID id: Int64) async throws -> SpotlightItem? {
        guard let record = try await store.record(id: id) else { return nil }
        let ocrText = try await store.ocrText(forCapture: id)
        let tags = try await store.tags(forCapture: id)
        return SpotlightDonationBuilder.item(for: record, ocrText: ocrText, tags: tags)
    }
}
