import CoreGraphics
import CoreImage
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
            let controlPoint = surface.point(control)
            shaftPath.move(to: start)
            shaftPath.addQuadCurve(to: end, control: controlPoint)
            // Tangent of a quadratic Bézier at t=1 is direction (end - control).
            tipTangent = CGVector(dx: end.x - controlPoint.x, dy: end.y - controlPoint.y)
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
            let controlPoint = surface.point(control)
            drawnShaft.move(to: start)
            drawnShaft.addQuadCurve(to: backed, control: controlPoint)
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
                let radius = min(CGFloat(a.cornerRadius), min(rect.width, rect.height) / 2)
                path.addRoundedRect(in: rect, cornerWidth: radius, cornerHeight: radius)
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
                let dot = surface.point(only)
                let radius = CGFloat(a.stroke.width) / 2
                context.saveGState()
                context.setFillColor(a.stroke.color.cgColor)
                context.fillEllipse(in: CGRect(
                    x: dot.x - radius, y: dot.y - radius, width: radius * 2, height: radius * 2
                ))
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
            for point in pts.dropFirst() {
                path.addLine(to: point)
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

        // Render the visible document content magnified into the callout. We sample
        // the ALREADY-RENDERED context (base image + every lower-z annotation,
        // including destructive redactions) — never a pristine re-decode of the base
        // image — so a magnifier over a redacted region cannot re-expose the original
        // pixels (spec:redaction "Hardened, non-reversible export"). `makeImage()`
        // returns the current canvas as one image covering the whole visible rect.
        if let snapshot = context.makeImage() {
            let source = surface.rect(a.sourceRect).standardized
            // Scale that maps the source region onto the callout. Guard zero-size.
            let sx = callout.width / (source.width == 0 ? 1 : source.width)
            let sy = callout.height / (source.height == 0 ? 1 : source.height)
            // The snapshot covers the whole visible rect in context space; place and
            // scale it so the source sub-rect lands exactly on the callout.
            let visible = surface.rect(surface.visibleRect)
            let drawRect = CGRect(
                x: callout.minX - source.minX * sx,
                y: callout.minY - source.minY * sy,
                width: visible.width * sx,
                height: visible.height * sy
            )
            // The redaction below sampled the same makeImage() snapshot, so the magnified
            // content already carries burned-in redactions. 1:1 nearest-neighbour keeps the
            // magnified pixels honest (no resampling can synthesize readable detail).
            context.interpolationQuality = .none
            drawCGImage(snapshot, in: drawRect)
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
}

// MARK: Destructive redaction + image compositing

/// Split into an extension to keep each declaration cohesive (and the primary type
/// body within the strict length budget); identical behaviour, same file.
extension AnnotationDrawer {
    // MARK: Redaction (blur / pixelate / blackout) — destructive (task 6.1)

    func drawRedaction(_ a: RedactionAnnotation) {
        // Two-pass, z-order-honest destructive obscuring (spec:redaction "Hardened,
        // non-reversible export"): redaction reads the pixels BENEATH it (base +
        // every lower annotation already drawn into this context), computes a real
        // blur / pixelate / blackout patch, and overwrites the region irreversibly.
        // Annotations drawn AFTER this one still composite on top, so z-order holds.
        let userRect = surface.rect(a.rect).standardized
        guard userRect.width > 0, userRect.height > 0 else { return }

        // Convert the document-space rect into OUTPUT-pixel space (bottom-left
        // origin — the orientation `context.makeImage()` returns), clamped to the
        // canvas so we never sample outside the bitmap.
        let scale = surface.scale
        let canvas = CGRect(x: 0, y: 0, width: surface.pixelWidth, height: surface.pixelHeight)
        let pixelRect = CGRect(
            x: userRect.minX * scale,
            y: CGFloat(surface.pixelHeight) - userRect.maxY * scale,
            width: userRect.width * scale,
            height: userRect.height * scale
        ).intersection(canvas).integral
        guard pixelRect.width >= 1, pixelRect.height >= 1 else { return }

        // Snapshot what is currently beneath this redaction (everything drawn so far).
        guard let beneath = context.makeImage(),
              let patch = RedactionRenderer.obscuredPatch(
                  of: beneath,
                  region: pixelRect,
                  style: a.style,
                  strength: a.strength,
                  scale: scale
              )
        else { return }

        // Draw the obscuring patch back over exactly its region. We bypass the
        // document-space CTM and draw straight in device pixels: save the current
        // transform, reset to identity (device space), copy in opaque pixels, restore.
        context.saveGState()
        context.concatenate(context.ctm.inverted())
        context.setBlendMode(.copy) // destructive: replace, do not blend over
        context.interpolationQuality = .none // 1:1 pixel copy, no resampling
        context.draw(patch, in: pixelRect)
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
