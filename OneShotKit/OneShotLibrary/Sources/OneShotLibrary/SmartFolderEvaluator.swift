import Foundation

/// Evaluates smart folders against the live Library store (spec §9.5). A smart
/// folder is a saved *query*: this compiles its predicates to `SearchFilters` and
/// runs a filter-only search, so membership re-derives from current store contents
/// every time — it "updates automatically as items are added or re-indexed".
///
/// It owns no state beyond the store + a `LibrarySearch`, so two evaluations of the
/// same folder at different times can legitimately differ (a rolling date bucket,
/// newly indexed items). That is the intended behavior, not drift.
public struct SmartFolderEvaluator: Sendable {
    private let store: LibraryStore
    private let search: LibrarySearch

    public init(store: LibraryStore) {
        self.store = store
        search = LibrarySearch(store: store)
    }

    /// Resolve `folder` to its matching captures, newest-first. `now`/`calendar`
    /// anchor any rolling date bucket so membership is deterministic for a given
    /// instant. An empty folder result is honest (no matches), never an error.
    public func captures(
        in folder: SmartFolder,
        now: Date = Date(),
        calendar: Calendar = .current,
        limit: Int = 5000
    ) async throws -> [CaptureRecord] {
        let filters = folder.compile(now: now, calendar: calendar)
        let hits = try await search.search("", filters: filters, limit: limit)
        return hits.map(\.record)
    }

    /// Count matches without materializing every record (cheap folder badges).
    public func count(
        in folder: SmartFolder,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> Int {
        try await captures(in: folder, now: now, calendar: calendar).count
    }

    /// The auto-generated built-in folder set (spec §9.5: built-ins ship with "zero
    /// user setup"): one per source app present in the store, the contains-code
    /// folder, and the standard date buckets. Per-app folders are derived live from
    /// the store so they appear/disappear as apps are captured.
    public func builtInFolders() async throws -> [SmartFolder] {
        let apps = try await store.distinctAppNames()
        var folders: [SmartFolder] = apps.map(SmartFolder.perApp)
        folders.append(.containsCode())
        folders.append(contentsOf: DateBucket.allCases.map { SmartFolder.dates($0) })
        return folders
    }
}
