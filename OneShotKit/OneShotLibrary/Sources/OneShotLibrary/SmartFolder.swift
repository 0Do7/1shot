import Foundation

/// A coarse, named date window for the date-based smart folders (spec §9.5:
/// "date-based folders (e.g. Today, This Week)"). Resolved against a reference
/// `now` + calendar so membership is deterministic and timezone-correct; the
/// bucket itself stores no absolute dates, so a saved smart folder stays a
/// "rolling" window that re-evaluates each time it is opened.
public enum DateBucket: String, Codable, Sendable, Hashable, CaseIterable {
    case today
    case yesterday
    case thisWeek
    case thisMonth

    /// Resolve to an inclusive `[start, end]` capture-time range for `now`.
    /// `thisWeek`/`thisMonth` extend from the start of the period through `now`.
    func range(now: Date, calendar: Calendar) -> (start: Date, end: Date) {
        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            return (start, now)
        case .yesterday:
            let startOfToday = calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
            return (start, startOfToday)
        case .thisWeek:
            return (Self.startOfPeriod(.weekOfYear, now: now, calendar: calendar), now)
        case .thisMonth:
            return (Self.startOfPeriod(.month, now: now, calendar: calendar), now)
        }
    }

    private static func startOfPeriod(
        _ component: Calendar.Component,
        now: Date,
        calendar: Calendar
    ) -> Date {
        let interval = calendar.dateInterval(of: component, for: now)
        return interval?.start ?? calendar.startOfDay(for: now)
    }
}

/// One clause of a smart folder's saved query (spec §9.5: "predicates over source
/// app / date range / contains-code / tag / media type"). Codable so a smart
/// folder persists as a portable, human-meaningful definition rather than a frozen
/// list of matching ids. Predicates compile down to `SearchFilters` (§9.3).
public enum SmartFolderPredicate: Codable, Sendable, Hashable {
    /// Captures whose recorded source app equals this display name.
    case sourceApp(String)
    /// Captures within an explicit absolute capture-time range (either bound optional).
    case dateRange(after: Date?, before: Date?)
    /// Captures within a rolling named window (Today / This Week / …).
    case dateBucket(DateBucket)
    /// Captures whose index-time contains-code heuristic equals `value`.
    case containsCode(Bool)
    /// Captures carrying this manual tag.
    case tag(String)
    /// Captures of this media type (MVP only ever produces `.image`).
    case mediaType(MediaType)
}

/// A saved, Codable smart-folder definition (spec §9.5). A smart folder is a *query*,
/// not a stored membership list: it re-evaluates against the live store every time,
/// so membership updates automatically as items are added or re-indexed.
///
/// Predicates are ANDed. Because the underlying `SearchFilters` carries one value per
/// dimension, a folder SHOULD hold at most one predicate per kind; when two predicates
/// of the same kind are present the later one wins (documented, deterministic).
public struct SmartFolder: Codable, Sendable, Hashable, Identifiable {
    /// Stable identity for persistence/selection. Built-ins use a derived stable id.
    public var id: String
    /// Human-meaningful display name (e.g. "Xcode", "Contains code", "Today").
    public var name: String
    /// Whether the app generated this folder automatically (built-in) vs. user-saved.
    public var isBuiltIn: Bool
    /// The ANDed predicate set this folder compiles to.
    public var predicates: [SmartFolderPredicate]

    public init(
        id: String,
        name: String,
        isBuiltIn: Bool = false,
        predicates: [SmartFolderPredicate]
    ) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.predicates = predicates
    }
}

// MARK: - Compilation to SearchFilters

public extension SmartFolder {
    /// Compile this folder's predicates into a `SearchFilters` (§9.3). The date
    /// predicates resolve against `now`/`calendar` so a rolling bucket is correct at
    /// evaluation time. Browsing is filter-only, so the companion search query is
    /// always empty — a smart folder selects by rule, not by typed text.
    func compile(now: Date = Date(), calendar: Calendar = .current) -> SearchFilters {
        var filters = SearchFilters()
        for predicate in predicates {
            apply(predicate, to: &filters, now: now, calendar: calendar)
        }
        return filters
    }

    private func apply(
        _ predicate: SmartFolderPredicate,
        to filters: inout SearchFilters,
        now: Date,
        calendar: Calendar
    ) {
        switch predicate {
        case let .sourceApp(name):
            filters.appName = name
        case let .dateRange(after, before):
            filters.capturedAfter = after
            filters.capturedBefore = before
        case let .dateBucket(bucket):
            let range = bucket.range(now: now, calendar: calendar)
            filters.capturedAfter = range.start
            filters.capturedBefore = range.end
        case let .containsCode(value):
            filters.containsCode = value
        case let .tag(name):
            filters.tag = name
        case let .mediaType(type):
            filters.mediaType = type
        }
    }
}

// MARK: - Built-in factories

public extension SmartFolder {
    /// A per-source-app folder (spec §9.5: "per-source-app folders"). Membership =
    /// every capture whose provenance records `appName`.
    static func perApp(_ appName: String) -> SmartFolder {
        SmartFolder(
            id: "builtin.app.\(appName)",
            name: appName,
            isBuiltIn: true,
            predicates: [.sourceApp(appName)]
        )
    }

    /// The contains-code folder (spec §9.5: "a contains-code folder (heuristic
    /// detection from OCR content … no AI)"). Reuses the index-time `containsCode`
    /// flag — no re-scan, no model.
    static func containsCode() -> SmartFolder {
        SmartFolder(
            id: "builtin.containsCode",
            name: "Contains Code",
            isBuiltIn: true,
            predicates: [.containsCode(true)]
        )
    }

    /// A date-bucket folder (spec §9.5: "date-based folders (e.g. Today, This Week)").
    static func dates(_ bucket: DateBucket, name: String? = nil) -> SmartFolder {
        SmartFolder(
            id: "builtin.date.\(bucket.rawValue)",
            name: name ?? defaultName(for: bucket),
            isBuiltIn: true,
            predicates: [.dateBucket(bucket)]
        )
    }

    private static func defaultName(for bucket: DateBucket) -> String {
        switch bucket {
        case .today: "Today"
        case .yesterday: "Yesterday"
        case .thisWeek: "This Week"
        case .thisMonth: "This Month"
        }
    }
}
