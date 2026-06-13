import Foundation
import os
import Testing
@testable import OneShotCapture

private typealias PreflightStub = (flag: OSAllocatedUnfairLock<Bool>, preflight: PermissionMonitor.Preflight)

/// Mutable preflight stub the tests flip mid-scenario.
private func stubPreflight(initially value: Bool) -> PreflightStub {
    let flag = OSAllocatedUnfairLock(initialState: value)
    return (flag, { flag.withLock { $0 } })
}

@Test func monitor_startsUnknownAndPreflightGrants() async {
    let (_, preflight) = stubPreflight(initially: true)
    let monitor = PermissionMonitor(preflight: preflight)
    #expect(await monitor.state == .unknown)
    #expect(await monitor.refreshFromPreflight() == .granted)
}

@Test func monitor_preflightDenied_emitsRecoveryHook() async {
    let (_, preflight) = stubPreflight(initially: false)
    let monitor = PermissionMonitor(preflight: preflight)
    let recovery = await monitor.recoveryNeeded()
    #expect(await monitor.refreshFromPreflight() == .denied)
    var iterator = recovery.makeAsyncIterator()
    #expect(await iterator.next() == .denied)
}

@Test func monitor_failureAfterSuccess_suspectsReauthAndEmitsOnce() async {
    let (_, preflight) = stubPreflight(initially: true)
    let monitor = PermissionMonitor(preflight: preflight)
    let recovery = await monitor.recoveryNeeded()
    await monitor.recordCaptureSuccess()
    // Preflight still says true (the re-auth lapse case): suspicion holds.
    #expect(await monitor.recordCaptureFailure(.permissionDenied) == .reauthSuspected)
    var iterator = recovery.makeAsyncIterator()
    #expect(await iterator.next() == .reauthSuspected)
}

@Test func monitor_failureWithoutPriorSuccess_isPlainDenied() async {
    let (flag, preflight) = stubPreflight(initially: true)
    let monitor = PermissionMonitor(preflight: preflight)
    await monitor.refreshFromPreflight()
    flag.withLock { $0 = false }
    #expect(await monitor.recordCaptureFailure(.permissionDenied) == .denied)
}

@Test func monitor_failureThenPreflightFalse_resolvesToDeniedNotReauth() async {
    // S0: after -3801 re-preflight; an explicit TCC denial means revocation,
    // not the re-auth lapse, even after a prior success.
    let (flag, preflight) = stubPreflight(initially: true)
    let monitor = PermissionMonitor(preflight: preflight)
    await monitor.recordCaptureSuccess()
    flag.withLock { $0 = false }
    #expect(await monitor.recordCaptureFailure(.permissionDenied) == .denied)
}

@Test func monitor_nonPermissionFailure_leavesStateUntouched() async {
    let (_, preflight) = stubPreflight(initially: true)
    let monitor = PermissionMonitor(preflight: preflight)
    await monitor.recordCaptureSuccess()
    #expect(await monitor.recordCaptureFailure(.captureFailed(domain: "test", code: 1)) == .granted)
}

@Test func monitor_recoveryOpened_rechecksAndDetectsGrant() async {
    let (flag, preflight) = stubPreflight(initially: false)
    let monitor = PermissionMonitor(preflight: preflight)
    await monitor.refreshFromPreflight()
    flag.withLock { $0 = true }
    // User fixed it in System Settings; opening recovery re-preflights.
    #expect(await monitor.noteUserOpenedRecovery() == .granted)
}

@Test func monitor_recoveryHook_silentWhileStateUnchanged() async {
    let (flag, preflight) = stubPreflight(initially: false)
    let monitor = PermissionMonitor(preflight: preflight)
    let recovery = await monitor.recoveryNeeded()
    await monitor.refreshFromPreflight()
    await monitor.refreshFromPreflight()
    await monitor.noteUserOpenedRecovery()
    var iterator = recovery.makeAsyncIterator()
    // Exactly one emission for the single unknown→denied transition; prove it
    // by pushing a different transition and seeing it next, not a duplicate.
    #expect(await iterator.next() == .denied)
    flag.withLock { $0 = true }
    await monitor.recordCaptureSuccess()
    await monitor.recordCaptureFailure(.permissionDenied)
    #expect(await iterator.next() == .reauthSuspected)
}
