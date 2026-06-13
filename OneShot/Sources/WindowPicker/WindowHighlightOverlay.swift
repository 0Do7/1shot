import AppKit
import OneShotCore

/// Visual highlight over the window-pick candidate (spec scenario "Window
/// highlighting during pick"): one borderless, non-activating, click-through
/// panel per display, drawing a rounded border + tint over the candidate's
/// frame. Driven by `WindowPickerModel` via show/move/hide.
///
/// Event routing: this overlay installs NO event monitors and never becomes
/// key — Esc-to-cancel is owned by the capture-mode coordinator (task 3.4),
/// which calls `hide()` and may observe teardown through `onDismiss`.
@MainActor
final class WindowHighlightOverlay {
    /// Hook for the coordinator: fired whenever the overlay hides.
    var onDismiss: (() -> Void)?

    private var panels: [NSPanel] = []

    /// Show (or move) the highlight over a candidate window's frame, given in
    /// global logical points, CG orientation (`WindowDescriptor.frame` space).
    func show(over windowFrame: LogicalRect) {
        rebuildPanelsIfNeeded()
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return }
        let global = WindowPickerGeometry.appKitScreenRect(for: windowFrame, primaryScreenHeight: primaryHeight)
        for panel in panels {
            guard let view = panel.contentView as? HighlightView else { continue }
            let local = CGRect(
                x: global.minX - panel.frame.minX,
                y: global.minY - panel.frame.minY,
                width: global.width,
                height: global.height
            )
            view.highlightRect = global.intersects(panel.frame) ? local : nil
            panel.orderFrontRegardless()
        }
    }

    func move(to windowFrame: LogicalRect) {
        show(over: windowFrame)
    }

    func hide() {
        guard panels.contains(where: \.isVisible) else { return }
        for panel in panels {
            (panel.contentView as? HighlightView)?.highlightRect = nil
            panel.orderOut(nil)
        }
        onDismiss?()
    }

    /// One panel per display; rebuilt when the screen arrangement changes.
    private func rebuildPanelsIfNeeded() {
        let screens = NSScreen.screens
        guard panels.count != screens.count
            || zip(panels, screens).contains(where: { $0.frame != $1.frame })
        else { return }
        for panel in panels {
            panel.orderOut(nil)
        }
        panels = screens.map(Self.makePanel(for:))
    }

    private static func makePanel(for screen: NSScreen) -> NSPanel {
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // Click-through: picking clicks must reach the capture flow / the
        // windows below, never this overlay.
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.contentView = HighlightView()
        return panel
    }
}

/// Draws the highlight: accent-tinted fill + rounded accent border.
private final class HighlightView: NSView {
    var highlightRect: CGRect? {
        didSet { needsDisplay = true }
    }

    override func draw(_: NSRect) {
        guard let rect = highlightRect else { return }
        let path = NSBezierPath(
            roundedRect: rect.insetBy(dx: 1.5, dy: 1.5),
            xRadius: 10,
            yRadius: 10
        )
        NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
        path.fill()
        NSColor.controlAccentColor.setStroke()
        path.lineWidth = 3
        path.stroke()
    }
}
