import Foundation

/// A headless, framework-free description of what to donate to system search for ONE
/// Library item (spec §9.7). Built from a `CaptureRecord` + its OCR text + tags so the
/// donation logic is unit-testable without CoreSpotlight. The real adapter maps this to
/// a `CSSearchableItem`; a mock adapter records it.
public struct SpotlightItem: Sendable, Hashable, Identifiable {
    /// Stable unique identifier for the donation (and the activation deep-link target).
    /// Encodes the Library row id so activating the result reopens THAT item (§9.7
    /// "selecting it opens that item in the Library"). See `SpotlightItem.identifier(for:)`.
    public var id: String
    /// Display title — the item's (auto or manual) name.
    public var title: String
    /// OCR text, so Spotlight finds the capture by words that were only ever pixels.
    public var contentDescription: String?
    /// Provenance + tag keywords (app name, window title, URL host, tags) for keyword search.
    public var keywords: [String]
    /// Absolute path of the user-visible original, so the result can carry a thumbnail/url.
    public var originalPath: String

    public init(
        id: String,
        title: String,
        contentDescription: String?,
        keywords: [String],
        originalPath: String
    ) {
        self.id = id
        self.title = title
        self.contentDescription = contentDescription
        self.keywords = keywords
        self.originalPath = originalPath
    }

    /// The donation/deep-link identifier for a capture row id. The app's activation
    /// handler parses this back to the id via `captureID(fromIdentifier:)`.
    public static func identifier(for captureID: Int64) -> String {
        "\(identifierPrefix)\(captureID)"
    }

    /// Parse a donation identifier back to its Library row id, or nil if it isn't ours.
    public static func captureID(fromIdentifier identifier: String) -> Int64? {
        guard identifier.hasPrefix(identifierPrefix) else { return nil }
        return Int64(identifier.dropFirst(identifierPrefix.count))
    }

    private static let identifierPrefix = "com.sidequests.oneshot.library.item."
}

/// Donates/withdraws Library items to/from system search (spec §9.7). Injected so the
/// donation PIPELINE stays headless-testable with a mock; the real `CSSearchableIndex`
/// adapter is kept thin. All calls are best-effort: a failed donation MUST NOT fail a
/// capture/index/delete (Spotlight is an enhancement, never a gate).
public protocol SpotlightIndexing: Sendable {
    /// Donate (insert or update) these items. Idempotent per identifier — re-donating an
    /// item with the same id updates it, so rename/re-index just re-donates (§9.7
    /// "Donations SHALL be updated on rename/re-index").
    func donate(_ items: [SpotlightItem]) async
    /// Withdraw the donations for these identifiers (item delete / retention eviction).
    func withdraw(identifiers: [String]) async
    /// Withdraw EVERY donation this app owns (user disabled Spotlight integration —
    /// §9.7 "the donation SHALL be withdrawn entirely").
    func withdrawAll() async
}

/// No-op `SpotlightIndexing` — the safe default when integration is disabled or on a
/// platform without CoreSpotlight. Lets all call sites donate/withdraw unconditionally.
public struct NoopSpotlightIndex: SpotlightIndexing {
    public init() {}
    public func donate(_: [SpotlightItem]) async {}
    public func withdraw(identifiers _: [String]) async {}
    public func withdrawAll() async {}
}

// MARK: - Donation building

/// Maps Library records into `SpotlightItem`s (spec §9.7: findable "by name, OCR text,
/// and provenance keywords"). Pure + headless — the indexing pipeline / app calls this,
/// then hands the result to whatever `SpotlightIndexing` is wired in.
public enum SpotlightDonationBuilder {
    /// Build a donation for one record. `ocrText` and `tags` are supplied by the store
    /// (the record itself doesn't carry OCR text). A record without an id can't be
    /// donated (no stable identifier) ⇒ nil.
    public static func item(for record: CaptureRecord, ocrText: String?, tags: [String]) -> SpotlightItem? {
        guard let id = record.id else { return nil }
        var keywords: [String] = []
        if let app = record.provenance.appName { keywords.append(app) }
        if let title = record.provenance.windowTitle { keywords.append(title) }
        if let host = record.provenance.url.flatMap({ URL(string: $0)?.host }) { keywords.append(host) }
        keywords.append(contentsOf: tags)
        return SpotlightItem(
            id: SpotlightItem.identifier(for: id),
            title: record.name,
            contentDescription: ocrText,
            keywords: keywords,
            originalPath: record.originalPath
        )
    }
}
