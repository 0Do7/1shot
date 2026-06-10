import OneShotCore
import Testing
@testable import OneShot

/// In-memory registrar standing in for Carbon so rebinding logic is testable
/// headless (design D6).
@MainActor
private final class FakeRegistrar: HotkeyRegistrar {
    var onHotkey: ((BindableAction) -> Void)?

    private(set) var registered: [BindableAction: KeyCombo] = [:]
    private(set) var unregisterLog: [BindableAction] = []
    /// One-shot failure injected into the next `register` call.
    var nextRegistrationError: HotkeyRegistrationError?

    func register(_ combo: KeyCombo, for action: BindableAction) throws(HotkeyRegistrationError) {
        if let error = nextRegistrationError {
            nextRegistrationError = nil
            throw error
        }
        registered[action] = combo
    }

    func unregister(_ action: BindableAction) {
        unregisterLog.append(action)
        registered[action] = nil
    }

    func fire(_ action: BindableAction) {
        onHotkey?(action)
    }
}

@MainActor
struct HotkeyCenterTests {
    private let fake = FakeRegistrar()
    private let center: HotkeyCenter

    init() {
        center = HotkeyCenter(registrar: fake)
    }

    @Test func apply_registersAllDefaultBindings() {
        let failures = center.apply(.defaults)

        #expect(failures.isEmpty)
        #expect(fake.registered == HotkeyBindings.defaults.bindings)
        #expect(center.bindings == .defaults)
    }

    @Test func rebind_newShortcutFiresWithoutRestart_oldOneStops() throws {
        center.apply(.defaults)
        let oldCombo = try #require(center.bindings.combo(for: .captureArea)) // ⌘⇧4
        let newCombo = KeyCombo(keyCode: 0, modifiers: [.command, .option]) // ⌘⌥A

        try center.rebind(.captureArea, to: newCombo)

        // New shortcut is live with the OS; the old one is gone.
        #expect(fake.registered[.captureArea] == newCombo)
        #expect(!fake.registered.values.contains(oldCombo))
        #expect(fake.unregisterLog.contains(.captureArea))
        #expect(center.bindings.combo(for: .captureArea) == newCombo)

        // And it still routes to the app's handler.
        var fired: [BindableAction] = []
        center.onAction = { fired.append($0) }
        fake.fire(.captureArea)
        #expect(fired == [.captureArea])
    }

    @Test func rebind_internalConflictNamesOwnerAndChangesNothing() throws {
        center.apply(.defaults)
        let areaCombo = center.bindings.combo(for: .captureArea)
        let registeredBefore = fake.registered

        do {
            try center.rebind(.captureWindow, to: #require(areaCombo))
            Issue.record("expected HotkeyConflict")
        } catch let conflict as HotkeyConflict {
            #expect(conflict.conflictingAction == .captureArea)
        } catch {
            Issue.record("unexpected error: \(error)")
        }

        // Neither the table nor the OS registrations moved.
        #expect(center.bindings == .defaults)
        #expect(fake.registered == registeredBefore)
    }

    @Test func rebind_registrationFailureRollsBackSoBindingsReflectReality() throws {
        center.apply(.defaults)
        let oldCombo = try #require(center.bindings.combo(for: .captureArea))
        let refused = KeyCombo(keyCode: 0, modifiers: [.command, .option])
        fake.nextRegistrationError = HotkeyRegistrationError(
            action: .captureArea,
            combo: refused,
            status: -9878
        )

        #expect(throws: HotkeyRegistrationError.self) {
            try center.rebind(.captureArea, to: refused)
        }

        // Old binding restored in both the table and the registrar.
        #expect(center.bindings == .defaults)
        #expect(fake.registered[.captureArea] == oldCombo)
    }

    @Test func clear_unregistersTheAction() {
        center.apply(.defaults)

        center.clear(.captureArea)

        #expect(fake.registered[.captureArea] == nil)
        #expect(fake.unregisterLog.contains(.captureArea))
        #expect(center.bindings.combo(for: .captureArea) == nil)
    }

    @Test func apply_unregistersActionsRemovedFromTheNewTable() {
        center.apply(.defaults)
        var trimmed = HotkeyBindings.defaults
        trimmed.clear(.captureOCR)

        center.apply(trimmed)

        #expect(fake.registered[.captureOCR] == nil)
        #expect(center.bindings == trimmed)
    }

    @Test func apply_dropsCombosTheOSRefusesAndReportsThem() {
        let combo = KeyCombo(keyCode: 21, modifiers: [.command, .shift])
        var table = HotkeyBindings()
        try? table.set(combo, for: .captureArea)
        fake.nextRegistrationError = HotkeyRegistrationError(
            action: .captureArea,
            combo: combo,
            status: -9878
        )

        let failures = center.apply(table)

        #expect(failures[.captureArea]?.status == -9878)
        #expect(fake.registered[.captureArea] == nil)
        #expect(center.bindings.combo(for: .captureArea) == nil)
    }
}
