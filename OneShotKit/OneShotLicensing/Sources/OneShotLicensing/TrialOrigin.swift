import Foundation

/// Where the trial clock comes from. The start instant is recorded redundantly
/// in two backing stores — the app's receipt/preferences store AND a Keychain
/// mirror (design D10, spec: "trial start recorded redundantly (receipt store
/// plus Keychain)"). Deleting preferences restores the clock from the Keychain
/// rather than restarting it (spec: "Casual reset defeated"). We accept that a
/// determined user can clear the Keychain too — dignity over DRM.
///
/// The two concrete stores (Defaults + Keychain) live in the app layer; this
/// protocol keeps the trial logic testable with in-memory fakes.
public protocol TrialOriginStore: Sendable {
    /// The earliest recorded start, or `nil` if this store has none.
    func read() -> Date?
    /// Persist the start instant.
    func write(_ start: Date)
}

/// Resolves the effective trial start from any number of redundant stores. The
/// rule: the EARLIEST non-nil value wins (so wiping one store can't reset the
/// clock forward), and any store missing the value is backfilled — this is what
/// makes a preferences-only wipe recover from the Keychain mirror.
public struct TrialOriginResolver: Sendable {
    private let stores: [any TrialOriginStore]

    public init(stores: [any TrialOriginStore]) {
        self.stores = stores
    }

    /// Return the established trial start, beginning (and backfilling) it at
    /// `now` on genuine first launch when no store holds a value.
    @discardableResult
    public func establishStart(now: Date) -> Date {
        let recorded = stores.compactMap { $0.read() }
        let start = recorded.min() ?? now
        // Backfill every store that is missing or later than the canonical start
        // (defeats a partial wipe).
        for store in stores where store.read() == nil || (store.read().map { $0 > start } ?? false) {
            store.write(start)
        }
        return start
    }

    /// Read-only view of the established start without writing (nil = never started).
    public func resolvedStart() -> Date? {
        stores.compactMap { $0.read() }.min()
    }
}

/// Guards the trial clock against system-clock rollback. It persists a
/// monotonic high-water-mark — the latest instant the app has ever observed —
/// redundantly across the same stores as the trial origin (prefs + Keychain
/// mirror). The trial decision is then evaluated against `max(now,
/// highWaterMark)` instead of the raw, attacker-controlled `now`, so an expired
/// trial cannot be re-granted by setting the macOS clock backward.
///
/// We deliberately only clamp the trial path; the licensed offline-grace window
/// is intentionally generous and is governed by the signed `lastValidatedAt`,
/// not by this guard.
public struct TrialClockGuard: Sendable {
    private let stores: [any TrialOriginStore]

    public init(stores: [any TrialOriginStore]) {
        self.stores = stores
    }

    /// Record `now` as observed and return the rollback-protected instant to use
    /// for trial arithmetic: the greater of `now` and the highest instant ever
    /// seen. Backfills every store that is behind the new high-water-mark, so a
    /// partial wipe cannot drop the mark.
    @discardableResult
    public func observe(now: Date) -> Date {
        let highWaterMark = max(now, stores.compactMap { $0.read() }.max() ?? now)
        for store in stores where (store.read() ?? .distantPast) < highWaterMark {
            store.write(highWaterMark)
        }
        return highWaterMark
    }

    /// Read-only rollback-protected instant without writing: the greater of `now`
    /// and the recorded high-water-mark.
    public func protectedNow(_ now: Date) -> Date {
        max(now, stores.compactMap { $0.read() }.max() ?? now)
    }
}

/// A simple in-memory `TrialOriginStore` for tests (and a reference for the
/// app-layer Defaults/Keychain implementations). `@unchecked Sendable`: the
/// single optional is guarded by a lock.
public final class InMemoryTrialOriginStore: TrialOriginStore, @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date?

    public init(_ value: Date? = nil) {
        self.value = value
    }

    public func read() -> Date? {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    public func write(_ start: Date) {
        lock.lock(); defer { lock.unlock() }
        value = start
    }

    /// Test affordance: simulate a wipe of this store (e.g. deleting prefs).
    public func clear() {
        lock.lock(); defer { lock.unlock() }
        value = nil
    }
}
