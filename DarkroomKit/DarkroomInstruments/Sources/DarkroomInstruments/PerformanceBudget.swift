import Foundation

/// The PRD §7 latency budgets, in one place so tests and signposts agree.
/// Budgets are product requirements — change only with a PRD change.
public struct PerformanceBudget: Sendable, Hashable {
    /// Stable identifier used in signpost names and test output.
    public let name: String
    /// The p95 ceiling for this interaction.
    public let p95: Duration

    public init(name: String, p95: Duration) {
        self.name = name
        self.p95 = p95
    }

    /// Hotkey press → post-capture chip visible. PRD §7: < 200 ms p95.
    public static let hotkeyToChip = PerformanceBudget(name: "hotkey-to-chip", p95: .milliseconds(200))

    /// Chip/Library → editor window interactive. PRD §7: < 400 ms p95.
    public static let editorOpen = PerformanceBudget(name: "editor-open", p95: .milliseconds(400))

    /// Library FTS5 search over 10k items. PRD §7: < 50 ms.
    public static let librarySearch = PerformanceBudget(name: "library-search-10k", p95: .milliseconds(50))

    /// Beautify preset render. PRD E9 / task 10.7: < 500 ms.
    public static let beautifyRender = PerformanceBudget(name: "beautify-render", p95: .milliseconds(500))
}
