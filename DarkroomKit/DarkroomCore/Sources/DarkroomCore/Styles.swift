import Foundation

/// Portable sRGB color (0–1 components). Not NSColor/CGColor: the document format
/// is the cross-platform contract.
public struct DocColor: Codable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let black = DocColor(red: 0, green: 0, blue: 0)
    public static let white = DocColor(red: 1, green: 1, blue: 1)
    public static let clear = DocColor(red: 0, green: 0, blue: 0, alpha: 0)
}

public struct StrokeStyle: Codable, Hashable, Sendable {
    public var color: DocColor
    public var width: Double

    public init(color: DocColor, width: Double) {
        self.color = color
        self.width = width
    }
}

public struct TextStyle: Codable, Hashable, Sendable {
    public enum Weight: String, Codable, Sendable {
        case regular, medium, bold
    }

    public enum Alignment: String, Codable, Sendable {
        case leading, center, trailing
    }

    /// Font family name; nil = platform default annotation font.
    public var fontFamily: String?
    public var pointSize: Double
    public var weight: Weight
    public var color: DocColor
    /// Optional filled backdrop behind the text run.
    public var backgroundColor: DocColor?
    public var alignment: Alignment

    public init(
        fontFamily: String? = nil,
        pointSize: Double,
        weight: Weight = .regular,
        color: DocColor,
        backgroundColor: DocColor? = nil,
        alignment: Alignment = .leading
    ) {
        self.fontFamily = fontFamily
        self.pointSize = pointSize
        self.weight = weight
        self.color = color
        self.backgroundColor = backgroundColor
        self.alignment = alignment
    }
}
