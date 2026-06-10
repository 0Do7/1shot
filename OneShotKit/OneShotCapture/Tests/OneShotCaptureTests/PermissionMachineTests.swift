import Testing
@testable import OneShotCapture

// Exhaustive reducer coverage: every (state × hasCapturedThisProcess) machine
// against every event — 8 machines × 5 events = all 40 cells.

private let allMachines: [PermissionMachine] = PermissionState.allCases.flatMap { state in
    [false, true].map { PermissionMachine(state: state, hasCapturedThisProcess: $0) }
}

@Test func reducer_preflightTrue_grantsFromEveryStateExceptReauthSuspected() {
    for machine in allMachines {
        let next = machine.applying(.preflightResult(true))
        if machine.state == .reauthSuspected {
            // TCC can report access while the lapsed re-auth still fails
            // captures — only a successful capture clears the suspicion.
            #expect(next.state == .reauthSuspected)
        } else {
            #expect(next.state == .granted)
        }
        #expect(next.hasCapturedThisProcess == machine.hasCapturedThisProcess)
    }
}

@Test func reducer_preflightFalse_deniesFromEveryState() {
    for machine in allMachines {
        let next = machine.applying(.preflightResult(false))
        #expect(next.state == .denied)
        #expect(next.hasCapturedThisProcess == machine.hasCapturedThisProcess)
    }
}

@Test func reducer_captureSucceeded_grantsAndRecordsSuccessFromEveryState() {
    for machine in allMachines {
        let next = machine.applying(.captureSucceeded)
        #expect(next.state == .granted)
        #expect(next.hasCapturedThisProcess)
    }
}

@Test func reducer_captureFailedPermission_withoutPriorSuccess_isPlainDenial() {
    for state in PermissionState.allCases {
        let next = PermissionMachine(state: state, hasCapturedThisProcess: false)
            .applying(.captureFailedPermission)
        #expect(next.state == .denied)
        #expect(!next.hasCapturedThisProcess)
    }
}

@Test func reducer_captureFailedPermission_afterPriorSuccess_suspectsReauth() {
    for state in PermissionState.allCases {
        let next = PermissionMachine(state: state, hasCapturedThisProcess: true)
            .applying(.captureFailedPermission)
        #expect(next.state == .reauthSuspected)
        #expect(next.hasCapturedThisProcess)
    }
}

@Test func reducer_userOpenedRecovery_isStateNeutralFromEveryState() {
    for machine in allMachines {
        #expect(machine.applying(.userOpenedRecovery) == machine)
    }
}

@Test func reducer_initialState_isUnknownWithNoPriorSuccess() {
    let machine = PermissionMachine()
    #expect(machine.state == .unknown)
    #expect(!machine.hasCapturedThisProcess)
}
