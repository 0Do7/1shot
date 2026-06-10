import Foundation

// Portable geometry primitives for the document model. Deliberately not CGPoint/
// CGRect: the JSON format is the cross-platform contract (design D3), so fields
// are named and the types carry no Apple framework dependency.
// Document coordinates: origin top-left, y down, units = base-image pixels.

public struct DocPoint: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = DocPoint(x: 0, y: 0)
}

public struct DocSize: Codable, Hashable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public static let zero = DocSize(width: 0, height: 0)
}

public struct DocRect: Codable, Hashable, Sendable {
    public var origin: DocPoint
    public var size: DocSize

    public init(origin: DocPoint, size: DocSize) {
        self.origin = origin
        self.size = size
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(origin: DocPoint(x: x, y: y), size: DocSize(width: width, height: height))
    }

    public var minX: Double {
        origin.x
    }

    public var minY: Double {
        origin.y
    }

    public var maxX: Double {
        origin.x + size.width
    }

    public var maxY: Double {
        origin.y + size.height
    }

    public var center: DocPoint {
        DocPoint(x: minX + size.width / 2, y: minY + size.height / 2)
    }

    public func offsetBy(dx: Double, dy: Double) -> DocRect {
        DocRect(x: minX + dx, y: minY + dy, width: size.width, height: size.height)
    }

    public func union(_ other: DocRect) -> DocRect {
        let x0 = Swift.min(minX, other.minX)
        let y0 = Swift.min(minY, other.minY)
        return DocRect(
            x: x0,
            y: y0,
            width: Swift.max(maxX, other.maxX) - x0,
            height: Swift.max(maxY, other.maxY) - y0
        )
    }

    public func contains(_ point: DocPoint) -> Bool {
        point.x >= minX && point.x < maxX && point.y >= minY && point.y < maxY
    }
}

/// Margins added around the base image by canvas expansion (all non-negative).
public struct DocEdgeInsets: Codable, Hashable, Sendable {
    public var top: Double
    public var left: Double
    public var bottom: Double
    public var right: Double

    public init(top: Double = 0, left: Double = 0, bottom: Double = 0, right: Double = 0) {
        precondition(
            top >= 0 && left >= 0 && bottom >= 0 && right >= 0,
            "canvas insets are margins; negative values are crops"
        )
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    public static let zero = DocEdgeInsets()
}
