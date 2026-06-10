import Testing
@testable import DarkroomInstruments

@Test func budgetMeterReportsPercentiles() {
    let report = BudgetMeter.Report(
        budget: .hotkeyToChip,
        samples: (1 ... 100).map { .milliseconds($0) }
    )
    #expect(report.p50 == .milliseconds(50))
    #expect(report.p95 == .milliseconds(95))
    #expect(report.meetsBudget) // 95ms p95 < 200ms budget
}

@Test func budgetMeterFlagsOverBudget() {
    let report = BudgetMeter.Report(
        budget: .librarySearch,
        samples: [.milliseconds(60), .milliseconds(70), .milliseconds(80)]
    )
    #expect(!report.meetsBudget)
    #expect(report.summary.contains("OVER BUDGET"))
}

@Test func measureRecordsRequestedIterations() {
    let report = BudgetMeter.measure(.editorOpen, iterations: 5, warmup: 1) {
        // trivially fast operation; harness mechanics are what's under test
        _ = (0 ..< 100).reduce(0, +)
    }
    #expect(report.samples.count == 5)
    #expect(report.meetsBudget)
}

@Test func measureAsyncRecordsRequestedIterations() async {
    let report = await BudgetMeter.measure(.hotkeyToChip, iterations: 3, warmup: 0) {
        await Task.yield()
    }
    #expect(report.samples.count == 3)
}

@Test func durationMillisecondsConversion() {
    #expect(Duration.milliseconds(250).milliseconds == 250)
    #expect(Duration.seconds(1).milliseconds == 1000)
}
