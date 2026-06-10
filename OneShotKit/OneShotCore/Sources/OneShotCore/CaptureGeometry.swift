import Foundation

// Capture coordinate model (task 2.3, spec:capture-engine "Multi-display and
// mixed-DPI correctness"). Two spaces, two types — the compiler prevents mixing:
//
// - LOGICAL: global desktop coordinates in points. Convention: CoreGraphics
//   orientation — origin at the main display's top-left, y down — matching
//   ScreenCaptureKit/CGDisplay. AppKit's bottom-left flip happens in the app
//   layer, never here.
// - PIXEL: display-local native pixels (integral), origin at that display's
//   top-left. Captured output is produced in this space, so a 100×100pt
//   selection is 100×100px on a 1x display and 200×200px on a 2x display.

public struct LogicalPoint: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct LogicalRect: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var minX: Double {
        x
    }

    public var minY: Double {
        y
    }

    public var maxX: Double {
        x + width
    }

    public var maxY: Double {
        y + height
    }

    public var isEmpty: Bool {
        width <= 0 || height <= 0
    }

    public func contains(_ point: LogicalPoint) -> Bool {
        point.x >= minX && point.x < maxX && point.y >= minY && point.y < maxY
    }

    public func intersection(_ other: LogicalRect) -> LogicalRect {
        let x0 = Swift.max(minX, other.minX)
        let y0 = Swift.max(minY, other.minY)
        let x1 = Swift.min(maxX, other.maxX)
        let y1 = Swift.min(maxY, other.maxY)
        guard x1 > x0, y1 > y0 else { return LogicalRect(x: x0, y: y0, width: 0, height: 0) }
        return LogicalRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }

    public var area: Double {
        isEmpty ? 0 : width * height
    }
}

/// Display-local native pixels. Integral by construction — there is no such
/// thing as a fractional captured pixel.
public struct PixelRect: Codable, Hashable, Sendable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Portable description of one attached display. Built by OneShotCapture from
/// SCDisplay/CGDisplay at enumeration time; everything downstream (overlays,
/// stitcher, document metadata) consumes this value type.
public struct DisplayDescriptor: Codable, Hashable, Sendable {
    /// CGDirectDisplayID on macOS; opaque stable token elsewhere.
    public var id: UInt32
    /// Position and size in global logical space (points, top-left origin, y down).
    public var logicalFrame: LogicalRect
    /// Native pixels per point (1.0, 2.0; arbitrary positive values tolerated).
    public var scale: Double

    public init(id: UInt32, logicalFrame: LogicalRect, scale: Double) {
        precondition(scale > 0, "display scale must be positive")
        self.id = id
        self.logicalFrame = logicalFrame
        self.scale = scale
    }

    /// Native pixel dimensions of the full display.
    public var pixelWidth: Int {
        Int((logicalFrame.width * scale).rounded())
    }

    public var pixelHeight: Int {
        Int((logicalFrame.height * scale).rounded())
    }

    // MARK: Space conversion

    /// Global logical rect → display-local pixel rect, snapped **outward** so the
    /// captured pixels fully cover the selection (never shave sub-pixel edges).
    /// The input is clamped to this display's bounds first.
    public func pixelRect(for logical: LogicalRect) -> PixelRect {
        let clamped = logical.intersection(logicalFrame)
        let x0 = ((clamped.minX - logicalFrame.minX) * scale).rounded(.down)
        let y0 = ((clamped.minY - logicalFrame.minY) * scale).rounded(.down)
        let x1 = Swift.min(((clamped.maxX - logicalFrame.minX) * scale).rounded(.up), Double(pixelWidth))
        let y1 = Swift.min(((clamped.maxY - logicalFrame.minY) * scale).rounded(.up), Double(pixelHeight))
        return PixelRect(x: Int(x0), y: Int(y0), width: Int(x1 - x0), height: Int(y1 - y0))
    }

    /// Display-local pixel rect → global logical rect (exact; pixels are always
    /// representable in points).
    public func logicalRect(for pixel: PixelRect) -> LogicalRect {
        LogicalRect(
            x: logicalFrame.minX + Double(pixel.x) / scale,
            y: logicalFrame.minY + Double(pixel.y) / scale,
            width: Double(pixel.width) / scale,
            height: Double(pixel.height) / scale
        )
    }
}

/// The full arrangement of attached displays plus the cross-display rules the
/// spec mandates (a selection never mixes scale factors; it is constrained to
/// the display that owns most of it).
public struct DisplayLayout: Codable, Hashable, Sendable {
    public var displays: [DisplayDescriptor]

    public init(displays: [DisplayDescriptor]) {
        self.displays = displays
    }

    public func display(withID id: UInt32) -> DisplayDescriptor? {
        displays.first { $0.id == id }
    }

    public func display(containing point: LogicalPoint) -> DisplayDescriptor? {
        displays.first { $0.logicalFrame.contains(point) }
    }

    /// The display owning the largest share of `rect` (ties broken by array
    /// order, which OneShotCapture populates main-display-first).
    public func display(bestFor rect: LogicalRect) -> DisplayDescriptor? {
        displays
            .map { ($0, $0.logicalFrame.intersection(rect).area) }
            .filter { $0.1 > 0 }
            .max { $0.1 < $1.1 }?.0
    }

    /// Resolve an area selection to a single display + the pixels to capture
    /// (spec: a cross-display selection is constrained to one display, never a
    /// corrupted mixed-scale result). Returns nil when the rect touches no display.
    public func selectionTarget(for rect: LogicalRect) -> (display: DisplayDescriptor, pixels: PixelRect)? {
        guard let display = display(bestFor: rect) else { return nil }
        let pixels = display.pixelRect(for: rect)
        guard pixels.width > 0, pixels.height > 0 else { return nil }
        return (display, pixels)
    }
}
