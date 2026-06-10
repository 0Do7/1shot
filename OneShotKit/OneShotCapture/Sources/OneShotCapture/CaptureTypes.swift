import Foundation

/// The kind of media a capture produces (spec:capture-engine "Capture type
/// extensibility", design D5).
///
/// `.video` is a RESERVED v2 hook and presently inert: it exists so every
/// pipeline interface (capture result, chip input, library record) is typed
/// against this enum today, letting recording land in v2 with no change to
/// existing still-image contracts. Nothing in the MVP constructs `.video`.
public enum CaptureType: String, Codable, Hashable, CaseIterable, Sendable {
    case image
    case video
}

/// The invocation modes a capture can start from (spec:capture-engine
/// "Capture modes" + scrolling). Raw values are STABLE routing keys: they are
/// the strings consumed by OneShotCore's `OutputRouting.presetIDByCaptureType`
/// and `TemplateContext.captureType` — renaming a case's raw value breaks
/// users' saved routing and filename templates.
public enum CaptureMode: String, Codable, Hashable, CaseIterable, Sendable {
    case area
    case window
    case fullscreen
    case repeatArea
    case delayed
    case freezeScreen
    case scrolling
}
