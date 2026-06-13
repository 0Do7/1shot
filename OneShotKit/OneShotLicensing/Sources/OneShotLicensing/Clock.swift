import Foundation

/// Time is injected, never read ambiently. Every piece of license/trial/grace
/// logic takes an explicit `now:` (design D10 — trial and grace boundaries are
/// the whole behavior, so they must be deterministically testable). Production
/// passes `SystemClock`; tests advance a `FixedClock` across day 0/13/14/14+23h/15.
public protocol DateProviding: Sendable {
    func now() -> Date
}

/// Production clock: wall-clock time.
public struct SystemClock: DateProviding {
    public init() {}
    public func now() -> Date {
        Date()
    }
}

/// Test clock: returns a settable instant so tests can step across boundaries.
/// `@unchecked Sendable`: the single mutable field is guarded by an internal
/// lock, so concurrent reads/advances are safe.
public final class FixedClock: DateProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var instant: Date

    public init(_ instant: Date) {
        self.instant = instant
    }

    public func now() -> Date {
        lock.lock(); defer { lock.unlock() }
        return instant
    }

    /// Jump to an absolute instant.
    public func set(_ instant: Date) {
        lock.lock(); defer { lock.unlock() }
        self.instant = instant
    }

    /// Advance by a relative interval (seconds).
    public func advance(by interval: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        instant = instant.addingTimeInterval(interval)
    }
}

/// Named durations used across the licensing rules, so the boundaries live in
/// one place and read the same in code and tests.
public enum LicensingDuration {
    public static let day: TimeInterval = 24 * 60 * 60
    /// Full-featured trial length (spec: "Fourteen-day full-featured trial").
    public static let trial: TimeInterval = 14 * day
    /// Post-expiry capture grace (spec: "Dignified trial expiry" — 24h).
    public static let captureGrace: TimeInterval = day
    /// Tolerated offline window before a licensed app warns (spec: "Fourteen-day
    /// offline grace").
    public static let offlineGrace: TimeInterval = 14 * day
}
