import CoreGraphics
import Foundation
import ImageIO
import OneShotCore
import OneShotOCR
import Testing
@testable import OneShotRender

// Text-aware redaction MODEL suite (task 6.3, specs/redaction/spec.md).
// Each `#### Scenario:` that the model layer can satisfy maps to a `test_<camel>`
// test below. The per-instance toggle / one-click UI itself is app-layer (out of
// this package), so we test the toggleable MODEL: detected boxes -> re-editable
// redaction objects, and that those objects actually obscure on flatten (reusing
// the real Vision OCR-defeat harness).

// MARK: - Helpers

private enum TextAwareSupport {
    /// Maps the synthetic fixture's text-line geometry to `TextBox` inputs. The
    /// fixture draws four crisp lines starting at `topY` going down by `lineGap`,
    /// in CG bottom-left coords; we convert to the document top-left convention.
    /// Stable ids per line index so produced redaction ids are deterministic.
    static func fixtureLineBoxes() -> [TextBox] {
        let topY = CGFloat(RedactionFixtures.height) - 40
        let lineGap: CGFloat = 34
        return (0 ..< RedactionFixtures.strings.count).map { i in
            // Each line baseline in CG space; build a generous box around it then
            // flip to top-left (docY = imageHeight - cgYTop).
            let baselineCG = topY - CGFloat(i) * lineGap
            let cgTop = baselineCG + 14 // ascent headroom above the baseline
            let docTop = Double(RedactionFixtures.height) - Double(cgTop)
            return TextBox(
                id: Canonical.uuid(6300 + i),
                rect: DocRect(x: 24, y: docTop, width: 432, height: 26)
            )
        }
    }

    static func imageSize() -> DocSize {
        DocSize(width: Double(RedactionFixtures.width), height: Double(RedactionFixtures.height))
    }

    static func decode(_ data: Data) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    static func crop(_ image: CGImage, docRect: DocRect) -> CGImage? {
        let rect = CGRect(x: docRect.minX, y: docRect.minY, width: docRect.size.width, height: docRect.size.height)
        return image.cropping(to: rect.integral)
    }

    /// All recognized strings (joined, lowercased) the real Vision recognizer reads.
    static func recognizedText(in image: CGImage) -> String {
        let recognizer = VisionTextRecognizer()
        let result = (try? recognizer.recognizeText(in: image, options: .default)) ?? RecognizedText()
        return result.lines.map(\.text).joined(separator: " ").lowercased()
    }

    /// True when any original fixture string (or a ≥6-char fragment) survives.
    static func leaksAnyOriginalString(_ recognized: String) -> Bool {
        for original in RedactionFixtures.strings {
            let needle = original.lowercased()
            if recognized.contains(needle) { return true }
            let fragments = needle.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            for fragment in fragments where fragment.count >= 6 {
                if recognized.contains(fragment) { return true }
            }
        }
        return false
    }
}

// MARK: - spec: Text-aware blur and erase

// NOTE: spec scenario "Text-aware erase blends" is now covered end-to-end. The
// model layer here produces one `.erase` redaction per detected instance (see
// `oneClickErasesAllText`); the actual background-matching fill (spike S1 diffusion
// fill, no legible residue) is rendered in `RedactionRenderer` and asserted by
// `textAwareEraseBlends` in RedactionTests over a real Vision OCR-defeat + a
// background-continuity check. `redactionStylePassesThrough` below verifies style
// pass-through for the obscuring styles.

/// #### Scenario: One click redacts all text
@Test func oneClickRedactsAllText() {
    let boxes = TextAwareSupport.fixtureLineBoxes()
    let result = TextAwareRedaction.allText(
        in: boxes,
        imageSize: TextAwareSupport.imageSize(),
        style: .blur
    )
    // One redaction object per detected instance, in one action.
    #expect(result.redactions.count == boxes.count)
    #expect(!result.foundNoText)
    // Every produced redaction is a re-editable, detected-text object. (Hoisted out
    // of #expect: the macro's rethrows analysis rejects a bare key-path predicate.)
    let allDetected = result.redactions.allSatisfy(\.detectedText)
    #expect(allDetected)
    #expect(result.redactions.allSatisfy { $0.style == .blur })
    // Identity is preserved per instance (deterministic ids from the boxes).
    #expect(result.redactions.map(\.id) == boxes.map(\.id))
}

