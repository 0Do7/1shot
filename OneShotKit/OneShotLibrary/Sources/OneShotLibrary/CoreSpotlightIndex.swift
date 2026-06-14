#if canImport(CoreSpotlight)
    import CoreSpotlight
    import Foundation
    import UniformTypeIdentifiers

    /// Thin production `SpotlightIndexing` over `CSSearchableIndex` (spec §9.7). Deliberately
    /// minimal — all the "what to donate" logic is in the headless `SpotlightDonationBuilder`;
    /// this only translates `SpotlightItem` ⇄ `CSSearchableItem` and calls the OS index.
    ///
    /// Best-effort: every operation swallows its error (logged by the OS), because a failed
    /// donation/withdrawal MUST NOT fail the capture/index/delete that triggered it.
    public final class CoreSpotlightIndex: SpotlightIndexing, @unchecked Sendable {
        // @unchecked Sendable: `CSSearchableIndex.default()` is the process-wide,
        // thread-safe OS index singleton; the stored reference is immutable and every
        // method only forwards to that thread-safe object, so there is no unsynchronized
        // mutable state to protect.

        /// Domain used for `withdrawAll` so disabling integration removes exactly this app's
        /// donations and nothing else (spec §9.7 "withdrawn entirely").
        public static let domainIdentifier = "com.sidequests.oneshot.library"

        private let index: CSSearchableIndex

        public init(index: CSSearchableIndex = .default()) {
            self.index = index
        }

        public func donate(_ items: [SpotlightItem]) async {
            guard !items.isEmpty else { return }
            let searchable = items.map(Self.searchableItem)
            try? await index.indexSearchableItems(searchable)
        }

        public func withdraw(identifiers: [String]) async {
            guard !identifiers.isEmpty else { return }
            try? await index.deleteSearchableItems(withIdentifiers: identifiers)
        }

        public func withdrawAll() async {
            try? await index.deleteSearchableItems(withDomainIdentifiers: [Self.domainIdentifier])
        }

        private static func searchableItem(_ item: SpotlightItem) -> CSSearchableItem {
            let attributes = CSSearchableItemAttributeSet(contentType: .image)
            attributes.title = item.title
            attributes.contentDescription = item.contentDescription
            attributes.keywords = item.keywords
            attributes.contentURL = URL(fileURLWithPath: item.originalPath)
            return CSSearchableItem(
                uniqueIdentifier: item.id,
                domainIdentifier: domainIdentifier,
                attributeSet: attributes
            )
        }
    }
#endif
