import Foundation
import OneShotCore

/// Which corner/edge of a selection a pointer grab is manipulating, or the body
/// (move-whole). Corners take priority over edges, edges over the body.
enum SelectionHandle: Equatable {
    enum Corner: Equatable { case topLeft, topRight, bottomLeft, bottomRight }
    enum Edge: Equatable { case top, bottom, left, right }
    case corner(Corner)
    case edge(Edge)
    case body
}

/// Arrow-key nudge directions. CG orientation: `.up` decreases y.
enum NudgeDirection: Equatable { case up, down, left, right }

/// Drives the area-selection flow (task 3.2, spec:capture-engine "Area selection
/// capture" + "Multi-display and mixed-DPI correctness"): it owns the selection
/// rectangle and the drag / handle-adjust / keyboard-nudge state machine, and
/// resolves the selection to a single source display + native pixel rect via the
/// portable `DisplayLayout` (so a cross-display selection is constrained to one
/// display, never a mixed-scale corruption).
///
/// All coordinates are global logical points in CG orientation (top-left origin,
/// y down) — the same space `DisplayDescriptor.logicalFrame` and
/// `WindowDescriptor.frame` use. The AppKit overlay (`AreaSelectionView`) flips
/// into this space at the boundary via `WindowPickerGeometry`; the model never
/// touches AppKit. The pure geometry is exposed as `nonisolated static` helpers
/// so the math is unit-testable without screens.
@MainActor
final class AreaSelectionModel {
    private(set) var layout: DisplayLayout

    /// The current selection in global logical points, normalized (non-negative
    /// size). `nil` before the first drag and after `cancel()`.
    private(set) var selection: LogicalRect?

    /// Distance (logical points) within which a pointer-down grabs a handle
    /// rather than starting a fresh selection.
    var handleSlop: Double = 8

    private enum Active {
        case drawing(anchor: LogicalPoint)
        case adjusting(handle: SelectionHandle, grabRect: LogicalRect, grabPoint: LogicalPoint)
    }

    private var active: Active?

    init(layout: DisplayLayout) {
        self.layout = layout
    }

    /// Refresh the display arrangement mid-selection (displays attach/detach).
    func updateLayout(_ layout: DisplayLayout) {
        self.layout = layout
    }

    // MARK: Pointer interaction

    /// Pointer-down: grab a handle of the existing selection if one is under the
    /// pointer, otherwise begin a fresh selection anchored here.
    func pointerDown(at point: LogicalPoint) {
        if let selection, let handle = Self.hitTest(point, in: selection, slop: handleSlop) {
            active = .adjusting(handle: handle, grabRect: selection, grabPoint: point)
        } else {
            active = .drawing(anchor: point)
            selection = LogicalRect(x: point.x, y: point.y, width: 0, height: 0)
        }
    }

    /// Pointer-drag: extend the new selection, or move the grabbed handle.
    func pointerDragged(to point: LogicalPoint) {
        switch active {
        case let .drawing(anchor):
            selection = Self.normalizedRect(from: anchor, to: point)
        case let .adjusting(handle, grabRect, grabPoint):
            selection = Self.resolved(handle: handle, grabRect: grabRect, grabPoint: grabPoint, to: point)
        case nil:
            break
        }
    }

    /// Pointer-up: end the gesture. A fresh drag that produced no area collapses
    /// back to "no selection" so a stray click does not arm an empty capture.
    func pointerUp() {
        if case .drawing = active, let selection, selection.isEmpty {
            self.selection = nil
        }
        active = nil
    }

    // MARK: Keyboard

    /// Nudge the selection by `step` logical points. `resizing` grows/shrinks the
    /// bottom-right corner; otherwise the whole selection translates. No-op when
    /// there is no selection.
    func nudge(_ direction: NudgeDirection, resizing: Bool, step: Double = 1) {
        guard let selection else { return }
        self.selection = Self.nudged(selection, direction, resizing: resizing, step: step)
    }

    /// Esc / dismiss: drop the selection entirely.
    func cancel() {
        selection = nil
        active = nil
    }

    // MARK: Resolution to a capturable target

    /// The single display + display-local native pixel rect the selection maps
    /// to, or `nil` when the selection is empty or off every display. Delegates
    /// the cross-display rules to `DisplayLayout.selectionTarget`.
    func target() -> (display: DisplayDescriptor, pixels: PixelRect)? {
        guard let selection, !selection.isEmpty else { return nil }
        return layout.selectionTarget(for: selection)
    }

    /// Live dimension readout: the native pixel size of the image the current
    /// selection would produce (200×200 for a 100×100-pt region on a 2× display,
    /// 100×100 on a 1× display). `nil` when there is nothing to capture yet.
    func pixelSize() -> (width: Int, height: Int)? {
        guard let target = target() else { return nil }
        return (target.pixels.width, target.pixels.height)
    }

