import Foundation

/// Every honest failure the automation surface can return (spec:automation). The
/// messages are the *contract*: AppIntents surface `errorDescription` to the
/// Shortcuts UI, and the URL scheme passes `code`/`errorDescription` to an
/// x-error callback (spec: "the caller receives a descriptive error callback").
///
/// There is deliberately no `.unknown` silent path — an unparseable or unknown
/// request maps to `.malformedRequest`, never a no-op that looks like success.
enum AutomationError: Error, Equatable {
    /// A capture action ran while the trial has fully expired and no license is
    /// present (spec: "Expired trial blocks automated capture honestly" — the
    /// intent fails with an error stating capture requires a license, NOT a
    /// silent no-op). Library search/export keep working, so they never hit this.
    case captureRequiresLicense

    /// A capture/OCR-region action ran without Screen Recording permission
    /// (spec: "Intent without required permission" — fail with an explicit error
    /// naming the missing permission; no blank image is returned).
    case screenRecordingPermissionMissing

    /// The URL-scheme API is OFF (the default). Incoming scheme requests are
    /// ignored except for the single non-actionable notice (spec: "Scheme call
    /// while disabled"). Carried so the caller's x-error callback, if any, is honest.
    case urlSchemeDisabled

    /// The request could not be parsed: unknown action, missing/invalid parameter,
    /// or a malformed URL (spec: "Malformed request fails safely" — no action, no
    /// crash, descriptive error callback).
    case malformedRequest(String)

    /// A referenced file (OCR input / pin source) does not exist or is unreadable.
    case fileNotReadable(String)

    /// The user declined the confirmation prompt for a side-effecting action.
    case cancelledByUser

    /// A stable token for x-callback-url `errorCode`, so scriptable callers can
    /// branch on the failure without string-matching the human message.
    var code: String {
        switch self {
        case .captureRequiresLicense: "capture-requires-license"
        case .screenRecordingPermissionMissing: "screen-recording-permission-missing"
        case .urlSchemeDisabled: "url-scheme-disabled"
        case .malformedRequest: "malformed-request"
        case .fileNotReadable: "file-not-readable"
        case .cancelledByUser: "cancelled"
        }
    }

    /// The user-facing message. For licensing this is the *contracted* string the
    /// spec scenario asserts ("capture requires a license").
    var message: String {
        switch self {
        case .captureRequiresLicense:
            "Capture requires a license. Your 1shot trial has ended — purchase a license to capture again. "
                + "(Your Library and saved images remain fully available.)"
        case .screenRecordingPermissionMissing:
            "1shot needs Screen Recording permission to capture. Grant it in "
                + "System Settings › Privacy & Security › Screen Recording, then try again."
        case .urlSchemeDisabled:
            "The 1shot URL API is turned off. Enable it in 1shot Settings › Automation "
                + "before other apps can trigger it."
        case let .malformedRequest(detail):
            "That 1shot automation request couldn't be understood: \(detail)"
        case let .fileNotReadable(path):
            "1shot couldn't read the file at \(path)."
        case .cancelledByUser:
            "The 1shot automation action was cancelled."
        }
    }
}

extension AutomationError: LocalizedError {
    var errorDescription: String? {
        message
    }
}
