import Foundation
import Testing
@testable import OneShotLicensing

// 14.1 — Fourteen-day offline grace. The clock is injected so we can place the
// instant at exactly 13 days, 14 days, and past 14 days since last validation.

struct OfflineGraceTests {
    /// Build a manager already licensed at `day0`, with a server that REFUSES
    /// further revalidation (simulating no network), so only the offline grace
    /// governs subsequent state.
    private func licensedThenOffline() async throws -> (LicenseManager, FixedClock) {
        let (signer, verifier) = Fixtures.keyPair()
        let server = Fixtures.server(signer: signer)
        let clock = FixedClock(Fixtures.day0)
        let mgr = Fixtures.manager(server: server, verifier: verifier, clock: clock)
        _ = try await mgr.activate(licenseKey: Fixtures.validKey)
        // From here, advancing the clock with no successful revalidation keeps the
        // receipt's lastValidatedAt fixed at day0.
        return (mgr, clock)
    }

    /// Spec scenario: Two weeks offline — offline for 13 days, all features work
    /// with no warnings (state stays fully `.licensed`).
    @Test func twoWeeksOffline() async throws {
        let (mgr, clock) = try await licensedThenOffline()
        clock.advance(by: 13 * LicensingDuration.day)
        #expect(await mgr.currentState() == .licensed)
    }

    /// Exactly at the 14-day boundary the license is still fully valid ("at least
    /// 14 days ... before showing any warning").
    @Test func atFourteenDayBoundaryStillLicensed() async throws {
        let (mgr, clock) = try await licensedThenOffline()
        clock.advance(by: 14 * LicensingDuration.day)
        #expect(await mgr.currentState() == .licensed)
    }

    /// Spec scenario: Grace exceeded then restored — past 14 days the app shows the
    /// lapse state; the first successful revalidation restores `.licensed`.
    @Test func graceExceededThenRestored() async throws {
        let (signer, verifier) = Fixtures.keyPair()
        let server = Fixtures.server(signer: signer)
        let clock = FixedClock(Fixtures.day0)
        let mgr = Fixtures.manager(server: server, verifier: verifier, clock: clock)
        _ = try await mgr.activate(licenseKey: Fixtures.validKey)

        // 14 days + 1 hour with no contact → grace exceeded.
        clock.advance(by: 14 * LicensingDuration.day + 3600)
        #expect(await mgr.currentState() == .licensedOfflineGraceExceeded)

        // Connectivity returns; revalidation refreshes lastValidatedAt to "now".
        let restored = await mgr.revalidate()
        #expect(restored == .licensed)
        // And it stays licensed at the same instant (clock unchanged).
        #expect(await mgr.currentState() == .licensed)
    }

    /// Even with the offline grace exceeded, capture remains enabled — the
    /// documented degradation is "no worse than unlicensed-capture rules" and a
    /// previously-valid license is trusted.
    @Test func graceExceededStillAllowsCapture() async throws {
        let (mgr, clock) = try await licensedThenOffline()
        clock.advance(by: 20 * LicensingDuration.day)
        let state = await mgr.currentState()
        #expect(state == .licensedOfflineGraceExceeded)
        #expect(state.captureEnabled)
        #expect(state.isLicensed)
    }
}
