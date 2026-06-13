import CoreGraphics
import Foundation
import ImageIO
import OneShotCore
import UniformTypeIdentifiers
@testable import OneShotRender

// Canonical AnnotationDocuments — one per annotation type plus a combined scene —
// used by the golden suite. The base image is generated deterministically in code
// (no external asset dependency) so the whole suite is self-contained and
// reproducible.

enum Canonical {
    static let baseWidth = 320
    static let baseHeight = 200
    static let baseName = "base.png"

    /// A deterministic synthetic base image: a soft horizontal gradient with a
    /// checkerboard band and a few dark "text-line" bars (so highlight / spotlight /
    /// magnifier have meaningful content underneath). Generated pixel-for-pixel the
    /// same on every run.
    static func baseImagePNG() -> Data {
        let width = baseWidth, height = baseHeight
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        // Vertical gradient backdrop (drawn manually to avoid gradient AA variance).
        for y in 0 ..< height {
            let ty = CGFloat(y) / CGFloat(height)
            ctx.setFillColor(red: 0.16 + 0.10 * ty, green: 0.20 + 0.18 * ty, blue: 0.30 + 0.30 * ty, alpha: 1)
            ctx.fill(CGRect(x: 0, y: y, width: width, height: 1))
        }
        // Checkerboard band across the middle.
        let cell = 16
        for gy in stride(from: 80, to: 140, by: cell) {
            for gx in stride(from: 0, to: width, by: cell) {
                let on = ((gx / cell) + (gy / cell)) % 2 == 0
                ctx.setFillColor(red: on ? 0.85 : 0.35, green: on ? 0.85 : 0.35, blue: on ? 0.88 : 0.40, alpha: 1)
                ctx.fill(CGRect(x: gx, y: gy, width: cell, height: cell))
            }
        }
        // Dark "text-line" bars near the top (highlight/redaction targets).
        ctx.setFillColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1)
        for line in 0 ..< 3 {
            ctx.fill(CGRect(x: 24, y: 24 + line * 16, width: 240, height: 8))
        }
        let image = ctx.makeImage()!
        let out = NSMutableData()
        let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, nil)
        _ = CGImageDestinationFinalize(dest)
        return out as Data
    }

    static func provider() -> ImageProvider {
        ImageProvider(images: [baseName: baseImagePNG()])
    }

    static func baseRef(scale: Double = 1) -> ImageReference {
        ImageReference(fileName: baseName, pixelWidth: baseWidth, pixelHeight: baseHeight, scale: scale)
    }

    static func document(_ annotations: [Annotation], scale: Double = 1) -> AnnotationDocument {
        AnnotationDocument(baseImage: baseRef(scale: scale), annotations: annotations)
    }

    /// Deterministic, stable UUIDs so re-runs (and counter ordering) never vary.
    static func uuid(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
    }

    static let red = DocColor(red: 0.90, green: 0.16, blue: 0.18)
    static let blue = DocColor(red: 0.16, green: 0.42, blue: 0.92)
    static let green = DocColor(red: 0.18, green: 0.70, blue: 0.36)
    static let yellow = DocColor(red: 1.0, green: 0.92, blue: 0.20, alpha: 0.55)

    // MARK: One document per annotation type

    static var arrow: AnnotationDocument {
        document([
            .arrow(ArrowAnnotation(
                id: uuid(1),
                start: DocPoint(x: 40, y: 160),
                end: DocPoint(x: 260, y: 60),
                stroke: StrokeStyle(color: red, width: 6)
            )),
        ])
    }

    static var curvedArrow: AnnotationDocument {
        document([
            .arrow(ArrowAnnotation(
                id: uuid(2),
                start: DocPoint(x: 40, y: 60),
                end: DocPoint(x: 270, y: 150),
                control: DocPoint(x: 80, y: 180),
                stroke: StrokeStyle(color: blue, width: 6)
            )),
        ])
    }

    static var line: AnnotationDocument {
        document([
            .line(LineAnnotation(
                id: uuid(3),
                start: DocPoint(x: 30, y: 100),
                end: DocPoint(x: 290, y: 120),
                stroke: StrokeStyle(color: green, width: 5)
            )),
        ])
    }

    static var rectangle: AnnotationDocument {
        document([
            .shape(ShapeAnnotation(
                id: uuid(4),
                shape: .rectangle,
                rect: DocRect(x: 50, y: 50, width: 160, height: 90),
                stroke: StrokeStyle(color: red, width: 5),
                fill: DocColor(red: 0.95, green: 0.85, blue: 0.20, alpha: 0.3),
                cornerRadius: 12
            )),
        ])
    }

    static var ellipse: AnnotationDocument {
        document([
            .shape(ShapeAnnotation(
                id: uuid(5),
                shape: .ellipse,
                rect: DocRect(x: 60, y: 40, width: 180, height: 110),
                stroke: StrokeStyle(color: blue, width: 5),
                fill: nil
            )),
        ])
    }

    static var text: AnnotationDocument {
        document([
            .text(TextAnnotation(
                id: uuid(6),
                text: "Hello 1shot\nsecond line",
                origin: DocPoint(x: 30, y: 60),
                style: TextStyle(
                    pointSize: 28,
                    weight: .bold,
                    color: .white,
                    backgroundColor: DocColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 0.85)
                )
            )),
        ])
    }

    static var highlight: AnnotationDocument {
        document([
            .highlight(HighlightAnnotation(
                id: uuid(7),
                mode: .snapped,
                rects: [
                    DocRect(x: 22, y: 22, width: 244, height: 12),
                    DocRect(x: 22, y: 38, width: 244, height: 12),
                    DocRect(x: 22, y: 54, width: 244, height: 12),
                ],
                color: yellow
            )),
        ])
    }

    static var spotlight: AnnotationDocument {
        document([
            .spotlight(SpotlightAnnotation(
                id: uuid(8),
                region: DocRect(x: 90, y: 70, width: 140, height: 90),
                shape: .ellipse,
                dimOpacity: 0.65
            )),
        ])
    }

    static var counters: AnnotationDocument {
        document([
            .counter(CounterAnnotation(id: uuid(9), center: DocPoint(x: 70, y: 90), color: red)),
            .counter(CounterAnnotation(id: uuid(10), center: DocPoint(x: 160, y: 90), diameter: 36, color: blue)),
            .counter(CounterAnnotation(id: uuid(11), center: DocPoint(x: 250, y: 90), color: green)),
        ])
    }

    static var freehand: AnnotationDocument {
        var pts: [DocPoint] = []
        for i in 0 ... 40 {
            let x = 30 + Double(i) * 6
            let y = 100 + 40 * sin(Double(i) / 4)
            pts.append(DocPoint(x: x, y: y))
        }
        return document([
            .freehand(FreehandAnnotation(
                id: uuid(12),
                points: pts,
                stroke: StrokeStyle(color: red, width: 5),
                smoothed: true
            )),
        ])
    }

    static var magnifier: AnnotationDocument {
        document([
            .magnifier(MagnifierAnnotation(
                id: uuid(13),
                sourceRect: DocRect(x: 30, y: 80, width: 60, height: 40),
                calloutRect: DocRect(x: 150, y: 120, width: 150, height: 70),
                border: StrokeStyle(color: .white, width: 4)
            )),
        ])
    }

    static var redaction: AnnotationDocument {
        // One of each style over the three dark "text-line" bars + the checkerboard,
        // so the DRAFT golden captures REAL destructive blur / pixelate / blackout
        // (task 6.1) rather than the old flat-fill placeholder.
        document([
            .redaction(RedactionAnnotation(
                id: uuid(14),
                rect: DocRect(x: 22, y: 22, width: 244, height: 12),
                style: .blackout
            )),
            .redaction(RedactionAnnotation(
                id: uuid(15),
                rect: DocRect(x: 22, y: 54, width: 244, height: 12),
                style: .blur,
                strength: 16
            )),
            .redaction(RedactionAnnotation(
                id: uuid(16),
                rect: DocRect(x: 40, y: 86, width: 160, height: 48),
                style: .pixelate,
                strength: 16
            )),
        ])
    }

    /// Combined scene exercising z-order and many types at once.
    static var combined: AnnotationDocument {
        document([
            .shape(ShapeAnnotation(
                id: uuid(20),
                shape: .rectangle,
                rect: DocRect(x: 40, y: 40, width: 180, height: 110),
                stroke: StrokeStyle(color: blue, width: 4),
                fill: DocColor(red: 1, green: 1, blue: 1, alpha: 0.12),
                cornerRadius: 10
            )),
            .highlight(HighlightAnnotation(
                id: uuid(21),
                mode: .snapped,
                rects: [DocRect(x: 24, y: 24, width: 240, height: 8)],
                color: yellow
            )),
            .arrow(ArrowAnnotation(
                id: uuid(22),
                start: DocPoint(x: 30, y: 180),
                end: DocPoint(x: 200, y: 110),
                stroke: StrokeStyle(color: red, width: 6)
            )),
            .counter(CounterAnnotation(id: uuid(23), center: DocPoint(x: 250, y: 50), color: red)),
            .counter(CounterAnnotation(id: uuid(24), center: DocPoint(x: 250, y: 100), color: red)),
            .text(TextAnnotation(
                id: uuid(25),
                text: "Step here",
                origin: DocPoint(x: 60, y: 60),
                style: TextStyle(pointSize: 22, weight: .medium, color: .white)
            )),
        ])
    }
}
