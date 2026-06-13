import AppKit
import OneShotCore

/// Briefly shows the stored region's bounds before a repeat-area recapture
/// (spec:capture-engine "Repeat shows preview before recapture" / "Cancel during
/// repeat preview"). Auto-confirms after `duration`; Esc cancels. Returns
/// whether the capture should proceed. Driven by a `@MainActor` async loop (no
/// `Timer`) so it stays clean under Swift 6 strict concurrency.
@MainActor
final class RepeatPreviewOverlay {
    private var cancelled = false
    private var window: PreviewWindow?

    func show(region pixels: PixelRect, on display: DisplayDescriptor, duration: TimeInterval = 0.8) async -> Bool {
        guard let screen = NSScreen.screens.first(where: { $0.oneShotDisplayID == display.id }) else { return true }
        let primaryHeight = Double(NSScreen.screens.first?.frame.height ?? 0)
        let global = WindowPickerGeometry.appKitScreenRect(
            for: display.logicalRect(for: pixels),
            primaryScreenHeight: primaryHeight
        )
        let window = PreviewWindow(screen: screen, regionGlobal: global) { [weak self] in self?.cancelled = true }
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        defer {
            window.orderOut(nil)
            self.window = nil
        }

        let steps = 8
        let stepNanos = UInt64((duration / Double(steps)) * 1_000_000_000)
        for _ in 0 ..< steps {
            if cancelled { return false }
            try? await Task.sleep(nanoseconds: stepNanos)
        }
        return !cancelled
    }
}

@MainActor
private final class PreviewWindow: NSPanel {
    private let onCancel: () -> Void

    init(screen: NSScreen, regionGlobal: CGRect, onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
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
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isReleasedWhenClosed = false
        animationBehavior = .none
        let view = PreviewView()
        view.regionInView = CGRect(
            x: regionGlobal.minX - frame.minX,
            y: regionGlobal.minY - frame.minY,
            width: regionGlobal.width,
            height: regionGlobal.height
        )
        contentView = view
    }

    override var canBecomeKey: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel() } else { super.keyDown(with: event) }
    }
}

private final class PreviewView: NSView {
    var regionInView: CGRect = .zero {
        didSet { needsDisplay = true }
    }

    override func draw(_: NSRect) {
        NSColor.black.withAlphaComponent(0.18).setFill()
        bounds.fill()
        NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
        regionInView.fill()
        NSColor.controlAccentColor.setStroke()
        let border = NSBezierPath(rect: regionInView)
        border.lineWidth = 2
        border.stroke()
    }
}

/// Visible, cancellable countdown for delayed capture (spec:capture-engine
/// "Delayed capture"). Ticks a `CaptureCountdown` once per second via a
/// `@MainActor` async loop; Esc or a click on the indicator cancels. Returns
/// whether the capture should fire.
@MainActor
final class CountdownOverlay {
    private var cancelled = false
    private var window: CountdownWindow?

    func run(seconds: Int) async -> Bool {
        guard seconds > 0 else { return true }
        let countdown = CaptureCountdown(seconds: seconds)
        let window = CountdownWindow(remaining: seconds) { [weak self] in self?.cancelled = true }
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        defer {
            window.orderOut(nil)
            self.window = nil
        }

        while !countdown.isFinished {
            if cancelled { return false }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if cancelled { return false }
            _ = countdown.tick()
            window.update(remaining: countdown.remaining)
        }
        return true
    }
}

@MainActor
private final class CountdownWindow: NSPanel {
    private let onCancel: () -> Void
    private let label = NSTextField(labelWithString: "")

    init(remaining: Int, onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
        let size = CGFloat(160)
        super.init(
            contentRect: CGRect(x: 0, y: 0, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isReleasedWhenClosed = false
        animationBehavior = .none

        let background = NSVisualEffectView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        background.material = .hudWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 20
        background.layer?.masksToBounds = true

        label.font = .systemFont(ofSize: 64, weight: .semibold)
        label.alignment = .center
        label.textColor = .white
        label.frame = CGRect(x: 0, y: (size - 80) / 2, width: size, height: 80)
        label.stringValue = "\(remaining)"
        background.addSubview(label)
        contentView = background
        center()
    }

    override var canBecomeKey: Bool {
        true
    }

    func update(remaining: Int) {
        label.stringValue = "\(remaining)"
    }

    override func mouseDown(with _: NSEvent) {
        onCancel()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel() } else { super.keyDown(with: event) }
    }
}
