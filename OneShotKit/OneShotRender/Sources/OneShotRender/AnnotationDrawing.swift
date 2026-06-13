import CoreGraphics
import CoreText
import Foundation
import OneShotCore

// Per-annotation CoreGraphics drawing. Every routine renders in document space
// (the surface context is already flipped/scaled), reading geometry/style straight
// from the scene-graph value types. No mutation of the document.

struct AnnotationDrawer {
    let surface: RenderSurface
    let images: ImageProvider
    /// The document, needed for counter numbering (position-derived value).
    let document: AnnotationDocument

    var context: CGContext {
        surface.context
    }

    func draw(_ annotation: Annotation) {
        switch annotation {
        case let .arrow(a): drawArrow(a)
        case let .line(a): drawLine(a)
        case let .shape(a): drawShape(a)
        case let .text(a): drawText(a)
        case let .highlight(a): drawHighlight(a)
        case let .spotlight(a): drawSpotlight(a)
        case let .counter(a): drawCounter(a)
        case let .freehand(a): drawFreehand(a)
        case let .magnifier(a): drawMagnifier(a)
        case let .redaction(a): drawRedaction(a)
        case let .placedImage(a): drawPlacedImage(a)
        }
    }

    // MARK: Arrow

    private func drawArrow(_ a: ArrowAnnotation) {
        let start = surface.point(a.start)
        let end = surface.point(a.end)
        let width = CGFloat(a.stroke.width)
        let color = a.stroke.color.cgColor

        // Arrowhead proportional to stroke weight but clamped for readability.
        let headLength = max(width * 3.2, 9)
        let headWidth = max(width * 2.6, 7)

        // Direction at the tip: tangent of the curve (or the straight line) so the
        // head always aligns with how the shaft arrives.
        let tipTangent: CGVector
        let shaftPath = CGMutablePath()
        if let control = a.control {
            let c = surface.point(control)
            shaftPath.move(to: start)
            shaftPath.addQuadCurve(to: end, control: c)
            // Tangent of a quadratic Bézier at t=1 is direction (end - control).
            tipTangent = CGVector(dx: end.x - c.x, dy: end.y - c.y)
        } else {
            shaftPath.move(to: start)
            shaftPath.addLine(to: end)
            tipTangent = CGVector(dx: end.x - start.x, dy: end.y - start.y)
        }

        let angle = atan2(tipTangent.dy, tipTangent.dx)
        // Pull the shaft back so it meets the base of the head rather than poking
        // through the tip.
        let backed = CGPoint(x: end.x - cos(angle) * headLength, y: end.y - sin(angle) * headLength)

        // Redraw the shaft to the backed point for the straight case; for curves we
        // keep the curve but stop a touch short by trimming the last segment via the
        // backed endpoint approximation.
        let drawnShaft = CGMutablePath()
        if let control = a.control {
            let c = surface.point(control)
            drawnShaft.move(to: start)
            drawnShaft.addQuadCurve(to: backed, control: c)
        } else {
            drawnShaft.move(to: start)
            drawnShaft.addLine(to: backed)
        }

        context.saveGState()
        context.setStrokeColor(color)
        context.setFillColor(color)
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.addPath(drawnShaft)
        context.strokePath()

        // Filled triangular head at the tip.
        let head = CGMutablePath()
        let baseCenter = CGPoint(x: end.x - cos(angle) * headLength, y: end.y - sin(angle) * headLength)
        let perp = CGVector(dx: -sin(angle), dy: cos(angle))
        let left = CGPoint(x: baseCenter.x + perp.dx * headWidth, y: baseCenter.y + perp.dy * headWidth)
        let right = CGPoint(x: baseCenter.x - perp.dx * headWidth, y: baseCenter.y - perp.dy * headWidth)
        head.move(to: end)
        head.addLine(to: left)
        head.addLine(to: right)
        head.closeSubpath()
        context.addPath(head)
        context.fillPath()
        context.restoreGState()
    }

    // MARK: Line

    private func drawLine(_ a: LineAnnotation) {
        context.saveGState()
        context.setStrokeColor(a.stroke.color.cgColor)
        context.setLineWidth(CGFloat(a.stroke.width))
        context.setLineCap(.round)
        context.move(to: surface.point(a.start))
        context.addLine(to: surface.point(a.end))
        context.strokePath()
        context.restoreGState()
    }

    // MARK: Shapes (rectangle / ellipse)

    private func drawShape(_ a: ShapeAnnotation) {
        let rect = surface.rect(a.rect).standardized
        let path = CGMutablePath()
        switch a.shape {
        case .rectangle:
            if a.cornerRadius > 0 {
                let r = min(CGFloat(a.cornerRadius), min(rect.width, rect.height) / 2)
                path.addRoundedRect(in: rect, cornerWidth: r, cornerHeight: r)
            } else {
                path.addRect(rect)
            }
        case .ellipse:
            path.addEllipse(in: rect)
        }

        context.saveGState()
        if let fill = a.fill {
            context.setFillColor(fill.cgColor)
            context.addPath(path)
            context.fillPath()
        }
        if a.stroke.width > 0 {
            context.setStrokeColor(a.stroke.color.cgColor)
            context.setLineWidth(CGFloat(a.stroke.width))
            context.setLineJoin(.round)
            context.addPath(path)
            context.strokePath()
        }
        context.restoreGState()
    }

