import OneShotInstruments
import Testing

/// Scaffold smoke test: the app target links all OneShotKit packages.
@Test func appLinksOneShotKit() {
    #expect(PerformanceBudget.hotkeyToChip.p95 == .milliseconds(200))
}
