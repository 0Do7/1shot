import AppKit
import CoreGraphics
import OneShotCapture
import OneShotCore

/// Outcome of an area-selection session.
enum AreaSelectionResult: Equatable {
    case captured(CapturedFrame)
    case cancelled

    static func == (lhs: AreaSelectionResult, rhs: AreaSelectionResult) -> Bool {
        switch (lhs, rhs) {
        case (.cancelled, .cancelled): true
        case let (.captured(left), .captured(right)):
            left.displayID == right.displayID && left.pixels == right.pixels && left.image === right.image
        default: false
        }
    }
}

/// Orchestrates area-selection capture (task 3.2): it grabs a per-display
/// backdrop snapshot at invocation, presents one borderless overlay window per
/// display, drives a shared `AreaSelectionModel` from the views, and on confirm
/// crops the selected region out of the backdrop snapshot.
///
/// Why crop the snapshot instead of re-capturing the live screen on confirm:
/// (1) it is exactly WYSIWYG with the dimmed backdrop the user selected over,
/// (2) it removes the one-frame race where the dimming overlay leaks into the
/// shot, and (3) the snapshot is needed anyway for the pixel-accurate magnifier.
/// The screen is therefore visually frozen for the brief selection lifetime;
/// the explicit, persistent freeze-screen mode (task 3.4) is the same mechanism
/// surfaced deliberately. The crop is at the source display's native pixel
/// density, satisfying the mixed-DPI requirement.
@MainActor
final class AreaSelectionController {
    private let still: StillCaptureService
    private let content: () async throws -> DisplayLayout

    private var model: AreaSelectionModel?
    private var windows: [AreaSelectionWindow] = []
    private var snapshots: [UInt32: CGImage] = [:]
    private var continuation: CheckedContinuation<AreaSelectionResult, Never>?

    init(still: StillCaptureService = StillCaptureService()) {
        self.still = still
        content = { try await ShareableContentService.snapshot().layout }
    }

    /// Begin an interactive area selection. Returns when the user confirms
    /// (`.captured`) or cancels (`.cancelled`). Throws `CaptureError` if the
    /// backdrop snapshot cannot be taken (e.g. Screen Recording denied) — the
    /// caller drives recovery; this controller never produces a black image.
    func begin(options: CaptureOptions = CaptureOptions()) async throws -> AreaSelectionResult {
        let layout = try await content()
        var images: [UInt32: CGImage] = [:]
        for display in layout.displays {
            images[display.id] = try await still.captureFullDisplay(display, options: options).image
        }
        snapshots = images

        let model = AreaSelectionModel(layout: layout)
        self.model = model

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            presentOverlays(layout: layout)
        }
    }

    func snapshot(for displayID: UInt32) -> CGImage? {
        snapshots[displayID]
    }

    // MARK: View callbacks

    func pointerDown(at point: LogicalPoint) {
        mutate { $0.pointerDown(at: point) }
    }

    func pointerDragged(to point: LogicalPoint) {
        mutate { $0.pointerDragged(to: point) }
    }

    func pointerUp() {
        mutate { $0.pointerUp() }
    }

    func nudge(_ direction: NudgeDirection, resizing: Bool, step: Double) {
        mutate { $0.nudge(direction, resizing: resizing, step: step) }
    }

    func confirm() {
        guard let model, let target = model.target(),
              let image = snapshots[target.display.id],
              let frame = Self.croppedFrame(from: image, display: target.display, pixels: target.pixels)
        else {
            finish(.cancelled)
            return
        }
        finish(.captured(frame))
    }

    func cancel() {
        finish(.cancelled)
    }

    /// Crop the confirmed region out of the on-open backdrop snapshot. This is
    /// what makes freeze-screen correct (spec: the selected region is extracted
    /// from the frozen image, never the live screen at confirm time) — the only
    /// input is the snapshot, so the output can only be the frozen pixels.
    /// Native density is preserved (the snapshot is already at native pixels).
    nonisolated static func croppedFrame(
        from snapshot: CGImage,
        display: DisplayDescriptor,
        pixels: PixelRect
    ) -> CapturedFrame? {
        let rect = CGRect(x: pixels.x, y: pixels.y, width: pixels.width, height: pixels.height)
        guard let cropped = snapshot.cropping(to: rect) else { return nil }
        return CapturedFrame(
            type: .image,
            image: cropped,
            displayID: display.id,
            pixels: pixels,
            scale: display.scale
        )
    }

    // MARK: Internals

    private func mutate(_ change: (AreaSelectionModel) -> Void) {
        guard let model else { return }
        change(model)
        for window in windows {
            window.selectionView.needsDisplay = true
        }
    }

    private func presentOverlays(layout: DisplayLayout) {
        guard let model else { return }
        windows = NSScreen.screens.compactMap { screen in
            guard let displayID = screen.oneShotDisplayID,
                  layout.display(withID: displayID) != nil
            else { return nil }
            return AreaSelectionWindow(screen: screen, displayID: displayID, model: model, controller: self)
        }
        for window in windows {
            window.orderFrontRegardless()
        }
        windows.first?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func finish(_ result: AreaSelectionResult) {
        for window in windows {
            window.orderOut(nil)
        }
        windows = []
        model = nil
        snapshots = [:]
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(returning: result)
    }
}

extension NSScreen {
    /// CGDirectDisplayID for this screen (the key `DisplayDescriptor.id` uses).
    var oneShotDisplayID: UInt32? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
