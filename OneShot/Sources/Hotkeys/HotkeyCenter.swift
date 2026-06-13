import OneShotCore

/// Owns the live binding table and keeps OS registration in sync with it
/// (spec utilities-settings "Hotkey configuration"). Rebinds apply immediately —
/// no restart — and roll back on OS-level registration failure so `bindings`
/// always reflects what actually fires.
@MainActor
final class HotkeyCenter {
    /// The app sets this to receive triggered actions.
    var onAction: ((BindableAction) -> Void)?

    private(set) var bindings = HotkeyBindings()
    private let registrar: any HotkeyRegistrar

    init(registrar: any HotkeyRegistrar) {
        self.registrar = registrar
        registrar.onHotkey = { [weak self] action in
            self?.onAction?(action)
        }
    }

    /// Replaces the whole table (defaults at launch, settings import, …) by
    /// diffing against current registrations: register new/changed combos,
    /// unregister removed ones. Combos the OS refuses are dropped from the
    /// resulting table and reported; everything else still applies.
    @discardableResult
    func apply(_ newBindings: HotkeyBindings) -> [BindableAction: HotkeyRegistrationError] {
        var failures: [BindableAction: HotkeyRegistrationError] = [:]
        var applied = newBindings

        for (action, _) in bindings.bindings where newBindings.combo(for: action) == nil {
            registrar.unregister(action)
        }
        for (action, combo) in newBindings.bindings where bindings.combo(for: action) != combo {
            if bindings.combo(for: action) != nil {
                registrar.unregister(action)
            }
            do {
                try registrar.register(combo, for: action)
            } catch {
                failures[action] = error
                applied.clear(action)
            }
        }

        bindings = applied
        return failures
    }

    /// Rebinds immediately (spec scenario: the new shortcut works without an
    /// app restart and the old one stops). Throws `HotkeyConflict` naming the
    /// owning action when the combo is already bound internally (registrar
    /// untouched), or `HotkeyRegistrationError` when the OS refuses the combo
    /// (previous binding restored).
    func rebind(_ action: BindableAction, to combo: KeyCombo) throws {
        var updated = bindings
        try updated.set(combo, for: action)
        let previous = bindings.combo(for: action)
        guard previous != combo else { return }

        if previous != nil {
            registrar.unregister(action)
        }
        do {
            try registrar.register(combo, for: action)
            bindings = updated
        } catch {
            if let previous {
                do {
                    try registrar.register(previous, for: action)
                } catch {
                    // Could not restore the old registration either; drop the
                    // binding so the table still reflects what actually fires.
                    bindings.clear(action)
                }
            }
            throw error
        }
    }

    func clear(_ action: BindableAction) {
        guard bindings.combo(for: action) != nil else { return }
        registrar.unregister(action)
        bindings.clear(action)
    }
}
