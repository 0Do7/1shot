import CoreGraphics
import Foundation

// Screen Recording permission model (task 3.6, S0 findings, spec:
// onboarding-permissions "Sequoia/Tahoe re-auth regime"). The OS gives no way
// to read the re-auth deadline (the approvals plist is TCC-protected), so
// lapses are detectable only reactively: re-auth is INFERRED when a capture
// fails with -3801 after this process already captured successfully.

public enum PermissionState: String, Codable, Hashable, CaseIterable, Sendable {
    case unknown
    case granted
    case denied
    /// Probable Sequoia/Tahoe periodic re-auth lapse. Exited only by a
    /// successful capture (proof of recovery) or an explicit preflight denial
    /// (plain revocation) — a positive preflight cannot clear it, because TCC
    /// can report access while the lapsed re-auth still fails captures.
    case reauthSuspected
}

public enum PermissionEvent: Hashable, Sendable {
    case preflightResult(Bool)
    case captureSucceeded
    /// A capture failed with `CaptureError.permissionDenied` (-3801).
    case captureFailedPermission
    /// The user opened the recovery / permission-health surface. State-neutral;
    /// the live monitor re-preflights in response.
    case userOpenedRecovery
}

/// Pure reducer state. Carries `hasCapturedThisProcess` because the
/// re-auth inference is defined relative to a prior in-process success —
/// `-3801` with no prior success is plain denial, not re-auth.
public struct PermissionMachine: Hashable, Sendable {
    public var state: PermissionState
    public var hasCapturedThisProcess: Bool

    public init(state: PermissionState = .unknown, hasCapturedThisProcess: Bool = false) {
        self.state = state
        self.hasCapturedThisProcess = hasCapturedThisProcess
    }

    public func applying(_ event: PermissionEvent) -> PermissionMachine {
        var next = self
        switch event {
        case .preflightResult(true):
            if state != .reauthSuspected {
                next.state = .granted
            }
        case .preflightResult(false):
            next.state = .denied
        case .captureSucceeded:
            next.state = .granted
            next.hasCapturedThisProcess = true
        case .captureFailedPermission:
            next.state = hasCapturedThisProcess ? .reauthSuspected : .denied
        case .userOpenedRecovery:
            break
        }
        return next
    }
}

/// Thin live wrapper around the pure reducer: feeds it
/// `CGPreflightScreenCaptureAccess()` and capture outcomes, and emits
/// recovery-flow hooks when the state transitions into `.denied` or
/// `.reauthSuspected`.
public actor PermissionMonitor {
    public typealias Preflight = @Sendable () -> Bool

    private let preflight: Preflight
    private var machine = PermissionMachine()
    private var continuations: [UUID: AsyncStream<PermissionState>.Continuation] = [:]

    /// `preflight` is injectable for tests; the default is the live TCC check.
    public init(preflight: @escaping Preflight = { CGPreflightScreenCaptureAccess() }) {
        self.preflight = preflight
    }

    public var state: PermissionState {
        machine.state
    }

    /// Emits the new state on every transition INTO `.denied` or
    /// `.reauthSuspected` — the hook the recovery UI subscribes to.
    public func recoveryNeeded() -> AsyncStream<PermissionState> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<PermissionState>.makeStream()
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeContinuation(id) }
        }
        return stream
    }

    @discardableResult
    public func refreshFromPreflight() -> PermissionState {
        apply([.preflightResult(preflight())])
    }

    @discardableResult
    public func recordCaptureSuccess() -> PermissionState {
        apply([.captureSucceeded])
    }

    /// Route a capture failure. Non-permission errors leave the state alone;
    /// -3801 applies the event and then re-preflights (S0: "re-preflight and
    /// route to recovery copy") so a plain revocation lands in `.denied`.
    @discardableResult
    public func recordCaptureFailure(_ error: CaptureError) -> PermissionState {
        guard error == .permissionDenied else { return machine.state }
        return apply([.captureFailedPermission, .preflightResult(preflight())])
    }

    /// Recovery surface opened: record the event and immediately re-check, so
    /// a grant made in System Settings is detected without user hunting.
    @discardableResult
    public func noteUserOpenedRecovery() -> PermissionState {
        apply([.userOpenedRecovery, .preflightResult(preflight())])
    }

    /// Folds events, emitting at most one recovery hook per call (the settled
    /// state, not intermediate hops).
    private func apply(_ events: [PermissionEvent]) -> PermissionState {
        let old = machine.state
        machine = events.reduce(machine) { $0.applying($1) }
        let new = machine.state
        if new != old, new == .denied || new == .reauthSuspected {
            for continuation in continuations.values {
                continuation.yield(new)
            }
        }
        return new
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }
}