    /// Source rect for the magnifier loupe: a `pixelDiameter`-wide native-pixel
    /// square centered on `point`, clamped inside the display under the pointer.
    /// `nil` when the pointer is over no display.
    func magnifierSample(
        around point: LogicalPoint,
        pixelDiameter: Int
    ) -> (display: DisplayDescriptor, pixels: PixelRect)? {
        guard let display = layout.display(containing: point) else { return nil }
        let width = Swift.min(pixelDiameter, display.pixelWidth)
        let height = Swift.min(pixelDiameter, display.pixelHeight)
        let centerX = (point.x - display.logicalFrame.minX) * display.scale
        let centerY = (point.y - display.logicalFrame.minY) * display.scale
        let rawX = Int(centerX.rounded(.down)) - width / 2
        let rawY = Int(centerY.rounded(.down)) - height / 2
        let x = Swift.min(Swift.max(0, rawX), display.pixelWidth - width)
        let y = Swift.min(Swift.max(0, rawY), display.pixelHeight - height)
        return (display, PixelRect(x: x, y: y, width: width, height: height))
    }

    // MARK: Pure geometry (unit-testable without screens)

    /// Axis-aligned rect spanning two points, with non-negative size — so a
    /// backward drag (up-left from the anchor) still yields a valid selection.
    nonisolated static func normalizedRect(from a: LogicalPoint, to b: LogicalPoint) -> LogicalRect {
        LogicalRect(
            x: Swift.min(a.x, b.x),
            y: Swift.min(a.y, b.y),
            width: abs(a.x - b.x),
            height: abs(a.y - b.y)
        )
    }

    /// Classify a pointer-down against an existing selection: corner, edge, body,
    /// or `nil` (outside → start a fresh selection). Corners beat edges; edges
    /// beat the body.
    nonisolated static func hitTest(_ point: LogicalPoint, in rect: LogicalRect, slop: Double) -> SelectionHandle? {
        let nearLeft = abs(point.x - rect.minX) <= slop
        let nearRight = abs(point.x - rect.maxX) <= slop
        let nearTop = abs(point.y - rect.minY) <= slop
        let nearBottom = abs(point.y - rect.maxY) <= slop
        let withinX = point.x >= rect.minX - slop && point.x <= rect.maxX + slop
        let withinY = point.y >= rect.minY - slop && point.y <= rect.maxY + slop
        guard withinX, withinY else { return nil }

        if nearLeft, nearTop { return .corner(.topLeft) }
        if nearRight, nearTop { return .corner(.topRight) }
        if nearLeft, nearBottom { return .corner(.bottomLeft) }
        if nearRight, nearBottom { return .corner(.bottomRight) }
        if nearLeft { return .edge(.left) }
        if nearRight { return .edge(.right) }
        if nearTop { return .edge(.top) }
        if nearBottom { return .edge(.bottom) }
        if rect.contains(point) { return .body }
        return nil
    }

    /// Apply a handle drag: corners pivot on the opposite corner, edges move one
    /// side, the body translates by the pointer delta. Result is normalized so a
    /// handle dragged past the opposite side flips cleanly.
    nonisolated static func resolved(
        handle: SelectionHandle,
        grabRect rect: LogicalRect,
        grabPoint grab: LogicalPoint,
        to point: LogicalPoint
    ) -> LogicalRect {
        let topLeft = LogicalPoint(x: rect.minX, y: rect.minY)
        let bottomRight = LogicalPoint(x: rect.maxX, y: rect.maxY)
        switch handle {
        case let .corner(corner):
            return normalizedRect(from: oppositeCorner(of: corner, in: rect), to: point)
        case .edge(.left):
            return normalizedRect(from: LogicalPoint(x: point.x, y: rect.minY), to: bottomRight)
        case .edge(.right):
            return normalizedRect(from: topLeft, to: LogicalPoint(x: point.x, y: rect.maxY))
        case .edge(.top):
            return normalizedRect(from: LogicalPoint(x: rect.minX, y: point.y), to: bottomRight)
        case .edge(.bottom):
            return normalizedRect(from: topLeft, to: LogicalPoint(x: rect.maxX, y: point.y))
        case .body:
            let origin = LogicalPoint(x: rect.x + point.x - grab.x, y: rect.y + point.y - grab.y)
            return LogicalRect(x: origin.x, y: origin.y, width: rect.width, height: rect.height)
        }
    }

    /// Translate or resize a rect by `step`. Resizing moves the bottom-right
    /// corner and clamps to a 1-pt floor so the selection never inverts or
    /// vanishes under repeated key presses.
    nonisolated static func nudged(
        _ rect: LogicalRect,
        _ direction: NudgeDirection,
        resizing: Bool,
        step: Double
    ) -> LogicalRect {
        var result = rect
        switch (direction, resizing) {
        case (.left, false): result.x -= step
        case (.right, false): result.x += step
        case (.up, false): result.y -= step
        case (.down, false): result.y += step
        case (.left, true): result.width = Swift.max(1, rect.width - step)
        case (.right, true): result.width += step
        case (.up, true): result.height = Swift.max(1, rect.height - step)
        case (.down, true): result.height += step
        }
        return result
    }

    private nonisolated static func oppositeCorner(
        of corner: SelectionHandle.Corner,
        in rect: LogicalRect
    ) -> LogicalPoint {
        switch corner {
        case .topLeft: LogicalPoint(x: rect.maxX, y: rect.maxY)
        case .topRight: LogicalPoint(x: rect.minX, y: rect.maxY)
        case .bottomLeft: LogicalPoint(x: rect.maxX, y: rect.minY)
        case .bottomRight: LogicalPoint(x: rect.minX, y: rect.minY)
        }
    }
}
