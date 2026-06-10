import Foundation
import os

/// os_signpost instrumentation for the budgeted interactions (PRD §7).
///
/// Production code brackets each budgeted interaction with `begin`/`end` so the
/// intervals are visible in Instruments and measurable by the budget harness.
/// Signpost names equal `PerformanceBudget.name` — keep them in sync.
public enum DarkroomSignpost {
    public static let subsystem = "com.sidequests.darkroom"

    /// One signposter per budgeted surface, so Instruments can filter by category.
    public static let capture = OSSignposter(subsystem: subsystem, category: "capture")
    public static let editor = OSSignposter(subsystem: subsystem, category: "editor")
    public static let library = OSSignposter(subsystem: subsystem, category: "library")
    public static let render = OSSignposter(subsystem: subsystem, category: "render")

    /// Begin an interval for a budgeted interaction. Pass the returned state to `end`.
    public static func begin(_ budget: PerformanceBudget, on signposter: OSSignposter) -> OSSignpostIntervalState {
        signposter.beginInterval("budget", id: signposter.makeSignpostID(), "\(budget.name)")
    }

    public static func end(_ state: OSSignpostIntervalState, on signposter: OSSignposter) {
        signposter.endInterval("budget", state)
    }
}
