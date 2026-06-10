import DarkroomInstruments
import Testing

/// Scaffold smoke test: the app target links all DarkroomKit packages.
@Test func appLinksDarkroomKit() {
    #expect(PerformanceBudget.hotkeyToChip.p95 == .milliseconds(200))
}
