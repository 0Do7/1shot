import AppKit
import CoreGraphics

/// Delivers the chip's three global contract keys (Esc/⌘C/Enter) to the model
/// while a chip is armed, swallowing only those keys. Abstracted so the presenter
/// can be exercised with a fake and so the real (CGEventTap) mechanism stays in
/// one place.
@MainActor
protocol ChipContractMonitoring: AnyObject {
    /// Start intercepting. `onKey` runs on the main actor for each contract key;
    /// returning `true` swallows that key from the frontmost app.
    func start(onKey: @escaping @MainActor (ChipKey) -> Bool)
    func stop()
}

/// CGEventTap implementation. The tap is created **only while a chip is armed**
/// and torn down when the arming window ends, so the app is not a standing
/// keyboard observer. If the tap can't be created (the app isn't trusted for
/// Input Monitoring), the contract silently degrades to mouse-only — no nag, no
/// proactive permission prompt (honest-failure).
///
/// Design note: this is the one place the app uses a `CGEventTap`. Design D6
/// scopes its "no CGEventTap" rule to *core capture*; the optional, transient,
/// disableable chip contract is not core capture, and the spec's "MUST swallow
/// only these contracted keys" is achievable no other way. Logged in
/// `docs/spec-conflicts.md`.
@MainActor
final class CGEventTapContractMonitor: ChipContractMonitoring {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var onKey: (@MainActor (ChipKey) -> Bool)?

    func start(onKey: @escaping @MainActor (ChipKey) -> Bool) {
        self.onKey = onKey
        guard tap == nil else { return }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: Self.callback,
            userInfo: refcon
        ) else {
            self.onKey = nil // untrusted/unavailable → mouse-only
            return
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        runLoopSource = source
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
        onKey = nil
    }

    /// Bridge from the C callback onto the main actor. Takes only Sendable
    /// primitives (never the non-Sendable `CGEvent`), so the actor hop is clean.
    nonisolated func dispatchKey(keyCode: UInt16, hasCommand: Bool, characters: String?) -> Bool {
        MainActor.assumeIsolated {
            guard let onKey,
                  let key = ChipKey.from(keyCode: keyCode, hasCommand: hasCommand, characters: characters)
            else { return false }
            return onKey(key)
        }
    }

    nonisolated func dispatchReenable() {
        MainActor.assumeIsolated {
            guard let tap else { return }
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    nonisolated static func characters(from event: CGEvent) -> String? {
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
        guard length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }

    /// C trampoline. Runs on the main run loop; the non-Sendable `CGEvent` stays
    /// in this nonisolated scope — only Sendable values cross to the main actor.
    private static let callback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let monitor = Unmanaged<CGEventTapContractMonitor>.fromOpaque(refcon).takeUnretainedValue()
        switch type {
        case .keyDown:
            let keyCode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
            let hasCommand = event.flags.contains(.maskCommand)
            if monitor.dispatchKey(keyCode: keyCode, hasCommand: hasCommand, characters: characters(from: event)) {
                return nil // swallow the contracted key
            }
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            monitor.dispatchReenable()
        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }
}
