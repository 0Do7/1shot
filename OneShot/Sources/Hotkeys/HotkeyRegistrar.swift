import OneShotCore

/// OS-level registration failed — typically the combo is already claimed by the
/// system or another app (`RegisterEventHotKey` returned a non-zero OSStatus).
struct HotkeyRegistrationError: Error, Equatable {
    let action: BindableAction
    let combo: KeyCombo
    /// The OSStatus returned by the failing registration call.
    let status: Int32
}

/// Registers key combos with the OS and reports fired hotkeys (design D6:
/// Carbon RegisterEventHotKey, no Accessibility permission). Abstracted so
/// `HotkeyCenter`'s rebinding logic is testable with a fake.
@MainActor
protocol HotkeyRegistrar: AnyObject {
    /// Called when a registered hotkey fires.
    var onHotkey: ((BindableAction) -> Void)? { get set }

    /// Registers `combo` for `action`, replacing any previous registration the
    /// action held. The registrar keeps the OS token internally, keyed by action.
    func register(_ combo: KeyCombo, for action: BindableAction) throws(HotkeyRegistrationError)

    /// Removes the action's registration; no-op when the action has none.
    func unregister(_ action: BindableAction)
}
