/// A cancellable integer countdown for delayed capture (spec:capture-engine
/// "Delayed capture": a visible countdown, cancellable, firing after the
/// configured interval). Tick-driven so it is deterministic in tests; the app
/// advances it with a 1 Hz timer and renders `remaining`.
@MainActor
final class CaptureCountdown {
    private(set) var remaining: Int
    private(set) var isCancelled = false

    init(seconds: Int) {
        remaining = Swift.max(0, seconds)
    }

    /// True once the countdown has elapsed without being cancelled.
    var isFinished: Bool {
        !isCancelled && remaining == 0
    }

    /// Advance one second. Returns `true` on the tick that reaches zero (the
    /// capture should fire). No-op once cancelled or already at zero.
    @discardableResult
    func tick() -> Bool {
        guard !isCancelled, remaining > 0 else { return false }
        remaining -= 1
        return remaining == 0
    }

    func cancel() {
        isCancelled = true
    }
}