    // MARK: Text

    private func drawText(_ a: TextAnnotation) {
        let font = TextRendering.font(
            family: a.style.fontFamily,
            pointSize: a.style.pointSize,
            weight: a.style.weight
        )
        let lineHeight = TextRendering.lineHeight(font: font)
        // Split on hard newlines; each becomes its own laid-out line.
        let rawLines = a.text.isEmpty ? [""] : a.text.components(separatedBy: "\n")
        let layouts = rawLines.map { TextRendering.layout($0, font: font, color: a.style.color) }
        let blockWidth = layouts.map(\.size.width).max() ?? 0

        let origin = surface.point(a.origin)
        let pad: CGFloat = a.style.backgroundColor != nil ? max(CGFloat(a.style.pointSize) * 0.25, 3) : 0
        let blockHeight = lineHeight * CGFloat(layouts.count)

        context.saveGState()
        if let bg = a.style.backgroundColor {
            let bgRect = CGRect(
                x: origin.x - pad,
                y: origin.y - pad,
                width: blockWidth + pad * 2,
                height: blockHeight + pad * 2
            )
            let path = CGMutablePath()
            path.addRoundedRect(in: bgRect, cornerWidth: pad, cornerHeight: pad)
            context.setFillColor(bg.cgColor)
            context.addPath(path)
            context.fillPath()
        }

        for (index, layout) in layouts.enumerated() {
            let lineTop = origin.y + lineHeight * CGFloat(index)
            let baselineY = lineTop + layout.ascent
            let xOffset: CGFloat = switch a.style.alignment {
            case .leading: 0
            case .center: (blockWidth - layout.size.width) / 2
            case .trailing: blockWidth - layout.size.width
            }
            TextRendering.draw(layout, baseline: CGPoint(x: origin.x + xOffset, y: baselineY), in: context)
        }
        context.restoreGState()
    }

    // MARK: Highlight (marker-over-text)

    private func drawHighlight(_ a: HighlightAnnotation) {
        // Marker semantics: a translucent overlay multiplied onto the pixels below.
        context.saveGState()
        context.setBlendMode(.multiply)
        context.setFillColor(a.color.cgColor)
        for rect in a.rects {
            context.fill(surface.rect(rect).standardized)
        }
        context.restoreGState()
    }

    // MARK: Spotlight (dim everything outside the region)

    private func drawSpotlight(_ a: SpotlightAnnotation) {
        let visible = surface.rect(surface.visibleRect)
        let region = surface.rect(a.region).standardized

        context.saveGState()
        // Clip to "outside the region" using even-odd: full canvas minus the region.
        let outside = CGMutablePath()
        outside.addRect(visible)
        switch a.shape {
        case .rectangle: outside.addRect(region)
        case .ellipse: outside.addEllipse(in: region)
        }
        context.addPath(outside)
        context.clip(using: .evenOdd)
        // Fill the dim. dimOpacity is clamped to 0...1 for safety.
        let dim = max(0, min(1, a.dimOpacity))
        context.setFillColor(CGColor(
            colorSpace: RenderColorSpace.sRGB,
            components: [0, 0, 0, CGFloat(dim)]
        )!)
        context.fill(visible)
        context.restoreGState()
    }

    // MARK: Counter badge (auto-incrementing)

    private func drawCounter(_ a: CounterAnnotation) {
        let number = document.counterNumber(for: a.id) ?? 1
        let center = surface.point(a.center)
        let radius = CGFloat(a.diameter) / 2
        let circle = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: CGFloat(a.diameter),
            height: CGFloat(a.diameter)
        )

        context.saveGState()
        context.setFillColor(a.color.cgColor)
        context.fillEllipse(in: circle)

