import Foundation

// The annotation scene graph (design D3): one enum, one case per tool, payload
// structs carrying identity + geometry + style. Annotations are never painted
// into pixels (spec: re-editable annotation document); OneShotRender rasterizes
// only at export.

public struct ArrowAnnotation: Codable, Hashable, Sendable {
    public var id: UUID
    public var start: DocPoint
    public var end: DocPoint
    /// Quadratic Bézier control point; nil = straight arrow (spec: curved arrow
    /// is reshaped by dragging this point).
    public var control: DocPoint?
    public var stroke: StrokeStyle

    public init(id: UUID = UUID(), start: DocPoint, end: DocPoint, control: DocPoint? = nil, stroke: StrokeStyle) {
        self.id = id
        self.start = start
        self.end = end
        self.control = control
        self.stroke = stroke
    }
}

public struct LineAnnotation: Codable, Hashable, Sendable {
    public var id: UUID
    public var start: DocPoint
    public var end: DocPoint
    public var stroke: StrokeStyle

    public init(id: UUID = UUID(), start: DocPoint, end: DocPoint, stroke: StrokeStyle) {
        self.id = id
        self.start = start
        self.end = end
        self.stroke = stroke
    }
}

public struct ShapeAnnotation: Codable, Hashable, Sendable {
    public enum Shape: String, Codable, Sendable {
        case rectangle, ellipse
    }

    public var id: UUID
    public var shape: Shape
    public var rect: DocRect
    public var stroke: StrokeStyle
    public var fill: DocColor?
    /// Rectangles only; ignored for ellipses.
    public var cornerRadius: Double

    public init(
        id: UUID = UUID(),
        shape: Shape,
        rect: DocRect,
        stroke: StrokeStyle,
        fill: DocColor? = nil,
        cornerRadius: Double = 0
    ) {
        self.id = id
        self.shape = shape
        self.rect = rect
        self.stroke = stroke
        self.fill = fill
        self.cornerRadius = cornerRadius
    }
}

public struct TextAnnotation: Codable, Hashable, Sendable {
    public var id: UUID
    public var text: String
    /// Anchor of the text block; width grows with content, so no full rect.
    public var origin: DocPoint
    public var style: TextStyle

    public init(id: UUID = UUID(), text: String, origin: DocPoint, style: TextStyle) {
        self.id = id
        self.text = text
        self.origin = origin
        self.style = style
    }
}

public struct HighlightAnnotation: Codable, Hashable, Sendable {
    public enum Mode: String, Codable, Sendable {
        /// Snapped to detected text-line geometry (spec: smart text-following highlight).
        case snapped
        /// Free rectangle (no text detected, or user override).
        case free
    }

    public var id: UUID
    public var mode: Mode
    /// One rect per highlighted text line in snapped mode; single rect in free mode.
    public var rects: [DocRect]
    public var color: DocColor

    public init(id: UUID = UUID(), mode: Mode, rects: [DocRect], color: DocColor) {
        self.id = id
        self.mode = mode
        self.rects = rects
        self.color = color
    }
}

public struct SpotlightAnnotation: Codable, Hashable, Sendable {
    public enum Shape: String, Codable, Sendable {
        case rectangle, ellipse
    }

    public var id: UUID
    public var region: DocRect
    public var shape: Shape
    /// 0–1 darkening applied outside the region.
    public var dimOpacity: Double

    public init(id: UUID = UUID(), region: DocRect, shape: Shape = .rectangle, dimOpacity: Double = 0.6) {
        self.id = id
        self.region = region
        self.shape = shape
        self.dimOpacity = dimOpacity
    }
}

/// Counter badges carry no stored number: their displayed value is their 1-based
/// position among counter annotations in document order, so deletion renumbers
/// automatically (spec: counter badges auto-increment).
public struct CounterAnnotation: Codable, Hashable, Sendable {
    public var id: UUID
    public var center: DocPoint
    public var diameter: Double
    public var color: DocColor

    public init(id: UUID = UUID(), center: DocPoint, diameter: Double = 28, color: DocColor) {
        self.id = id
        self.center = center
        self.diameter = diameter
        self.color = color
    }
}

