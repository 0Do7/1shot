import Foundation

/// The single honest, typed answer to "what can the user do right now?" (design
/// D10, spec E15). There is no silent degradation: every state names exactly
/// what is true. Capture availability is derived from the state, never guessed.
///
/// `Library, viewing, search, annotation editing, and export of existing data`
/// are available in EVERY state — the app never holds data hostage — so they are
/// intentionally not gated by this enum.
public enum LicenseState: Equatable, Sendable {
    /// Inside the 14-day free trial. `daysRemaining` is for on-demand display
    /// only (menu bar / about) — never a pop-up trigger.
    case trial(daysRemaining: Int)

    /// Trial elapsed; inside the 24-hour capture grace. Capture still works; the
    /// app informs the user ONCE (spec: "Dignified trial expiry — 24-hour grace").
    case trialGrace(hoursRemaining: Int)

    /// Trial + grace elapsed with no license. Capture is disabled; Library and
    /// export keep working forever (spec: "Post-grace state", "Data never hostage").
    case expired

    /// A verified, currently-valid license. The normal paid state.
    case licensed

    /// Licensed, but revalidation has been impossible past the 14-day offline
    /// grace (spec: "Grace exceeded then restored"). Shows ONE notice; recovers
    /// to `.licensed` automatically on the next successful validation. Capture
    /// stays available — the documented degradation is no worse than unlicensed,
    /// and a previously-valid license is given the benefit of the doubt.
    case licensedOfflineGraceExceeded

    /// Whether capture entry points are enabled in this state. Library/export are
    /// always available regardless and are not represented here.
    public var captureEnabled: Bool {
        switch self {
        case .trial, .trialGrace, .licensed, .licensedOfflineGraceExceeded:
            true
        case .expired:
            false
        }
    }

    /// Whether the user has a paid license (in either licensed sub-state).
    public var isLicensed: Bool {
        switch self {
        case .licensed, .licensedOfflineGraceExceeded: true
        case .trial, .trialGrace, .expired: false
        }
    }
}
