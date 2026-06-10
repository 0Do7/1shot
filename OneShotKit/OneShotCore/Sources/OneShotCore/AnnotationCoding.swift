import Foundation

// Hand-written Codable for the discriminated unions: the JSON layout
// (`{"kind": "...", "props": {...}}`) is the documented cross-platform format
// (design D3), so it must stay explicit and stable — never rely on Swift's
// synthesized enum encoding, whose shape is a language implementation detail.

extension Annotation: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, props
    }

    private enum Kind: String, Codable {
        case arrow, line, shape, text, highlight, spotlight, counter, freehand,
             magnifier, redaction, placedImage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        self = switch kind {
        case .arrow: try .arrow(container.decode(ArrowAnnotation.self, forKey: .props))
        case .line: try .line(container.decode(LineAnnotation.self, forKey: .props))
        case .shape: try .shape(container.decode(ShapeAnnotation.self, forKey: .props))
        case .text: try .text(container.decode(TextAnnotation.self, forKey: .props))
        case .highlight: try .highlight(container.decode(HighlightAnnotation.self, forKey: .props))
        case .spotlight: try .spotlight(container.decode(SpotlightAnnotation.self, forKey: .props))
        case .counter: try .counter(container.decode(CounterAnnotation.self, forKey: .props))
        case .freehand: try .freehand(container.decode(FreehandAnnotation.self, forKey: .props))
        case .magnifier: try .magnifier(container.decode(MagnifierAnnotation.self, forKey: .props))
        case .redaction: try .redaction(container.decode(RedactionAnnotation.self, forKey: .props))
        case .placedImage: try .placedImage(container.decode(PlacedImageAnnotation.self, forKey: .props))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .arrow(a):
            try container.encode(Kind.arrow, forKey: .kind)
            try container.encode(a, forKey: .props)
        case let .line(a):
            try container.encode(Kind.line, forKey: .kind)
            try container.encode(a, forKey: .props)
        case let .shape(a):
            try container.encode(Kind.shape, forKey: .kind)
            try container.encode(a, forKey: .props)
        case let .text(a):
            try container.encode(Kind.text, forKey: .kind)
            try container.encode(a, forKey: .props)
        case let .highlight(a):
            try container.encode(Kind.highlight, forKey: .kind)
            try container.encode(a, forKey: .props)
        case let .spotlight(a):
            try container.encode(Kind.spotlight, forKey: .kind)
            try container.encode(a, forKey: .props)
        case let .counter(a):
            try container.encode(Kind.counter, forKey: .kind)
            try container.encode(a, forKey: .props)
        case let .freehand(a):
            try container.encode(Kind.freehand, forKey: .kind)
            try container.encode(a, forKey: .props)
        case let .magnifier(a):
            try container.encode(Kind.magnifier, forKey: .kind)
            try container.encode(a, forKey: .props)
        case let .redaction(a):
            try container.encode(Kind.redaction, forKey: .kind)
            try container.encode(a, forKey: .props)
        case let .placedImage(a):
            try container.encode(Kind.placedImage, forKey: .kind)
            try container.encode(a, forKey: .props)
        }
    }
}

extension CanvasConfiguration.Background {
    private enum CodingKeys: String, CodingKey {
        case kind, color
    }

    private enum Kind: String, Codable {
        case transparent, color
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .transparent: self = .transparent
        case .color: self = try .color(container.decode(DocColor.self, forKey: .color))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .transparent:
            try container.encode(Kind.transparent, forKey: .kind)
        case let .color(color):
            try container.encode(Kind.color, forKey: .kind)
            try container.encode(color, forKey: .color)
        }
    }
}
