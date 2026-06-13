import AppKit
import OneShotCore

/// Borderless, key-capable overlay window — one per display (spec:capture-engine
/// "Area selection capture" + "Multi-display and mixed-DPI correctness": the
/// crosshair overlay appears on every connected display). Unlike the click-
/// through window-pick highlight, this window becomes key so it can own the
/// pointer drag and the Esc / arrow-key / Return contract during selection.
@MainActor
final class AreaSelectionWindow: NSPanel {
    let selectionView: AreaSelectionView

    init(screen: NSScreen, displayID: UInt32, model: AreaSelectionModel, controller: AreaSelectionController) {
        selectionView = AreaSelectionView(displayID: displayID, model: model, controller: controller)
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
        contentView = selectionView
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}

/// Renders the dimmed backdrop snapshot with the selection punched out at full
/// brightness, plus the crosshair, resize handles, live dimension readout, and
/// the pixel-accurate magnifier loupe. Routes pointer/keyboard input into the
/// shared model via the controller.
@MainActor
final class AreaSelectionView: NSView {
    private let displayID: UInt32
    private unowned let model: AreaSelectionModel
    private unowned let controller: AreaSelectionController

    private var cursor: LogicalPoint?
    private var trackingArea: NSTrackingArea?

    private let dimAlpha: CGFloat = 0.32
    private let magnifierPixelDiameter = 21
    private let magnifierSize: CGFloat = 132

    init(displayID: UInt32, model: AreaSelectionModel, controller: AreaSelectionController) {
        self.displayID = displayID
        self.model = model
        self.controller = controller
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("not used")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override var isFlipped: Bool {
        false
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
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func cursorUpdate(with _: NSEvent) {
        NSCursor.crosshair.set()
    }

    // MARK: Input

    override func mouseDown(with event: NSEvent) {
        let point = logical(from: event)
        cursor = point
        controller.pointerDown(at: point)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = logical(from: event)
        cursor = point
        controller.pointerDragged(to: point)
    }

    override func mouseUp(with _: NSEvent) {
        controller.pointerUp()
    }

    override func mouseMoved(with event: NSEvent) {
        cursor = logical(from: event)
        needsDisplay = true
    }

    override func mouseExited(with _: NSEvent) {
        cursor = nil
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        let step: Double = event.modifierFlags.contains(.shift) ? 10 : 1
        let resizing = event.modifierFlags.contains(.option)
        switch event.keyCode {
        case 53: controller.cancel() // Esc
        case 36, 76: controller.confirm() // Return / keypad Enter
        case 123: controller.nudge(.left, resizing: resizing, step: step)
        case 124: controller.nudge(.right, resizing: resizing, step: step)
        case 125: controller.nudge(.down, resizing: resizing, step: step)
        case 126: controller.nudge(.up, resizing: resizing, step: step)
        default: super.keyDown(with: event)
        }
    }

    // MARK: Drawing

    override func draw(_: NSRect) {
        guard let ctx = NSGraphicsContext.current else { return }
        let backdrop = controller.snapshot(for: displayID).map { NSImage(cgImage: $0, size: bounds.size) }

        backdrop?.draw(in: bounds)
        NSColor.black.withAlphaComponent(dimAlpha).setFill()
        bounds.fill()

        if let selection = model.selection, !selection.isEmpty {
            let rect = viewRect(forLogical: selection)
            if rect.intersects(bounds) {
                drawSelection(rect, backdrop: backdrop, context: ctx)
            }
        }
        drawCrosshairIfNeeded()
        drawMagnifierIfNeeded(context: ctx)
    }

    private func drawSelection(_ rect: CGRect, backdrop: NSImage?, context ctx: NSGraphicsContext) {
        // Re-light the selected region by redrawing the backdrop clipped to it.
        ctx.saveGraphicsState()
        NSBezierPath(rect: rect).addClip()
        backdrop?.draw(in: bounds)
        ctx.restoreGraphicsState()

        NSColor.controlAccentColor.setStroke()
        let border = NSBezierPath(rect: rect)
        border.lineWidth = 1.5
        border.stroke()
        drawHandles(around: rect)
        drawDimensionReadout(for: rect)
    }

    private func drawHandles(around rect: CGRect) {
        let size: CGFloat = 7
        let points = [
            CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.midX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.minX, y: rect.midY),
            CGPoint(x: rect.maxX, y: rect.midY), CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.midX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY),
        ]
        for point in points {
            let box = CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
            NSColor.white.setFill()
            NSColor.controlAccentColor.setStroke()
            let path = NSBezierPath(ovalIn: box)
            path.fill()
            path.lineWidth = 1
            path.stroke()
        }
    }