public struct FreehandAnnotation: Codable, Hashable, Sendable {
    public var id: UUID
    public var points: [DocPoint]
    public var stroke: StrokeStyle
    /// Smoothed (fitted curve) vs raw polyline rendering.
    public var smoothed: Bool

    public init(id: UUID = UUID(), points: [DocPoint], stroke: StrokeStyle, smoothed: Bool = true) {
        self.id = id
        self.points = points
        self.stroke = stroke
        self.smoothed = smoothed
    }
}

public struct MagnifierAnnotation: Codable, Hashable, Sendable {
    public var id: UUID
    /// Region of the base image being magnified; callout content tracks it live.
    public var sourceRect: DocRect
    /// Where the enlarged inset is displayed (its size sets the magnification).
    public var calloutRect: DocRect
    public var border: StrokeStyle

    public init(id: UUID = UUID(), sourceRect: DocRect, calloutRect: DocRect, border: StrokeStyle) {
        self.id = id
        self.sourceRect = sourceRect
        self.calloutRect = calloutRect
        self.border = border
    }

    public var magnification: Double {
        sourceRect.size.width > 0 ? calloutRect.size.width / sourceRect.size.width : 1
    }
}

/// Blur / pixelate / black-out / erase share one payload (spec:redaction).
/// Rendered destructively only at export (task 6.2); a live object until then.
public struct RedactionAnnotation: Codable, Hashable, Sendable {
    public enum Style: String, Codable, Sendable {
        case blur, pixelate, blackout
        /// Background-matching fill that synthesizes plausible surrounding content
        /// into the region so it blends in with NO legible residue (spec:redaction
        /// "Text-aware blur and erase" erase branch + "Content-aware object removal").
        /// Like the obscuring styles it is rendered destructively at export, never
        /// reversible. The fill synthesis lives in OneShotRender (CoreImage); the
        /// model just carries the case so erase round-trips through the document.
        case erase
    }

    public var id: UUID
    public var rect: DocRect
    public var style: Style
    /// Blur sigma or pixelate cell size, in base-image pixels. Must stay at or
    /// above the OCR-defeat floor enforced by task 6.1's tests.
    public var strength: Double
    /// Set when created by text-aware redaction (task 6.3) so per-instance
    /// toggling can distinguish detected text from manual regions.
    public var detectedText: Bool

    public init(
        id: UUID = UUID(),
        rect: DocRect,
        style: Style,
        strength: Double = 12,
        detectedText: Bool = false
    ) {
        self.id = id
        self.rect = rect
        self.style = style
        self.strength = strength
        self.detectedText = detectedText
    }
}

/// An additional capture placed into the document (spec: multi-image stitch and
/// combine). Independent, repositionable object until export.
public struct PlacedImageAnnotation: Codable, Hashable, Sendable {
    public var id: UUID
    public var image: ImageReference
    public var rect: DocRect

    public init(id: UUID = UUID(), image: ImageReference, rect: DocRect) {
        self.id = id
        self.image = image
        self.rect = rect
    }
}

public enum Annotation: Hashable, Sendable {
    case arrow(ArrowAnnotation)
    case line(LineAnnotation)
    case shape(ShapeAnnotation)
    case text(TextAnnotation)
    case highlight(HighlightAnnotation)
    case spotlight(SpotlightAnnotation)
    case counter(CounterAnnotation)
    case freehand(FreehandAnnotation)
    case magnifier(MagnifierAnnotation)
    case redaction(RedactionAnnotation)
    case placedImage(PlacedImageAnnotation)

    public var id: UUID {
        switch self {
        case let .arrow(a): a.id
        case let .line(a): a.id
        case let .shape(a): a.id
        case let .text(a): a.id
        case let .highlight(a): a.id
        case let .spotlight(a): a.id
        case let .counter(a): a.id
        case let .freehand(a): a.id
        case let .magnifier(a): a.id
        case let .redaction(a): a.id
        case let .placedImage(a): a.id
        }
    }
}

extension Annotation: Identifiable {}
