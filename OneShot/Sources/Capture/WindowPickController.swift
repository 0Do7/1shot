import AppKit
import OneShotCapture
import OneShotCore

/// Interactive window picking (spec:capture-engine "Window highlighting during
/// pick"): drives the 3.3 `WindowPickerModel` + `WindowHighlightOverlay` from a
/// per-display, key, event-capturing window. Returns the chosen window, or `nil`
/// if the user pressed Esc.
@MainActor
final class WindowPickController {
    private var windows: [PickEventWindow] = []
    private let highlight = WindowHighlightOverlay()
    private var model: WindowPickerModel?
    private var continuation: CheckedContinuation<WindowDescriptor?, Never>?

    func begin() async throws -> WindowDescriptor? {
        let snapshot = try await ShareableContentService.snapshot()
        let model = WindowPickerModel(candidates: ShareableContentService.capturableWindows(from: snapshot))
        self.model = model
        model.onHighlightChange = { [weak self] window in
            guard let self else { return }
            if let window { highlight.show(over: window.frame) } else { highlight.hide() }
        }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            present()
        }
    }

    private func present() {
        windows = NSScreen.screens.map { screen in
            PickEventWindow(
                screen: screen,
                onMove: { [weak self] point in self?.model?.updateCursor(point) },
                onClick: { [weak self] in self?.finish(self?.model?.highlighted) },
                onCancel: { [weak self] in self?.finish(nil) }
            )
        }
        for window in windows {
            window.orderFrontRegardless()
        }
        windows.first?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func finish(_ window: WindowDescriptor?) {
        highlight.hide()
        for overlay in windows {
            overlay.orderOut(nil)
        }
        windows = []
        model = nil
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(returning: window)
    }
}

/// Transparent, key, full-screen event sink for one display. Sits below the
/// click-through highlight overlay, so cursor moves and the pick click land
/// here while the highlight draws on top.
@MainActor
final class PickEventWindow: NSPanel {
    init(
        screen: NSScreen,
        onMove: @escaping (LogicalPoint) -> Void,
        onClick: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        let view = PickEventView(onMove: onMove, onClick: onClick, onCancel: onCancel)
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        setFrame(screen.frame, display: true)
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isReleasedWhenClosed = false
        animationBehavior = .none
        contentView = view
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}

private final class PickEventView: NSView {
    private let onMove: (LogicalPoint) -> Void
    private let onClick: () -> Void
    private let onCancel: () -> Void
    private var trackingArea: NSTrackingArea?

    init(
        onMove: @escaping (LogicalPoint) -> Void,
        onClick: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onMove = onMove
        self.onClick = onClick
        self.onCancel = onCancel
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("not used")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func cursorUpdate(with _: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseMoved(with event: NSEvent) {
        onMove(logical(from: event))
    }

    override func mouseDown(with event: NSEvent) {
        onMove(logical(from: event))
    }

    override func mouseUp(with _: NSEvent) {
        onClick()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel() } else { super.keyDown(with: event) }
    }

    private func logical(from event: NSEvent) -> LogicalPoint {
        guard let window else { return LogicalPoint(x: event.locationInWindow.x, y: event.locationInWindow.y) }
        let screenPoint = window.convertPoint(toScreen: event.locationInWindow)
        let primaryHeight = Double(NSScreen.screens.first?.frame.height ?? 0)
        return WindowPickerGeometry.logicalPoint(
            forAppKit: CGPoint(x: screenPoint.x, y: screenPoint.y),
            primaryScreenHeight: primaryHeight
        )
    }
}
