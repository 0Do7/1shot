import Carbon.HIToolbox
import OneShotCore
import Testing
@testable import OneShot

struct CarbonModifierMappingTests {
    @Test func modifierMapping_mapsEachModifierToItsCarbonFlag() {
        #expect(CarbonHotkeyRegistrar.carbonModifierFlags(for: [.command]) == UInt32(cmdKey))
        #expect(CarbonHotkeyRegistrar.carbonModifierFlags(for: [.shift]) == UInt32(shiftKey))
        #expect(CarbonHotkeyRegistrar.carbonModifierFlags(for: [.option]) == UInt32(optionKey))
        #expect(CarbonHotkeyRegistrar.carbonModifierFlags(for: [.control]) == UInt32(controlKey))
    }

    @Test func modifierMapping_combinesFlagsAndEmptyIsZero() {
        let all: KeyCombo.Modifiers = [.command, .shift, .option, .control]
        let expected = UInt32(cmdKey | shiftKey | optionKey | controlKey)
        #expect(CarbonHotkeyRegistrar.carbonModifierFlags(for: all) == expected)
        #expect(CarbonHotkeyRegistrar.carbonModifierFlags(for: []) == 0)
    }
}

@MainActor
struct CarbonHotkeyRegistrarSmokeTests {
    /// Live smoke: an obscure combo (⌃⌥⇧F19) registers and unregisters without
    /// error; runs headless (RegisterEventHotKey needs no permissions).
    @Test func registrar_registersAndUnregistersObscureCombo() throws {
        let registrar = CarbonHotkeyRegistrar()
        let combo = KeyCombo(keyCode: 80, modifiers: [.control, .option, .shift])

        try registrar.register(combo, for: .captureArea)
        registrar.unregister(.captureArea)
        registrar.unregisterAll()
    }
}
