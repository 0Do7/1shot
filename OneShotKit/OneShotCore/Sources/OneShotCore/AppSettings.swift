import Foundation

/// The typed settings schema (task 2.6, spec:utilities-settings). `AppSettings()`
/// IS the opinionated-defaults experience (PRD: a user who never opens Settings
/// gets the full intended product) — so "reset all" is assignment and a
/// setting's "default" label reads from a fresh instance.
///
/// Deliberately absent, by product decision, not omission: telemetry/analytics
/// flags (none exist), account state (none exists), license state (OneShotLicensing
/// owns it; never exported), destination secrets (Keychain only).
public struct AppSettings: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int

    // MARK: Capture

    public var includeCursor: Bool
    public var delayedCaptureSeconds: Int
    /// Window captures composite the true alpha drop shadow by default.
    public var windowCaptureShadow: Bool

    // MARK: Post-capture chip (design D7)

    public var chipEnabled: Bool
    public var chipKeyboardContractEnabled: Bool
    /// Seconds the Esc/⌘C/Enter contract stays armed after capture.
    public var chipKeyboardArmSeconds: Double
    public var chipTimeoutSeconds: Double

    // MARK: Output

    public var presets: [OutputPreset]
    public var routing: OutputRouting

    // MARK: Library

    public var libraryEnabled: Bool
    /// Watch standard screenshot folders for any-tool captures. Opt-in.
    public var autoImportEnabled: Bool
    /// Documented default for the transient history tray (spec: last N).
    public var historyTrayCount: Int
    /// Retention rules are off by default — we never delete without opt-in.
    public var retentionEnabled: Bool

    // MARK: App behavior

    public var launchAtLogin: Bool
    public var showMenuBarIcon: Bool
    /// URL-scheme automation API. Off by default (spec:automation).
    public var urlSchemeEnabled: Bool
    public var automaticUpdates: Bool

    // MARK: Hotkeys

    public var hotkeys: HotkeyBindings

    public init() {
        schemaVersion = Self.currentSchemaVersion
        includeCursor = false
        delayedCaptureSeconds = 5
        windowCaptureShadow = true
        chipEnabled = true
        chipKeyboardContractEnabled = true
        chipKeyboardArmSeconds = 8
        chipTimeoutSeconds = 8
        let desktop = OutputPreset(
            id: Self.defaultPresetID,
            name: "Desktop",
            directoryPath: "~/Desktop"
        )
        presets = [desktop]
        routing = OutputRouting(defaultPresetID: desktop.id)
        libraryEnabled = true
        autoImportEnabled = false
        historyTrayCount = 10
        retentionEnabled = false
        launchAtLogin = false
        showMenuBarIcon = true
        urlSchemeEnabled = false
        automaticUpdates = true
        hotkeys = .defaults
    }

    /// Fixed so defaults are value-equal across instances (reset/equality/tests).
    public static let defaultPresetID = UUID(uuidString: "00000000-0000-0000-0000-0000000D0001")!
}

public enum SettingsCodecError: Error, Equatable, Sendable {
    case schemaNewerThanSupported(found: Int, supported: Int)
    case malformed
}

/// Persistence + the export/import file (spec: "Settings persistence and
/// portability"). Export is the same encoding — the model contains no secrets
/// or license state by construction, so nothing needs stripping.
public enum SettingsCodec {
    public static func encode(_ settings: AppSettings) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try encoder.encode(settings)
    }

    /// Decode with update-resilience: stored JSON is overlaid onto the current
    /// defaults, so fields added in newer app versions pick up their defaults
    /// (spec scenario: settings survive update). Breaking changes bump
    /// `currentSchemaVersion` and add an explicit migration step here.
    public static func decode(_ data: Data) throws -> AppSettings {
        guard let stored = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SettingsCodecError.malformed
        }
        let version = stored["schemaVersion"] as? Int ?? 1
        guard version <= AppSettings.currentSchemaVersion else {
            throw SettingsCodecError.schemaNewerThanSupported(
                found: version,
                supported: AppSettings.currentSchemaVersion
            )
        }
        // Migration steps (1→2, …) transform `stored` here when they exist.

        let defaultsData = try encode(AppSettings())
        var merged = try JSONSerialization.jsonObject(with: defaultsData) as? [String: Any] ?? [:]
        for (key, value) in stored {
            merged[key] = value
        }
        merged["schemaVersion"] = AppSettings.currentSchemaVersion
        let mergedData = try JSONSerialization.data(withJSONObject: merged)
        return try JSONDecoder().decode(AppSettings.self, from: mergedData)
    }
}