/// #### Scenario: Text-aware erase blends (model half)
/// One-click text-aware ERASE produces one `.erase` redaction per detected instance.
/// The fill/blend itself is asserted in RedactionTests.textAwareEraseBlends.
@Test func oneClickErasesAllText() {
    let boxes = TextAwareSupport.fixtureLineBoxes()
    let result = TextAwareRedaction.allText(
        in: boxes,
        imageSize: TextAwareSupport.imageSize(),
        style: .erase
    )
    #expect(result.redactions.count == boxes.count)
    #expect(!result.foundNoText)
    #expect(result.redactions.allSatisfy { $0.style == .erase })
    let allDetected = result.redactions.allSatisfy(\.detectedText)
    #expect(allDetected)
    #expect(result.redactions.map(\.id) == boxes.map(\.id))
}

/// Style pass-through: the helper emits exactly the chosen style for every instance.
@Test func redactionStylePassesThrough() {
    let boxes = TextAwareSupport.fixtureLineBoxes()
    let result = TextAwareRedaction.allText(
        in: boxes,
        imageSize: TextAwareSupport.imageSize(),
        style: .blackout
    )
    #expect(result.redactions.count == boxes.count)
    #expect(result.redactions.allSatisfy { $0.style == .blackout })
}

// MARK: - spec: No-text and partial-detection behavior

/// #### Scenario: No text found
@Test func noTextFound() {
    // No detected boxes -> explicit empty result (honest failure), nothing created.
    let result = TextAwareRedaction.allText(
        in: [],
        imageSize: TextAwareSupport.imageSize(),
        style: .blur
    )
    #expect(result.redactions.isEmpty)
    #expect(result.foundNoText, "empty input must be an EXPLICIT no-text state, not a silent no-op")
}

/// Degenerate boxes (zero area, or wholly outside the image) cannot obscure and so
/// are dropped — and a result of only degenerate boxes is the honest no-text state.
@Test func degenerateBoxesAreDropped() {
    let size = TextAwareSupport.imageSize()
    let boxes = [
        TextBox(id: Canonical.uuid(6390), rect: DocRect(x: 10, y: 10, width: 0, height: 20)), // zero width
        TextBox(id: Canonical.uuid(6391), rect: DocRect(x: -50, y: -50, width: 10, height: 10)), // off-image
    ]
    let result = TextAwareRedaction.redactions(for: boxes, imageSize: size, style: .blur, padding: 0)
    #expect(result.redactions.isEmpty)
    #expect(result.foundNoText)
}

/// #### Scenario: Manual region supplements detection
@Test func manualRegionSupplementsDetection() throws {
    // A text-aware set PLUS a manual redaction coexist in one document and BOTH
    // harden on export (manual region is NOT detectedText; text-aware ones are).
    let provider = RedactionFixtures.provider()
    let boxes = TextAwareSupport.fixtureLineBoxes()
    let textAware = TextAwareRedaction.allText(
        in: boxes,
        imageSize: TextAwareSupport.imageSize(),
        style: .blur
    )
    let manual = RedactionAnnotation(
        id: Canonical.uuid(6395),
        rect: DocRect(x: 24, y: 30, width: 200, height: 24),
        style: .blackout,
        detectedText: false
    )
    let annotations = textAware.redactions.map(Annotation.redaction) + [.redaction(manual)]
    let doc = AnnotationDocument(baseImage: RedactionFixtures.baseRef(), annotations: annotations)

    let exported = try HardenedExport.export(document: doc, images: provider, format: .png)
    let image = try #require(TextAwareSupport.decode(exported))
    // The whole text region (covered by detection + manual) reveals nothing.
    let region = try #require(TextAwareSupport.crop(image, docRect: RedactionFixtures.textRegion))
    let recognized = TextAwareSupport.recognizedText(in: region)
    #expect(
        !TextAwareSupport.leaksAnyOriginalString(recognized),
        "text-aware + manual redactions must both harden on export: \(recognized)"
    )
    // Detected vs manual remain distinguishable in the document model.
    let allDetected = textAware.redactions.allSatisfy(\.detectedText)
    #expect(allDetected)
    #expect(!manual.detectedText)
}

// MARK: - spec: Per-instance toggles (MODEL)

