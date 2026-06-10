import Foundation

/// Every bindable action (spec:utilities-settings "Hotkey configuration").
/// The hotkey editor lists exactly these; registration is Carbon
/// RegisterEventHotKey in the app layer (design D6 — no Accessibility needed).
public enum BindableAction: String, Codable, CaseIterable, Sendable {
    case captureArea
    case captureWindow
    case captureFullscreen
    case captureRepeat
    case captureDelayed
    case captureFreeze
    case captureScrolling
    case captureOCR
    case pinFromHistory
    case historyTray
    case hideDesktop
    case hideShowAllPins
}

/// A keyboard shortcut: Carbon virtual key code + modifier set. Portable value;
/// the Carbon registration call lives in the app layer.
public struct KeyCombo: Codable, Hashable, Sendable {
    public struct Modifiers: OptionSet, Codable, Hashable, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let command = Modifiers(rawValue: 1 << 0)
        public static let shift = Modifiers(rawValue: 1 << 1)
        public static let option = Modifiers(rawValue: 1 << 2)
        public static let control = Modifiers(rawValue: 1 << 3)
    }

    public var keyCode: UInt16
    public var modifiers: Modifiers

    public init(keyCode: UInt16, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public struct HotkeyConflict: Error, Equatable, Sendable {
    /// The action that already owns the combo (spec: the editor identifies it).
    public let conflictingAction: BindableAction
}

/// The full binding table. Mutations enforce the no-internal-duplicates rule;
/// any action may be unbound (cleared).
public struct HotkeyBindings: Codable, Hashable, Sendable {
    public private(set) var bindings: [BindableAction: KeyCombo]

    public init(bindings: [BindableAction: KeyCombo] = [:]) {
        self.bindings = bindings
    }

    public func combo(for action: BindableAction) -> KeyCombo? {
        bindings[action]
    }

    /// Which action currently owns this combo, if any.
    public func owner(of combo: KeyCombo) -> BindableAction? {
        bindings.first { $0.value == combo }?.key
    }

    /// Bind `combo` to `action`, replacing the action's previous binding.
    /// Refuses (throws) if another action already uses the combo.
    public mutating func set(_ combo: KeyCombo, for action: BindableAction) throws {
        if let owner = owner(of: combo), owner != action {
            throw HotkeyConflict(conflictingAction: owner)
        }
        bindings[action] = combo
    }

    public mutating func clear(_ action: BindableAction) {
        bindings[action] = nil
    }

    /// Shipped defaults assume the onboarding hotkey-takeover wizard freed the
    /// system's ⌘⇧3/4/5 (task 12.2). Carbon ANSI key codes.
    public static let defaults: HotkeyBindings = {
        var table = HotkeyBindings()
        let cmdShift: KeyCombo.Modifiers = [.command, .shift]
        // kVK_ANSI_3=20, 4=21, 5=23, 6=22, 2=19, R=15, P=35, H=4, D=2, T=17
        try? table.set(KeyCombo(keyCode: 20, modifiers: cmdShift), for: .captureFullscreen)
        try? table.set(KeyCombo(keyCode: 21, modifiers: cmdShift), for: .captureArea)
        try? table.set(KeyCombo(keyCode: 23, modifiers: cmdShift), for: .captureWindow)
        try? table.set(KeyCombo(keyCode: 22, modifiers: cmdShift), for: .captureScrolling)
        try? table.set(KeyCombo(keyCode: 19, modifiers: cmdShift), for: .captureOCR)
        try? table.set(KeyCombo(keyCode: 15, modifiers: cmdShift), for: .captureRepeat)
        return table
    }()
}
