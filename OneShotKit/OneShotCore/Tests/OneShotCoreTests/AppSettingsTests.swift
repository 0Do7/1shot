import Foundation
import Testing
@testable import OneShotCore

// Spec: Zero-configuration usability — the shipped defaults ARE the product.
@Test func defaults_matchTheOpinionatedProductDecisions() {
    let settings = AppSettings()
    #expect(settings.chipEnabled)
    #expect(settings.chipKeyboardContractEnabled)
    #expect(settings.chipKeyboardArmSeconds == 8) // design D7 documented default
    // Spec (post-capture-chip "Chip persistence and timeout"): persistent by
    // default — 0 means no auto-dismiss. Timeout is opt-in.
    #expect(settings.chipTimeoutSeconds == 0)
    #expect(settings.chipCorner == .bottomTrailing)
    #expect(settings.libraryEnabled)
    #expect(settings.windowCaptureShadow)
    #expect(settings.historyTrayCount == 10) // the documented last-N default
    // Trust posture: everything invasive or surprising is opt-in.
    #expect(!settings.autoImportEnabled)
    #expect(!settings.retentionEnabled)
    #expect(!settings.launchAtLogin)
    #expect(!settings.urlSchemeEnabled)
    #expect(!settings.includeCursor)
    // A usable save path exists out of the box.
    #expect(settings.presets.first?.directoryPath == "~/Desktop")
    #expect(settings.routing.defaultPresetID == settings.presets.first?.id)
}

// Spec: Reset to defaults — value semantics make reset assignment; defaults
// are value-equal across instances (fixed preset UUID).
@Test func resetAll_isAssignmentOfDefaults() throws {
    var settings = AppSettings()
    settings.includeCursor = true
    settings.historyTrayCount = 50
    try settings.hotkeys.set(KeyCombo(keyCode: 1, modifiers: [.command]), for: .historyTray)

    settings = AppSettings()
    #expect(settings == AppSettings())
}

@Test func settings_roundTripThroughCodec() throws {
    var settings = AppSettings()
    settings.delayedCaptureSeconds = 10
    settings.presets.append(OutputPreset(name: "Docs", directoryPath: "~/Docs", format: .webp))
    try settings.hotkeys.set(KeyCombo(keyCode: 35, modifiers: [.command, .shift]), for: .pinFromHistory)

    let decoded = try SettingsCodec.decode(SettingsCodec.encode(settings))
    #expect(decoded == settings)
}

// Spec: Settings survive update — JSON from an older build (missing fields
// added since) decodes with defaults filled in, customizations kept.
@Test func olderSettingsFile_decodesWithDefaultsForNewFields() throws {
    let oldJSON = """
    {"schemaVersion": 1, "includeCursor": true, "historyTrayCount": 25}
    """
    let decoded = try SettingsCodec.decode(Data(oldJSON.utf8))
    #expect(decoded.includeCursor) // customization kept
    #expect(decoded.historyTrayCount == 25)
    #expect(decoded.chipEnabled) // everything absent → default
    #expect(decoded.hotkeys == .defaults)
}

@Test func newerSettingsFile_refusedExplicitly() {
    let future = #"{"schemaVersion": 99}"#
    #expect(throws: SettingsCodecError.schemaNewerThanSupported(
        found: 99,
        supported: AppSettings.currentSchemaVersion
    )) {
        _ = try SettingsCodec.decode(Data(future.utf8))
    }
    #expect(throws: SettingsCodecError.malformed) {
        _ = try SettingsCodec.decode(Data("not json".utf8))
    }
}

// Spec: Export/import round trip excludes secrets and license state — which
// the model cannot contain by construction; the export file proves it.
@Test func exportFile_containsNoSecretsOrLicenseState() throws {
    var settings = AppSettings()
    settings.presets.append(OutputPreset(name: "S3 shots", directoryPath: "~/Uploads"))
    let exported = try SettingsCodec.encode(settings)
    let json = try #require(String(bytes: exported, encoding: .utf8)).lowercased()

    for forbidden in ["secret", "credential", "license", "accesskey", "token", "password"] {
        #expect(!json.contains(forbidden), "export leaked '\(forbidden)'")
    }
    // ...while the portable things ARE there.
    #expect(json.contains("hotkeys"))
    #expect(json.contains("presets"))
}

// MARK: Hotkeys

// Spec: Rebind an action — new combo wins, old combo no longer maps.
@Test func hotkeys_rebind_replacesOldBinding() throws {
    var hotkeys = HotkeyBindings.defaults
    let oldCombo = try #require(hotkeys.combo(for: .captureArea))
    let newCombo = KeyCombo(keyCode: 0, modifiers: [.command, .option])

    try hotkeys.set(newCombo, for: .captureArea)
    #expect(hotkeys.combo(for: .captureArea) == newCombo)
    #expect(hotkeys.owner(of: oldCombo) == nil) // old shortcut is dead
}

// Spec: Internal conflict refused — and the conflicting action is identified.
@Test func hotkeys_duplicateBinding_refusedNamingOwner() throws {
    var hotkeys = HotkeyBindings.defaults
    let areaCombo = try #require(hotkeys.combo(for: .captureArea))

    #expect(throws: HotkeyConflict(conflictingAction: .captureArea)) {
        try hotkeys.set(areaCombo, for: .captureOCR)
    }
    // Re-setting an action's own combo is not a conflict.
    try hotkeys.set(areaCombo, for: .captureArea)
}

@Test func hotkeys_clearUnbindsAction() {
    var hotkeys = HotkeyBindings.defaults
    hotkeys.clear(.captureArea)
    #expect(hotkeys.combo(for: .captureArea) == nil)
}

@Test func hotkeys_defaultTable_hasNoDuplicates() {
    let combos = HotkeyBindings.defaults.bindings.values
    #expect(Set(combos).count == combos.count)
    // Core capture actions ship bound; utility actions ship unbound (less surprise).
    for action in [BindableAction.captureArea, .captureWindow, .captureFullscreen, .captureOCR] {
        #expect(HotkeyBindings.defaults.combo(for: action) != nil, "\(action) should ship bound")
    }
}

@Test func hotkeys_roundTripThroughCodable() throws {
    let decoded = try JSONDecoder().decode(
        HotkeyBindings.self,
        from: JSONEncoder().encode(HotkeyBindings.defaults)
    )
    #expect(decoded == HotkeyBindings.defaults)
}
