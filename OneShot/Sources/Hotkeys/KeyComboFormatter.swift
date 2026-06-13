import OneShotCore

/// Renders a `KeyCombo` for display in the hotkey editor, e.g. "⌘⇧4".
/// Modifier order follows the product's spoken convention (⌘⇧4, not HIG's ⇧⌘4).
enum KeyComboFormatter {
    static func string(for combo: KeyCombo) -> String {
        var result = ""
        if combo.modifiers.contains(.command) { result += "⌘" }
        if combo.modifiers.contains(.shift) { result += "⇧" }
        if combo.modifiers.contains(.option) { result += "⌥" }
        if combo.modifiers.contains(.control) { result += "⌃" }
        return result + keyName(for: combo.keyCode)
    }

    /// Carbon ANSI key code → display string; unknown codes → "key 0xNN".
    static func keyName(for keyCode: UInt16) -> String {
        keyNames[keyCode] ?? String(format: "key 0x%02X", keyCode)
    }

    /// Common Carbon ANSI virtual key codes (kVK_ANSI_* / kVK_F*).
    private static let keyNames: [UInt16: String] = [
        // Letters
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H",
        34: "I", 38: "J", 40: "K", 37: "L", 46: "M", 45: "N", 31: "O", 35: "P",
        12: "Q", 15: "R", 1: "S", 17: "T", 32: "U", 9: "V", 13: "W", 7: "X",
        16: "Y", 6: "Z",
        // Digits
        29: "0", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6",
        26: "7", 28: "8", 25: "9",
        // Named keys
        49: "Space", 36: "↩", 53: "⎋",
        // Function keys
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18",
        80: "F19", 90: "F20",
    ]
}
