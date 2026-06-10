import OneShotCore
import Testing
@testable import OneShot

struct KeyComboFormatterTests {
    @Test func formatter_rendersCommandShift4() {
        let combo = KeyCombo(keyCode: 21, modifiers: [.command, .shift])
        #expect(KeyComboFormatter.string(for: combo) == "⌘⇧4")
    }

    @Test func formatter_rendersAllModifiersAndLetterKey() {
        let combo = KeyCombo(keyCode: 0, modifiers: [.command, .shift, .option, .control])
        #expect(KeyComboFormatter.string(for: combo) == "⌘⇧⌥⌃A")
    }

    @Test func formatter_rendersNamedAndFunctionKeys() {
        #expect(KeyComboFormatter.keyName(for: 49) == "Space")
        #expect(KeyComboFormatter.keyName(for: 36) == "↩")
        #expect(KeyComboFormatter.keyName(for: 53) == "⎋")
        #expect(KeyComboFormatter.keyName(for: 80) == "F19")
    }

    @Test func formatter_unknownKeyCodeFallsBackToHex() {
        let combo = KeyCombo(keyCode: 0x7F, modifiers: [.command])
        #expect(KeyComboFormatter.string(for: combo) == "⌘key 0x7F")
    }

    @Test func formatter_unmodifiedComboIsJustTheKey() {
        let combo = KeyCombo(keyCode: 96, modifiers: [])
        #expect(KeyComboFormatter.string(for: combo) == "F5")
    }
}
