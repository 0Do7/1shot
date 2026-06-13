import Foundation
import GRDB

/// One search hit: the matched record plus an FTS5 `snippet()` showing WHY it
/// matched (spec §9.3: "indicate why each item matched"). `snippet` is nil when
/// the match was NOT in the OCR text (e.g. a name-, tag-, or provenance-only hit),
/// so it never surfaces an unrelated OCR excerpt as the reason for the match.
public struct SearchHit: Sendable, Hashable {
    public var record: CaptureRecord
    /// Highlighted excerpt of the matching OCR text, with `[` / `]` marking the
    /// matched terms. Nil unless the query actually matched the OCR text — a
    /// non-highlighted excerpt is never a valid "why matched" signal.
    public var snippet: String?

    public init(record: CaptureRecord, snippet: String?) {
        self.record = record
        self.snippet = snippet
    }
}

/// Structured filters layered on top of the full-text query (spec §9.3:
/// "filters (app/date/tag/type)"). All optional and ANDed together. Any filter may
/// be used with an empty query to browse purely by filter.
public struct SearchFilters: Sendable, Hashable {
    /// Exact source application display name (e.g. "Xcode").
    public var appName: String?
    /// Inclusive lower bound on capture time.
    public var capturedAfter: Date?
    /// Inclusive upper bound on capture time.
    public var capturedBefore: Date?
    /// Require this manual tag.
    public var tag: String?
    /// Restrict to a media type (MVP only ever has `.image`).
    public var mediaType: MediaType?
    /// Require the stored `containsCode` flag to equal this value. Smart folders
    /// (§9.5 contains-code) compile to this; it reuses the index-time heuristic
    /// result rather than re-scanning OCR, so membership is consistent and cheap.
    public var containsCode: Bool?

    public init(
        appName: String? = nil,
        capturedAfter: Date? = nil,
        capturedBefore: Date? = nil,
        tag: String? = nil,
        mediaType: MediaType? = nil,
        containsCode: Bool? = nil
    ) {
        self.appName = appName
        self.capturedAfter = capturedAfter
        self.capturedBefore = capturedBefore
        self.tag = tag
        self.mediaType = mediaType
        self.containsCode = containsCode
    }

    var isEmpty: Bool {
        appName == nil && capturedAfter == nil && capturedBefore == nil
            && tag == nil && mediaType == nil && containsCode == nil
    }
}

/// Full-text + filtered search over the Library (spec §9.3). FTS5 with prefix
/// matching (`term*`), bm25() relevance ranking, and snippet() match highlighting.
///
/// Honest empty result (product law): a query with no matches returns `[]`, which
/// the UI renders as an explicit no-results state — never a blank/stale list.
public struct LibrarySearch: Sendable {
    private let store: LibraryStore

    public init(store: LibraryStore) {
        self.store = store
    }

    /// Run a search. `query` is the user's raw text (may be empty to browse by
    /// filters). Prefix matching is automatic so partial words match while typing.
    /// Results are ordered by bm25() relevance (best first) when a query is present,
    /// else newest-first.
    public func search(
        _ query: String,
        filters: SearchFilters = SearchFilters(),
        limit: Int = 200
    ) async throws -> [SearchHit] {
        let pattern = Self.ftsPattern(for: query)

        return try await store.read { db in
            var sql: String
            var args: [(any DatabaseValueConvertible)?] = []

            if let pattern {
                // snippet(): column 1 (ocrText), '[' / ']' delimiters, '…' ellipsis,
                // up to 16 tokens. bm25() ascends with relevance (lower = better),
                // so ORDER BY bm25() ASC puts the best match first.
                sql = """
                SELECT c.*, snippet(captures_fts, 1, '[', ']', '…', 16) AS snip
                FROM captures_fts f
                JOIN captures c ON c.id = f.rowid
                WHERE captures_fts MATCH ?
                """
                args.append(pattern)
            } else {
                sql = "SELECT c.*, NULL AS snip FROM captures c WHERE 1 = 1"
            }

            Self.appendFilters(filters, to: &sql, args: &args, captureAlias: "c", db: db)

            if pattern != nil {
                sql += " ORDER BY bm25(captures_fts) ASC, c.capturedAt DESC"
            } else {
                sql += " ORDER BY c.capturedAt DESC"
            }
            sql += " LIMIT ?"
            args.append(limit)

            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(args))
            return rows.map { row in
                SearchHit(
                    record: LibraryStore.record(from: row),
                    snippet: Self.ocrSnippet(from: row["snip"])
                )
            }
        }
    }

    /// Open delimiter passed to FTS5 `snippet()`; its presence proves the excerpt
    /// actually highlights a matched term in the OCR column.
    private static let highlightOpen = "["

    /// Validate the FTS5 `snippet()` output as a genuine "why matched" OCR excerpt.
    ///
    /// `snippet()` always excerpts the OCR column (column 1), but FTS5 only inserts
    /// the `[`/`]` highlight delimiters when the matched term is actually in that
    /// column. For a name-, tag-, or provenance-only match it returns the raw OCR
    /// text with NO brackets — an excerpt that has nothing to do with why the item
    /// matched (spec §9.3 requires the result to "indicate why each item matched").
    /// So treat a snippet as valid only when it contains the highlight delimiter;
    /// otherwise return nil and let the UI surface the matched field another way.
    private static func ocrSnippet(from raw: String?) -> String? {
        guard let raw, raw.contains(highlightOpen) else { return nil }
        return raw
    }

    // MARK: - Filter SQL

    private static func appendFilters(
        _ filters: SearchFilters,
        to sql: inout String,
        args: inout [(any DatabaseValueConvertible)?],
        captureAlias alias: String,
        db: Database
    ) {
        if let appName = filters.appName {
            sql += " AND \(alias).appName = ?"
            args.append(appName)
        }
        if let after = filters.capturedAfter {
            sql += " AND \(alias).capturedAt >= ?"
            args.append(after.timeIntervalSince1970)
        }
        if let before = filters.capturedBefore {
            sql += " AND \(alias).capturedAt <= ?"
            args.append(before.timeIntervalSince1970)
        }
        if let mediaType = filters.mediaType {
            sql += " AND \(alias).mediaType = ?"
            args.append(mediaType.rawValue)
        }
        if let containsCode = filters.containsCode {
            sql += " AND \(alias).containsCode = ?"
            args.append(containsCode)
        }
        if let tag = filters.tag {
            sql += """
             AND EXISTS (
                SELECT 1 FROM capture_tags ct JOIN tags t ON t.id = ct.tagID
                WHERE ct.captureID = \(alias).id AND t.name = ?
            )
            """
            args.append(tag)
        }
    }

    // MARK: - FTS5 pattern building

    /// Build a safe FTS5 MATCH pattern from raw user input, applying prefix matching
    /// to the final term so partial words match while typing (spec: "Live results
    /// while typing"). Each token is double-quoted (FTS5 string literal) to neutralize
    /// FTS5 query operators, with a trailing `*` for prefix matching.
    ///
    /// Returns nil for an effectively empty query (browse-by-filter mode).
    static func ftsPattern(for query: String) -> String? {
        // Tokenize on whitespace and FTS-significant punctuation; keep dots so a
        // domain like "github.com" survives as one token (provenance URL search).
        let raw = query.lowercased()
        let separators = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: "\"'()*:^"))
        let tokens = raw
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return nil }

        // Every term is a prefix term so "webho" matches "webhook" mid-typing.
        return tokens
            .map { "\"\($0)\"*" }
            .joined(separator: " ")
    }
}
