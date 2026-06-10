import Foundation

/// Reference to image pixels stored alongside the document (inside the `.1shot`
/// bundle, task 2.2). The model never embeds pixel data — base image pixels stay
/// untouched for the lifetime of the document (spec: re-editable annotation document).
public struct ImageReference: Codable, Hashable, Sendable {
    /// File name within the document bundle (e.g. "base.png", "image-<uuid>.png").
    public var fileName: String
    /// Native pixel dimensions — exports must preserve these (never downscale).
    public var pixelWidth: Int
    public var pixelHeight: Int
    /// Backing scale at capture time (2.0 for Retina); pixel/logical conversion.
    public var scale: Double

    public init(fileName: String, pixelWidth: Int, pixelHeight: Int, scale: Double) {
        self.fileName = fileName
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.scale = scale
    }
}

/// Canvas margins beyond the base image plus their fill
/// (spec: crop and expandable canvas).
public struct CanvasConfiguration: Codable, Hashable, Sendable {
    public enum Background: Codable, Hashable, Sendable {
        case transparent
        case color(DocColor)
    }

    public var insets: DocEdgeInsets
    public var background: Background

    public init(insets: DocEdgeInsets = .zero, background: Background = .transparent) {
        self.insets = insets
        self.background = background
    }

    public static let none = CanvasConfiguration()
}

/// Non-destructive crop: the visible window onto the canvas. Content outside is
/// retained and reappears when the crop is adjusted or removed (spec scenario:
/// crop is re-adjustable).
public struct CropState: Codable, Hashable, Sendable {
    /// In document coordinates (base-image pixel space; canvas insets may extend
    /// coordinates negative or beyond the base image).
    public var rect: DocRect

    public init(rect: DocRect) {
        self.rect = rect
    }
}

/// The annotation document (design D3): a value-type scene graph over an untouched
/// base image. Undo/redo = whole-value snapshots (task 5.7). Persisted as JSON
/// inside the `.1shot` bundle with explicit schema versioning (task 2.2).
public struct AnnotationDocument: Codable, Hashable, Sendable {
    /// Bump on any breaking format change; `DocumentMigrator` must then migrate
    /// every older version forward (spec scenario: old documents open in newer
    /// app versions).
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var baseImage: ImageReference
    /// Z-ordered scene graph, index 0 = bottom. Counter badges derive their
    /// displayed number from their position in this array.
    public var annotations: [Annotation]
    public var canvas: CanvasConfiguration
    public var crop: CropState?

    public init(
        baseImage: ImageReference,
        annotations: [Annotation] = [],
        canvas: CanvasConfiguration = .none,
        crop: CropState? = nil
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.baseImage = baseImage
        self.annotations = annotations
        self.canvas = canvas
        self.crop = crop
    }

    // MARK: Derived geometry

    /// Base image bounds in document coordinates (origin at 0,0; pixel units).
    public var baseImageRect: DocRect {
        DocRect(x: 0, y: 0, width: Double(baseImage.pixelWidth), height: Double(baseImage.pixelHeight))
    }

    /// Full canvas including expansion margins (before any crop).
    public var canvasRect: DocRect {
        DocRect(
            x: -canvas.insets.left,
            y: -canvas.insets.top,
            width: Double(baseImage.pixelWidth) + canvas.insets.left + canvas.insets.right,
            height: Double(baseImage.pixelHeight) + canvas.insets.top + canvas.insets.bottom
        )
    }

    /// What exports render: the crop window if set, else the full canvas.
    public var visibleRect: DocRect {
        crop?.rect ?? canvasRect
    }

    // MARK: Annotation access

    public func annotation(id: UUID) -> Annotation? {
        annotations.first { $0.id == id }
    }

    /// Displayed number for a counter annotation: 1-based position among counters
    /// in document order. Deleting a counter renumbers the rest automatically
    /// (spec scenario: counter badges auto-increment).
    public func counterNumber(for id: UUID) -> Int? {
        var number = 0
        for annotation in annotations {
            if case .counter = annotation {
                number += 1
                if annotation.id == id { return number }
            }
        }
        return nil
    }
}
