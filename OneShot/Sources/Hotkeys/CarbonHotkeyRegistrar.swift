import Carbon.HIToolbox
import OneShotCore

/// Owns the raw Carbon tokens so cleanup can run when the @MainActor registrar
/// deallocates (Swift 6 forbids touching non-Sendable isolated state from a
/// nonisolated deinit). @unchecked Sendable invariant: only the registrar
/// mutates this, always on the main actor; this deinit therefore also runs on
/// the main thread (the registrar's last release happens there), which Carbon —
/// a main-thread API — requires. Removing the handler here, before the
/// registrar's memory is reused, guarantees the unretained userData pointer
/// Carbon holds can never dangle.
private final class CarbonTokenStore: @unchecked Sendable {
    var hotkeyRefs: [BindableAction: EventHotKeyRef] = [:]
    var eventHandler: EventHandlerRef?

    deinit {
        for ref in hotkeyRefs.values {
            UnregisterEventHotKey(ref)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}

/// Real registrar over Carbon `RegisterEventHotKey`/`UnregisterEventHotKey`
/// (design D6: no Accessibility permission; CGEventTap never required).
@MainActor
final class CarbonHotkeyRegistrar: HotkeyRegistrar {
    var onHotkey: ((BindableAction) -> Void)?

    /// `EventHotKeyID.signature` for hotkeys owned by this app ("1SHT").
    private static let signature: FourCharCode = 0x3153_4854

    private let tokens = CarbonTokenStore()

    func register(_ combo: KeyCombo, for action: BindableAction) throws(HotkeyRegistrationError) {
        installEventHandlerIfNeeded()
        unregister(action)

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(combo.keyCode),
            Self.carbonModifierFlags(for: combo.modifiers),
            EventHotKeyID(signature: Self.signature, id: Self.hotkeyID(for: action)),
            GetEventDispatcherTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            throw HotkeyRegistrationError(action: action, combo: combo, status: status)
        }
        tokens.hotkeyRefs[action] = ref
    }

    func unregister(_ action: BindableAction) {
        guard let ref = tokens.hotkeyRefs.removeValue(forKey: action) else { return }
        UnregisterEventHotKey(ref)
    }

    func unregisterAll() {
        for action in Array(tokens.hotkeyRefs.keys) {
            unregister(action)
        }
    }

    /// `KeyCombo.Modifiers` → Carbon modifier flags. Pure; unit-tested directly.
    nonisolated static func carbonModifierFlags(for modifiers: KeyCombo.Modifiers) -> UInt32 {
        var flags: UInt32 = 0
        if modifiers.contains(.command) { flags |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { flags |= UInt32(shiftKey) }
        if modifiers.contains(.option) { flags |= UInt32(optionKey) }
        if modifiers.contains(.control) { flags |= UInt32(controlKey) }
        return flags
    }

    /// Stable per-action hotkey ID: the action's position in `allCases`.
    private nonisolated static func hotkeyID(for action: BindableAction) -> UInt32 {
        UInt32(BindableAction.allCases.firstIndex(of: action) ?? 0)
    }

    private nonisolated static func action(forHotkeyID id: UInt32) -> BindableAction? {
        let all = BindableAction.allCases
        guard Int(id) < all.count else { return nil }
        return all[Int(id)]
    }

    private func installEventHandlerIfNeeded() {
        guard tokens.eventHandler == nil else { return }
        var pressed = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        // Carbon C callback → Swift bridge: self is passed unretained as
        // userData; deinit removes the handler before self deallocates, so the
        // pointer cannot outlive the instance.
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hotkeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyID
                )
                guard status == noErr else { return status }
                // Carbon dispatches hotkey events on the main thread's run
                // loop, so assuming MainActor isolation is sound here.
                return MainActor.assumeIsolated {
                    Unmanaged<CarbonHotkeyRegistrar>.fromOpaque(userData)
                        .takeUnretainedValue()
                        .handleFiredHotkey(hotkeyID)
                }
            },
            1,
            &pressed,
            Unmanaged.passUnretained(self).toOpaque(),
            &tokens.eventHandler
        )
    }

    private func handleFiredHotkey(_ id: EventHotKeyID) -> OSStatus {
        guard id.signature == Self.signature, let action = Self.action(forHotkeyID: id.id) else {
            return OSStatus(eventNotHandledErr)
        }
        onHotkey?(action)
        return noErr
    }
}
