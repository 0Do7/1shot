import AppKit
import Foundation
import UserNotifications

/// Receives `oneshot://` Apple Events, runs the request through the shared
/// dispatcher, and fires x-callback-url returns (§13.5). The parse → gate →
/// dispatch → callback PIPELINE is the only thing here; the parsing and the gate
/// are the pure units that carry the test coverage, so this thin AppKit shell is
/// runner-only (like every interactive surface in the app).
///
/// Disabled-by-default contract (spec: "Scheme call while disabled"): when the
/// URL API is off, the gate rejects with `.urlSchemeDisabled` and we show the ONE
/// non-actionable notice telling the user where to enable it — no action, no nag.
@MainActor
final class AutomationURLHandler: NSObject {
    private let dispatcher: AutomationDispatcher
    /// One-shot guard so a flood of disabled scheme calls yields a SINGLE notice,
    /// not a barrage (spec: "a single non-actionable notice").
    private var disabledNoticeShown = false

    init(dispatcher: AutomationDispatcher) {
        self.dispatcher = dispatcher
        super.init()
    }

    /// Register for the Get-URL Apple Event. `LSUIElement` apps still receive
    /// these once the scheme is declared in Info.plist (`CFBundleURLTypes`).
    func register() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent _: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else { return }
        handle(url)
    }

    /// Parse + dispatch a single scheme URL. Public-ish entry point so a future
    /// runner-only XCUITest can drive it; pure logic stays in parser/gate.
    func handle(_ url: URL) {
        let request: ParsedAutomationRequest
        do {
            request = try AutomationURLParser.parse(url)
        } catch {
            // Malformed/unknown: no action, no crash. If the caller attached an
            // x-error callback we still want to honor it, but a malformed URL we
            // couldn't parse also couldn't carry a callback, so just bail safely.
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await dispatcher.run(
                    request.action,
                    source: .urlScheme,
                    forceConfirm: request.forceConfirm
                )
                if let success = AutomationCallbackBuilder.successURL(for: result, callbacks: request.callbacks) {
                    NSWorkspace.shared.open(success)
                }
            } catch let error as AutomationError {
                handleFailure(error, callbacks: request.callbacks)
            } catch {
                handleFailure(.malformedRequest(String(describing: error)), callbacks: request.callbacks)
            }
        }
    }

    private func handleFailure(_ error: AutomationError, callbacks: AutomationCallbacks) {
        if case .urlSchemeDisabled = error {
            showDisabledNoticeOnce()
        }
        if let errorURL = AutomationCallbackBuilder.errorURL(for: error, callbacks: callbacks) {
            NSWorkspace.shared.open(errorURL)
        }
    }

    /// The single non-actionable notice for a disabled-API call. Best-effort: if
    /// notifications aren't authorized it silently no-ops (never nags).
    private func showDisabledNoticeOnce() {
        guard !disabledNoticeShown else { return }
        disabledNoticeShown = true
        let content = UNMutableNotificationContent()
        content.title = "1shot automation is off"
        content.body = "Another app tried to control 1shot. Enable the URL API "
            + "in 1shot Settings › Automation to allow it."
        let request = UNNotificationRequest(identifier: "oneshot.automation.disabled", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
