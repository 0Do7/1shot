import Foundation

/// Export image formats. Encoders live in OneShotDestinations (task 11.3);
/// this portable enum is the shared vocabulary for presets and settings.
public enum ImageFormat: String, Codable, CaseIterable, Sendable {
    case png, jpeg, webp, heic

    public var pathExtension: String {
        rawValue
    }

    public var utType: String {
        switch self {
        case .png: "public.png"
        case .jpeg: "public.jpeg"
        case .webp: "org.webmproject.webp"
        case .heic: "public.heic"
        }
    }
}

/// A named output preset: save location + format + density + filename template
/// (spec:output-destinations "Per-preset save-location rules").
public struct OutputPreset: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    /// Tilde-style path; expansion happens at the filesystem boundary.
    public var directoryPath: String
    public var format: ImageFormat
    /// Export Retina captures at 1x logical resolution.
    public var downscaleRetinaTo1x: Bool
    public var template: String

    public init(
        id: UUID = UUID(),
        name: String,
        directoryPath: String,
        format: ImageFormat = .png,
        downscaleRetinaTo1x: Bool = false,
        template: String = FilenameTemplate.defaultTemplate
    ) {
        self.id = id
        self.name = name
        self.directoryPath = directoryPath
        self.format = format
        self.downscaleRetinaTo1x = downscaleRetinaTo1x
        self.template = template
    }
}

/// Which preset serves which capture type, with a global default
/// (e.g. scrolling captures → "Docs" preset). Keys are capture-type names
/// (the typed enum lives in OneShotCapture, design D2).
public struct OutputRouting: Codable, Hashable, Sendable {
    public var defaultPresetID: UUID
    public var presetIDByCaptureType: [String: UUID]

    public init(defaultPresetID: UUID, presetIDByCaptureType: [String: UUID] = [:]) {
        self.defaultPresetID = defaultPresetID
        self.presetIDByCaptureType = presetIDByCaptureType
    }
}

/// Where a save will actually land, after availability rules ran.
public struct ResolvedSaveLocation: Hashable, Sendable {
    public var preset: OutputPreset
    public var directoryPath: String
    /// True when the preset's folder was unavailable and the default location
    /// was used instead — drives the spec's non-blocking notification.
    public var usedFallback: Bool
    /// The unavailable path, for the notification text.
    public var unavailablePath: String?
}

public enum OutputPresetResolver {
    /// Pick the preset for a capture type: explicit route, else default, else
    /// first preset (a settings file can't brick saving).
    public static func preset(
        forCaptureType captureType: String?,
        presets: [OutputPreset],
        routing: OutputRouting
    ) -> OutputPreset? {
        let routed = captureType
            .flatMap { routing.presetIDByCaptureType[$0] }
            .flatMap { routedID in presets.first { $0.id == routedID } }
        return routed
            ?? presets.first { $0.id == routing.defaultPresetID }
            ?? presets.first
    }

    /// Apply the availability rule (spec: missing destination folder falls
    /// back): unavailable preset folder → default preset's folder + flag.
    /// `directoryExists` is injected so the rule is testable without a filesystem.
    public static func resolveSaveLocation(
        for preset: OutputPreset,
        defaultPreset: OutputPreset,
        directoryExists: (String) -> Bool
    ) -> ResolvedSaveLocation {
        if directoryExists(preset.directoryPath) {
            return ResolvedSaveLocation(
                preset: preset,
                directoryPath: preset.directoryPath,
                usedFallback: false,
                unavailablePath: nil
            )
        }
        return ResolvedSaveLocation(
            preset: preset,
            directoryPath: defaultPreset.directoryPath,
            usedFallback: true,
            unavailablePath: preset.directoryPath
        )
    }
}