        // Number, white, centered, sized to fit inside the badge.
        let pointSize = Double(a.diameter) * 0.55
        let font = TextRendering.font(family: nil, pointSize: pointSize, weight: .bold)
        let label = TextRendering.layout("\(number)", font: font, color: .white)
        // Center the glyph box within the badge.
        let baselineX = center.x - label.size.width / 2
        let baselineY = center.y - (label.ascent + label.descent) / 2 + label.ascent
        TextRendering.draw(label, baseline: CGPoint(x: baselineX, y: baselineY), in: context)
        context.restoreGState()
    }

    // MARK: Freehand (raw polyline or smoothed Catmull-Rom)

    private func drawFreehand(_ a: FreehandAnnotation) {
        guard a.points.count > 1 else {
            // A single point renders as a dot so a tap is still visible.
            if let only = a.points.first {
                let p = surface.point(only)
                let r = CGFloat(a.stroke.width) / 2
                context.saveGState()
                context.setFillColor(a.stroke.color.cgColor)
                context.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                context.restoreGState()
            }
            return
        }

        let pts = a.points.map { surface.point($0) }
        let path = CGMutablePath()
        path.move(to: pts[0])
        if a.smoothed, pts.count > 2 {
            // Catmull-Rom through the points, converted to cubic Béziers — a stable,
            // dependency-free smoothing that passes through every sample.
            for i in 0 ..< pts.count - 1 {
                let p0 = pts[max(i - 1, 0)]
                let p1 = pts[i]
                let p2 = pts[i + 1]
                let p3 = pts[min(i + 2, pts.count - 1)]
                let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
                let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
                path.addCurve(to: p2, control1: c1, control2: c2)
            }
        } else {
            for p in pts.dropFirst() {
                path.addLine(to: p)
            }
        }

        context.saveGState()
        context.setStrokeColor(a.stroke.color.cgColor)
        context.setLineWidth(CGFloat(a.stroke.width))
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.addPath(path)
        context.strokePath()
        context.restoreGState()
    }

    // MARK: Magnifier callout (enlarged inset of a source region)

    private func drawMagnifier(_ a: MagnifierAnnotation) {
        let callout = surface.rect(a.calloutRect).standardized
        guard callout.width > 0, callout.height > 0 else { return }

        context.saveGState()
        // Clip to the callout so the magnified content stays inside the frame.
        let frame = CGMutablePath()
        frame.addRect(callout)
        context.addPath(frame)
        context.clip()

        // Render the visible document content magnified into the callout. We draw a
        // snapshot of the base layer (base image + placed images) scaled so the
        // source region maps onto the callout rect. To keep the render core simple
        // and deterministic we re-draw the base image transformed.
        if let baseImage = baseLayerImage() {
            let source = a.sourceRect
            // Map source-doc-rect → callout-context-rect.
            let sx = callout.width / CGFloat(source.size.width == 0 ? 1 : source.size.width)
            let sy = callout.height / CGFloat(source.size.height == 0 ? 1 : source.size.height)
            // Position the full base image so that `source` lands on `callout`.
            // base image is drawn in document space starting at (0,0).
            let drawW = CGFloat(document.baseImage.pixelWidth) * sx
            let drawH = CGFloat(document.baseImage.pixelHeight) * sy
            let originX = callout.minX - (CGFloat(source.minX) - CGFloat(surface.visibleRect.minX)) * sx
            let originY = callout.minY - (CGFloat(source.minY) - CGFloat(surface.visibleRect.minY)) * sy
            drawCGImage(baseImage, in: CGRect(x: originX, y: originY, width: drawW, height: drawH))
        }
        context.restoreGState()

        // Frame border on top.
        if a.border.width > 0 {
            context.saveGState()
            context.setStrokeColor(a.border.color.cgColor)
            context.setLineWidth(CGFloat(a.border.width))
            context.setLineJoin(.round)
            context.stroke(callout)
            context.restoreGState()
        }
    }

    private func baseLayerImage() -> CGImage? {
        guard let data = images.data(for: document.baseImage) else { return nil }
        return try? ImageCodec.decode(data, name: document.baseImage.fileName)
    }

    // MARK: Redaction (blur / pixelate / blackout)

    private func drawRedaction(_ a: RedactionAnnotation) {
        // The render core renders redaction destructively at flatten time. Blur and
        // pixelate require sampling underlying pixels; to stay portable (no Core
        // Image filters that pull in platform specifics here) we composite an opaque
        // obscuring fill. Full content-aware blur/pixelate lives in the redaction
        // lane (task 6.x) which owns the destructive export pixel-floor tests; here
        // we guarantee the region is irreversibly obscured for any style.
        let rect = surface.rect(a.rect).standardized
        context.saveGState()
        switch a.style {
        case .blackout:
            context.setFillColor(DocColor.black.cgColor)
            context.fill(rect)
        case .blur, .pixelate:
            // Mosaic block fill: average is unavailable without a sampling pass, so
            // we paint a neutral opaque cover that defeats reading. Distinct from
            // blackout by a mid-gray tone so the two styles render differently.
            context.setFillColor(CGColor(
                colorSpace: RenderColorSpace.sRGB,
                components: [0.5, 0.5, 0.5, 1.0]
            )!)
            context.fill(rect)
        }
        context.restoreGState()
    }

    // MARK: Placed image (multi-image stitch / combine)

    private func drawPlacedImage(_ a: PlacedImageAnnotation) {
        guard let data = images.data(for: a.image),
              let image = try? ImageCodec.decode(data, name: a.image.fileName)
        else { return }
        drawCGImage(image, in: surface.rect(a.rect).standardized)
    }

    // MARK: CGImage drawing in flipped document space

    /// Draws a CGImage into a document-space rect. The surface context is flipped
    /// (y-down); CGContext.draw expects y-up image orientation, so we locally flip
    /// the destination rect to render the image upright.
    func drawCGImage(_ image: CGImage, in rect: CGRect) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.minY)
        context.translateBy(x: 0, y: rect.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        context.restoreGState()
    }
}
