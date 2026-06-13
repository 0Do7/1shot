import CoreGraphics
import CoreText
import Foundation
import OneShotCore

// Text via CoreText only (the portability law forbids AppKit; CoreText is
// allowed). We build CTFont/CTLine directly so there is no NSAttributedString /
// NSFont dependency and the layout is deterministic for goldens.

enum TextRendering {
    /// A laid-out, measured single style run ready to draw. Document-space metrics.
    struct Layout {
        let line: CTLine
        /// Tight typographic size of the text (ascent+descent tall, advance wide).
        let size: CGSize
        let ascent: CGFloat
        let descent: CGFloat
    }

    static func font(family: String?, pointSize: Double, weight: TextStyle.Weight) -> CTFont {
        let size = CGFloat(pointSize)
        if let family, !family.isEmpty {
            // Named family: build a descriptor with the requested traits.
            let traits: [CFString: Any] = [
                kCTFontWeightTrait: weightValue(weight),
            ]
            let attributes: [CFString: Any] = [
                kCTFontFamilyNameAttribute: family,
                kCTFontTraitsAttribute: traits,
            ]
            let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
            return CTFontCreateWithFontDescriptor(descriptor, size, nil)
        }
        // Default annotation font: the system UI font at the requested weight.
        // CTFontCreateUIFontForLanguage gives a stable, present-everywhere face.
        let base = CTFontCreateUIFontForLanguage(.system, size, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let traits: [CFString: Any] = [kCTFontWeightTrait: weightValue(weight)]
        let descriptor = CTFontDescriptorCreateWithAttributes([
            kCTFontTraitsAttribute: traits,
        ] as CFDictionary)
        return CTFontCreateCopyWithAttributes(base, size, nil, descriptor)
    }

    private static func weightValue(_ weight: TextStyle.Weight) -> CGFloat {
        switch weight {
        case .regular: 0.0
        case .medium: 0.23
        case .bold: 0.4
        }
    }

    /// Lays out a single line of text in the given style. Multi-line text is split
    /// by the caller (see `lines`).
    static func layout(_ string: String, font: CTFont, color: DocColor) -> Layout {
        // CoreText attribute keys (kCTFontAttributeName / kCTForegroundColorAttributeName)
        // rather than NSAttributedString.Key.font — the latter lives in AppKit/UIKit
        // and would violate the portability law.
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: color.cgColor,
        ]
        let attributed = CFAttributedStringCreate(
            kCFAllocatorDefault,
            string as CFString,
            attributes as CFDictionary
        )!
        let line = CTLineCreateWithAttributedString(attributed)
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        return Layout(
            line: line,
            size: CGSize(width: CGFloat(width), height: ascent + descent),
            ascent: ascent,
            descent: descent
        )
    }

    static func lineHeight(font: CTFont) -> CGFloat {
        CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)
    }

    /// Draws a single CTLine at a document-space baseline origin. The context is
    /// in flipped (y-down) document space, so we locally flip the text matrix back
    /// to upright while keeping positioning in document coordinates.
    static func draw(_ layout: Layout, baseline: CGPoint, in context: CGContext) {
        context.saveGState()
        // CoreText draws glyphs in y-up space; our context is y-down. Flip around
        // the baseline so glyphs render upright.
        context.translateBy(x: baseline.x, y: baseline.y)
        context.scaleBy(x: 1, y: -1)
        context.textPosition = .zero
        CTLineDraw(layout.line, context)
        context.restoreGState()
    }
}
