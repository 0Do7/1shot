import CoreGraphics
import Foundation
import OneShotCore

// Text-aware redaction MODEL helper (task 6.3, spec:redaction "Text-aware blur and
// erase" + "Per-instance toggles" + "No-text and partial-detection behavior").
//
// COVERAGE NOTE: this helper covers BOTH branches of "Text-aware blur and erase".
// The "erase" branch — filling each text region to BLEND with the surrounding
// background with no legible residue — is now representable: `RedactionAnnotation
// .Style.erase` is a content-aware background-matching fill (spike S1 diffusion
// fill), rasterized destructively at export like the obscuring styles. So
// `style: .erase` produces one toggleable erase redaction per detected instance.
//
// SCOPE: this is the pure model layer only. It turns *already-detected* text-box
// geometry into re-editable `RedactionAnnotation` objects (each marked
// `detectedText`, so the app's per-instance toggle UI can tell detected boxes from
// manual regions). The detection pass itself and the one-click / per-instance
// toggle UI are app-layer concerns and live OUTSIDE this package.
//
// OCR BOUNDARY (deliberate): the shipping OneShotRender target is OCR-free — it
// must NOT depend on OneShotOCR (that is a TEST-only dependency, see Package.swift).
// So this helper takes a LOCAL lightweight `TextBox` (image-space pixels, top-left
// origin — the document convention) and NEVER an OCR type. The app is responsible
// for mapping its detector's output (e.g. OneShotOCR `NormalizedRect`, which is
// normalized + bottom-left origin) into `TextBox` values in image-pixel space.
//
// Portability: CoreGraphics + Foundation only (design D2).

/// One detected text instance's geometry, in image-space pixels with the document
/// coordinate convention (origin top-left, y down, units = base-image pixels).
///
/// Local on purpose — see the OCR BOUNDARY note above. Carrying the source `id`
/// lets the caller keep a stable identity per instance across a re-detection or a
/// toggle so the produced redaction's `id` is deterministic.
public struct TextBox: Hashable, Sendable {
    /// Stable identity for this detected instance (so per-instance toggling and the
    /// produced redaction id are deterministic across passes). The app supplies it.
    public var id: UUID
    /// The instance's bounding rect in image-pixel space (top-left origin).
    public var rect: DocRect

    public init(id: UUID = UUID(), rect: DocRect) {
        self.id = id
        self.rect = rect
    }
}

/// The outcome of producing text-aware redactions. A typed result so "no text was
/// detected" is an EXPLICIT state the app can message honestly (product law:
/// honest failure — never silently do nothing), distinct from "produced N".
public struct TextAwareRedactionResult: Hashable, Sendable {
    /// One re-editable redaction per *usable* detected box, in input order. Empty
    /// when no boxes were usable.
    public var redactions: [RedactionAnnotation]
    /// True when no usable text box was supplied — the app states "no text detected"
    /// and creates nothing (rather than silently producing an empty document change).
    public var foundNoText: Bool

    public init(redactions: [RedactionAnnotation], foundNoText: Bool) {
        self.redactions = redactions
        self.foundNoText = foundNoText
    }
}

/// Pure model helper: detected text-box geometry -> re-editable redaction objects.
public enum TextAwareRedaction {
    /// Padding (image pixels) grown around each detected box before redacting, so a
    /// tight glyph-hugging detector box does not leave a legible rim of ascenders /
    /// descenders just outside it. Small and symmetric; the region is clamped to the
    /// image afterwards.
    public static let defaultPadding: Double = 2

    /// Produces one toggleable `RedactionAnnotation` per detected text box.
    ///
    /// Each produced redaction:
    /// - is marked `detectedText = true` so the app can distinguish detected
    ///   instances from manual regions for per-instance toggling;
    /// - takes the box's `id` (so identity is stable across re-detection / toggle);
    /// - is padded by `padding` and clamped to `imageSize` (image-pixel bounds);
    /// - is skipped when its clamped rect is degenerate (< 1 px on a side) — a
    ///   zero-area box can never obscure anything, so emitting it would be dishonest.
    ///
    /// - Parameters:
    ///   - boxes: detected text instances in image-pixel space (NOT OCR types).
    ///   - imageSize: the base image size in pixels, used to clamp each region.
    ///   - style: the redaction style to apply to every instance — any
    ///     `RedactionAnnotation.Style` (blur/pixelate/blackout, or `.erase` for the
    ///     spec's "Text-aware erase blends": a background-matching fill with no
    ///     legible residue, synthesized in the renderer per spike S1).
    ///   - strength: blur sigma / pixelate cell (base-image px). The renderer floors
    ///     it to the OCR-defeat minimum (task 6.1), so a low value still obscures.
    ///   - padding: pixels grown around each box (default `defaultPadding`).
    /// - Returns: a typed result whose `foundNoText` flag makes the empty case
    ///   explicit (honest failure).
    public static func redactions(
        for boxes: [TextBox],
        imageSize: DocSize,
        style: RedactionAnnotation.Style,
        strength: Double = 12,
        padding: Double = defaultPadding
    ) -> TextAwareRedactionResult {
        let produced = boxes.compactMap { box -> RedactionAnnotation? in
            guard let region = clamp(box.rect, padding: padding, to: imageSize) else { return nil }
            return RedactionAnnotation(
                id: box.id,
                rect: region,
                style: style,
                strength: strength,
                detectedText: true
            )
        }
        return TextAwareRedactionResult(redactions: produced, foundNoText: produced.isEmpty)
    }

    /// Convenience for the "redact ALL detected text in one action" command
    /// (spec scenario: "One click redacts all text"). Identical to
    /// `redactions(for:imageSize:style:strength:padding:)` — every usable box gets
    /// its own redaction — but named for the bulk call site.
    public static func allText(
        in boxes: [TextBox],
        imageSize: DocSize,
        style: RedactionAnnotation.Style,
        strength: Double = 12,
        padding: Double = defaultPadding
    ) -> TextAwareRedactionResult {
        redactions(for: boxes, imageSize: imageSize, style: style, strength: strength, padding: padding)
    }

    // MARK: Geometry

    /// Grows `rect` by `padding` on every side, then clamps it to the image bounds
    /// (`0..width`, `0..height`). Returns `nil` when the clamped rect is degenerate
    /// (< 1 px on either axis) so the caller drops it.
    private static func clamp(_ rect: DocRect, padding: Double, to imageSize: DocSize) -> DocRect? {
        let minX = max(0, rect.minX - padding)
        let minY = max(0, rect.minY - padding)
        let maxX = min(imageSize.width, rect.maxX + padding)
        let maxY = min(imageSize.height, rect.maxY + padding)
        let width = maxX - minX
        let height = maxY - minY
        guard width >= 1, height >= 1 else { return nil }
        return DocRect(x: minX, y: minY, width: width, height: height)
    }
}
