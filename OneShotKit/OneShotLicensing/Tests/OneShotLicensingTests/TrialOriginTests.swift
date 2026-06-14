import Foundation
import Testing
@testable import OneShotLicensing

// 14.2 — redundant trial-start recording (receipt/prefs store + Keychain mirror)
// defeats a casual reset. Spec scenario: "Casual reset defeated".

struct TrialOriginTests {
    /// Spec scenario: Casual reset defeated — deleting the prefs store and
    /// relaunching restores the trial clock from the Keychain mirror rather than
    /// restarting it.
    @Test func casualResetDefeated() {
        let prefs = InMemoryTrialOriginStore() // app preferences
        let keychain = InMemoryTrialOriginStore() // Keychain mirror
        let resolver = TrialOriginResolver(stores: [prefs, keychain])

        // First launch establishes the start in BOTH stores.
        let start = resolver.establishStart(now: Fixtures.day0)
        #expect(prefs.read() == Fixtures.day0)
        #expect(keychain.read() == Fixtures.day0)

        // User deletes preferences and relaunches 10 days later.
        prefs.clear()
        let later = Fixtures.day0.addingTimeInterval(10 * LicensingDuration.day)
        let restored = resolver.establishStart(now: later)

        // The original start is restored from the Keychain mirror — NOT reset.
        #expect(restored == start)
        #expect(prefs.read() == Fixtures.day0) // backfilled from the mirror
    }

    /// The earliest recorded start wins, so wiping one store cannot move the clock
    /// forward even if a later value somehow appears.
    @Test func earliestRecordedStartWins() {
        let a = InMemoryTrialOriginStore(Fixtures.day0.addingTimeInterval(5 * LicensingDuration.day))
        let b = InMemoryTrialOriginStore(Fixtures.day0) // earlier
        let resolver = TrialOriginResolver(stores: [a, b])
        #expect(resolver.resolvedStart() == Fixtures.day0)
        // establishStart backfills the later store down to the earliest.
        _ = resolver.establishStart(now: Fixtures.day0.addingTimeInterval(20 * LicensingDuration.day))
        #expect(a.read() == Fixtures.day0)
    }

    /// Genuine first launch (no store has a value) begins the trial at `now`.
    @Test func genuineFirstLaunchStartsTrialNow() {
        let resolver = TrialOriginResolver(stores: [InMemoryTrialOriginStore(), InMemoryTrialOriginStore()])
        #expect(resolver.resolvedStart() == nil)
        let start = resolver.establishStart(now: Fixtures.day0)
        #expect(start == Fixtures.day0)
    }

    /// `TrialClockGuard` records the highest instant ever observed and never
    /// lowers it, so reading back a rolled-back `now` returns the high-water-mark.
    @Test func clockGuardHoldsHighWaterMark() {
        let prefs = InMemoryTrialOriginStore()
        let keychain = InMemoryTrialOriginStore()
        let guardian = TrialClockGuard(stores: [prefs, keychain])

        let later = Fixtures.day0.addingTimeInterval(20 * LicensingDuration.day)
        #expect(guardian.observe(now: later) == later)
        #expect(prefs.read() == later)
        #expect(keychain.read() == later) // mirrored across stores

        // Clock rolled back: observe and read-only both clamp UP to the mark.
        #expect(guardian.observe(now: Fixtures.day0) == later)
        #expect(guardian.protectedNow(Fixtures.day0) == later)
        #expect(prefs.read() == later) // mark never lowered
    }

    /// Spec-adjacent hardening: an EXPIRED trial cannot be re-granted by winding
    /// the macOS system clock backward. Once the manager has observed time past
    /// expiry, rolling `now` back keeps the state `.expired`.
    @Test func clockRollbackDoesNotRegrantTrial() async {
        let (signer, verifier) = Fixtures.keyPair()
        let server = Fixtures.server(signer: signer)
        let clock = FixedClock(Fixtures.day0)
        let mgr = Fixtures.manager(server: server, verifier: verifier, clock: clock)
        await mgr.startTrialIfNeeded()

        // Advance past trial + grace; the high-water-mark is recorded on read.
        clock.advance(by: 16 * LicensingDuration.day)
        #expect(await mgr.currentState() == .expired)

        // Attacker winds the clock back to before expiry. Trial must NOT return.
        clock.set(Fixtures.day0.addingTimeInterval(5 * LicensingDuration.day))
        #expect(await mgr.currentState() == .expired)

        // Even all the way back to day 0.
        clock.set(Fixtures.day0)
        #expect(await mgr.currentState() == .expired)
    }

    /// End-to-end through the manager: wiping the receipt store after expiry does
    /// not revive capture, because the trial origin survives in the mirror.
    @Test func managerCasualResetKeepsTrialExpired() async {
        let (signer, verifier) = Fixtures.keyPair()
        let server = Fixtures.server(signer: signer)
        let clock = FixedClock(Fixtures.day0)
        let prefs = InMemoryTrialOriginStore()
        let keychain = InMemoryTrialOriginStore()
        let receiptStore = InMemoryReceiptStore()
        let mgr = Fixtures.manager(
            server: server, verifier: verifier, clock: clock,
            receiptStore: receiptStore, trialStores: [prefs, keychain]
        )
        await mgr.startTrialIfNeeded()

        // Run past trial + grace.
        clock.advance(by: 16 * LicensingDuration.day)
        #expect(await mgr.currentState() == .expired)

        // "Casual reset": wipe prefs + receipt store. Keychain mirror persists.
        prefs.clear()
        receiptStore.clear()
        await mgr.startTrialIfNeeded() // relaunch
        #expect(await mgr.currentState() == .expired) // still expired, clock restored
    }
}