/// #### Scenario: Exclude one instance
@Test func excludeOneInstance() throws {
    // Toggling an instance OFF = excluding its box from the produced set. The other
    // instances stay redacted and the excluded instance's original text reappears.
    let provider = RedactionFixtures.provider()
    let allBoxes = TextAwareSupport.fixtureLineBoxes()
    // Exclude the LAST line; its text must become OCR-readable again while the
    // others stay obscured. (The last line is "Account: 5512-9087-3344".)
    let excluded = allBoxes[allBoxes.count - 1]
    let kept = Array(allBoxes.dropLast())

    let result = TextAwareRedaction.allText(in: kept, imageSize: TextAwareSupport.imageSize(), style: .blackout)
    #expect(result.redactions.count == allBoxes.count - 1)
    #expect(!result.redactions.contains { $0.id == excluded.id }, "excluded instance must not be redacted")

    let doc = AnnotationDocument(
        baseImage: RedactionFixtures.baseRef(),
        annotations: result.redactions.map(Annotation.redaction)
    )
    let exported = try HardenedExport.export(document: doc, images: provider, format: .png)
    let image = try #require(TextAwareSupport.decode(exported))
    // The excluded line's region still reads its original text.
    let excludedRegion = try TextAwareSupport.recognizedText(
        in: #require(TextAwareSupport.crop(image, docRect: excluded.rect))
    )
    #expect(excludedRegion.contains("5512"), "excluded instance's original text must be visible: \(excludedRegion)")
}

/// #### Scenario: Re-include a toggled-off instance
@Test func reIncludeAToggledOffInstance() throws {
    // Re-including = the box is back in the set, so its region is redacted again
    // over exactly that instance.
    let provider = RedactionFixtures.provider()
    let allBoxes = TextAwareSupport.fixtureLineBoxes()
    let reincluded = allBoxes[allBoxes.count - 1]

    let result = TextAwareRedaction.allText(in: allBoxes, imageSize: TextAwareSupport.imageSize(), style: .blackout)
    #expect(result.redactions.contains { $0.id == reincluded.id }, "re-included instance must be redacted")

    let doc = AnnotationDocument(
        baseImage: RedactionFixtures.baseRef(),
        annotations: result.redactions.map(Annotation.redaction)
    )
    let exported = try #require(try TextAwareSupport.decode(
        HardenedExport.export(document: doc, images: provider, format: .png)
    ))
    let region = try TextAwareSupport.recognizedText(
        in: #require(TextAwareSupport.crop(exported, docRect: reincluded.rect))
    )
    #expect(!region.contains("5512"), "re-included instance's text must be obscured again: \(region)")
}

// MARK: - Flatten actually obscures (reuse the Vision OCR-defeat harness)

/// Text-aware redactions actually DESTROY their boxed regions on flatten/export —
/// the produced annotations go through the existing destructive redaction render
/// path, so OCR reads none of the covered strings.
@Test func textAwareRedactionsDestroyRegionsOnFlatten() throws {
    let provider = RedactionFixtures.provider()
    let boxes = TextAwareSupport.fixtureLineBoxes()
    let result = TextAwareRedaction.allText(
        in: boxes,
        imageSize: TextAwareSupport.imageSize(),
        style: .blur,
        strength: 12
    )
    let doc = AnnotationDocument(
        baseImage: RedactionFixtures.baseRef(),
        annotations: result.redactions.map(Annotation.redaction)
    )
    let exported = try #require(try TextAwareSupport.decode(
        HardenedExport.export(document: doc, images: provider, format: .png)
    ))
    let region = try #require(TextAwareSupport.crop(exported, docRect: RedactionFixtures.textRegion))
    let recognized = TextAwareSupport.recognizedText(in: region)
    #expect(
        !TextAwareSupport.leaksAnyOriginalString(recognized),
        "text-aware redactions failed to destroy text on flatten: \(recognized)"
    )
}

// MARK: - Clamping / padding geometry

/// Produced regions are clamped to the image and padded — never exceeding bounds.
@Test func redactionsAreClampedToImageBounds() throws {
    let size = DocSize(width: 100, height: 80)
    // A box hugging the bottom-right corner; padding must not push it past bounds.
    let boxes = [TextBox(id: Canonical.uuid(6398), rect: DocRect(x: 90, y: 70, width: 20, height: 20))]
    let result = TextAwareRedaction.redactions(for: boxes, imageSize: size, style: .blur, padding: 4)
    let rect = try #require(result.redactions.first).rect
    #expect(rect.minX >= 0 && rect.minY >= 0)
    #expect(rect.maxX <= size.width && rect.maxY <= size.height)
}
