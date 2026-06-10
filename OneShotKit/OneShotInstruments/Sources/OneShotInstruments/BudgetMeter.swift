import Foundation

/// Test-framework-agnostic measurement harness for the PRD §7 budgets.
///
/// Tests run an operation through `measure` and assert on the returned report,
/// e.g. `#expect(report.meetsBudget)` (swift-testing) or
/// `XCTAssertTrue(report.meetsBudget, report.summary)` (XCTest).
/// Keeping assertion out of this type lets the same harness serve unit tests,
/// XCUITest-driven flows, and the release-certification run (task 15.2).
public enum BudgetMeter {
    public struct Report: Sendable {
        public let budget: PerformanceBudget
        /// Wall-clock duration of every iteration, in capture order.
        public let samples: [Duration]

        public var p50: Duration {
            percentile(0.50)
        }

        public var p95: Duration {
            percentile(0.95)
        }

        public var meetsBudget: Bool {
            p95 <= budget.p95
        }

        public var summary: String {
            "\(budget.name): p50=\(p50.milliseconds)ms p95=\(p95.milliseconds)ms " +
                "budget=\(budget.p95.milliseconds)ms over \(samples.count) iterations" +
                (meetsBudget ? " ✓" : " ✗ OVER BUDGET")
        }

        /// Nearest-rank percentile over the recorded samples.
        public func percentile(_ fraction: Double) -> Duration {
            precondition(!samples.isEmpty, "no samples recorded")
            let sorted = samples.sorted()
            let rank = Int((fraction * Double(sorted.count)).rounded(.up))
            return sorted[Swift.max(0, Swift.min(sorted.count - 1, rank - 1))]
        }
    }

    /// Run `operation` `iterations` times (after `warmup` unrecorded runs) and report.
    public static func measure(
        _ budget: PerformanceBudget,
        iterations: Int = 20,
        warmup: Int = 2,
        operation: () throws -> Void
    ) rethrows -> Report {
        let clock = ContinuousClock()
        for _ in 0 ..< warmup {
            try operation()
        }
        var samples: [Duration] = []
        samples.reserveCapacity(iterations)
        for _ in 0 ..< iterations {
            try samples.append(clock.measure(operation))
        }
        return Report(budget: budget, samples: samples)
    }

    /// Async variant for operations that hop actors (capture → chip spans the main actor).
    public static func measure(
        _ budget: PerformanceBudget,
        iterations: Int = 20,
        warmup: Int = 2,
        operation: () async throws -> Void
    ) async rethrows -> Report {
        let clock = ContinuousClock()
        for _ in 0 ..< warmup {
            try await operation()
        }
        var samples: [Duration] = []
        samples.reserveCapacity(iterations)
        for _ in 0 ..< iterations {
            let start = clock.now
            try await operation()
            samples.append(clock.now - start)
        }
        return Report(budget: budget, samples: samples)
    }
}

public extension Duration {
    /// Milliseconds as a Double, for human-readable reports.
    var milliseconds: Double {
        Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15
    }
}