    private func drawDimensionReadout(for rect: CGRect) {
        guard let size = model.pixelSize() else { return }
        let text = "\(size.width) × \(size.height)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let textSize = string.size()
        let padding: CGFloat = 6
        let chip = CGRect(
            x: rect.minX,
            y: Swift.max(2, rect.minY - textSize.height - padding * 2 - 4),
            width: textSize.width + padding * 2,
            height: textSize.height + padding
        )
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: chip, xRadius: 4, yRadius: 4).fill()
        string.draw(at: CGPoint(x: chip.minX + padding, y: chip.minY + padding / 2))
    }

    private func drawCrosshairIfNeeded() {
        // Pre-selection placement aid: full-bleed crosshair at the cursor.
        guard model.selection == nil, let cursor, let point = viewPoint(forLogical: cursor) else { return }
        NSColor.white.withAlphaComponent(0.6).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1
        path.move(to: CGPoint(x: bounds.minX, y: point.y))
        path.line(to: CGPoint(x: bounds.maxX, y: point.y))
        path.move(to: CGPoint(x: point.x, y: bounds.minY))
        path.line(to: CGPoint(x: point.x, y: bounds.maxY))
        path.stroke()
    }

    private func drawMagnifierIfNeeded(context ctx: NSGraphicsContext) {
        guard let cursor, let point = viewPoint(forLogical: cursor),
              let sample = model.magnifierSample(around: cursor, pixelDiameter: magnifierPixelDiameter),
              sample.display.id == displayID,
              let backdrop = controller.snapshot(for: displayID),
              let cropped = backdrop.cropping(to: CGRect(
                  x: sample.pixels.x, y: sample.pixels.y,
                  width: sample.pixels.width, height: sample.pixels.height
              ))
        else { return }

        var origin = CGPoint(x: point.x + 16, y: point.y + 16)
        if origin.x + magnifierSize > bounds.maxX { origin.x = point.x - 16 - magnifierSize }
        if origin.y + magnifierSize > bounds.maxY { origin.y = point.y - 16 - magnifierSize }
        let loupe = CGRect(x: origin.x, y: origin.y, width: magnifierSize, height: magnifierSize)

        ctx.saveGraphicsState()
        let clip = NSBezierPath(roundedRect: loupe, xRadius: 8, yRadius: 8)
        clip.addClip()
        ctx.imageInterpolation = .none
        NSImage(cgImage: cropped, size: loupe.size).draw(in: loupe)
        ctx.restoreGraphicsState()

        // Center cell + frame.
        let cell = magnifierSize / CGFloat(magnifierPixelDiameter)
        let center = CGRect(
            x: loupe.minX + (loupe.width - cell) / 2,
            y: loupe.minY + (loupe.height - cell) / 2,
            width: cell,
            height: cell
        )
        NSColor.controlAccentColor.setStroke()
        let centerPath = NSBezierPath(rect: center)
        centerPath.lineWidth = 1
        centerPath.stroke()
        let frame = NSBezierPath(roundedRect: loupe, xRadius: 8, yRadius: 8)
        NSColor.white.withAlphaComponent(0.8).setStroke()
        frame.lineWidth = 1
        frame.stroke()
    }

    // MARK: Coordinate conversion

    private var primaryHeight: Double {
        Double(NSScreen.screens.first?.frame.height ?? 0)
    }

    private func logical(from event: NSEvent) -> LogicalPoint {
        guard let window else { return LogicalPoint(x: event.locationInWindow.x, y: event.locationInWindow.y) }
        let screenPoint = window.convertPoint(toScreen: event.locationInWindow)
        return WindowPickerGeometry.logicalPoint(
            forAppKit: CGPoint(x: screenPoint.x, y: screenPoint.y),
            primaryScreenHeight: primaryHeight
        )
    }

    private func viewRect(forLogical rect: LogicalRect) -> CGRect {
        let global = WindowPickerGeometry.appKitScreenRect(for: rect, primaryScreenHeight: primaryHeight)
        guard let window else { return global }
        return CGRect(
            x: global.minX - window.frame.minX,
            y: global.minY - window.frame.minY,
            width: global.width,
            height: global.height
        )
    }

    private func viewPoint(forLogical point: LogicalPoint) -> CGPoint? {
        guard let window else { return nil }
        let global = WindowPickerGeometry.appKitScreenRect(
            for: LogicalRect(x: point.x, y: point.y, width: 0, height: 0),
            primaryScreenHeight: primaryHeight
        )
        let local = CGPoint(x: global.minX - window.frame.minX, y: global.minY - window.frame.minY)
        return bounds.contains(local) ? local : nil
    }
}
