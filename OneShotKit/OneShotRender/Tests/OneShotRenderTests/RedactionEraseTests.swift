import CoreGraphics
import Foundation
import ImageIO
import OneShotCore
import OneShotOCR
import Testing
@testable import OneShotRender

// Erase / content-aware-removal suite (tasks 6.3 erase branch + 6.4).
// `.erase` is a background-matching fill (spike S1 diffusion fill) that blends a
// region into its surroundings with NO legible residue. These tests assert both
// halves of the spec: it BLENDS (region matches the surrounding background) and it
// DEFEATS OCR + hardens destructively on export (the redaction floor, like 6.1/6.2),
// driven by the REAL VisionTextRecognizer headless over a CGImage.

// MARK: - Helpers

private enum EraseSupport {
    /// Mean per-channel absolute difference (0–255) between every pixel of `image`
    /// inside `docRect` and a fixed reference RGB colour. Used to assert an erase
    /// filled a region back to (approximately) the surrounding background colour.
    static func meanDiffFromColor(_ image: CGImage, docRect: DocRect, color: DocColor) -> Double {
        guard let buf = RasterBuffer.rgba(image) else { return .greatestFiniteMagnitude }
        let x0 = max(0, Int(docRect.minX)), y0 = max(0, Int(docRect.minY))
        let x1 = min(buf.width, Int(docRect.maxX)), y1 = min(buf.height, Int(docRect.maxY))
        guard x1 > x0, y1 > y0 else { return .greatestFiniteMagnitude }
        let ref = [Int(color.red * 255), Int(color.green * 255), Int(color.blue * 255)]
        var total = 0, count = 0
        for y in y0 ..< y1 {
            for x in x0 ..< x1 {
                let i = (y * buf.width + x) * 4
                for channel in 0 ..< 3 {
                    total += abs(Int(buf.pixels[i + channel]) - ref[channel])
                    count += 1
                }
            }
        }
        return count == 0 ? .greatestFiniteMagnitude : Double(total) / Double(count)
    }

    /// A document with one `.erase` redaction over the flat fixture's text region.
    static func flatEraseDocument(id: UUID) -> AnnotationDocument {
        AnnotationDocument(
            baseImage: RedactionFixtures.flatBaseRef(),
            annotations: [
                .redaction(RedactionAnnotation(id: id, rect: RedactionFixtures.flatTextRegion, style: .erase)),
            ]
        )
    }
}

// MARK: - spec: Text-aware blur and erase (the erase branch)

/// #### Scenario: Text-aware erase blends
/// (also the OCR-defeat floor for erase, mirroring 6.1's blur/pixelate floors):
/// after erasing text over a flat background the region must (a) read as NONE of
/// the original strings to the REAL Vision recognizer and (b) match the surrounding
/// background colour — i.e. blend in with no legible residue.
@Test func textAwareEraseBlends() throws {
    let provider = RedactionFixtures.flatProvider()
    let doc = EraseSupport.flatEraseDocument(id: Canonical.uuid(660))
    let exported = try HardenedExport.export(document: doc, images: provider, format: .png)
    let image = try #require(RedactionSupport.decode(exported))

    // (a) No legible residue: OCR over the erased region reads none of the strings.
    let region = try #require(RedactionSupport.crop(image, docRect: RedactionFixtures.flatTextRegion))
    let recognized = RedactionSupport.recognizedText(in: region)
    #expect(
        !RedactionSupport.leaksAnyOriginalString(recognized),
        "erase left legible residue: \(recognized)"
    )

    // (b) Blends: the erased region's pixels are close to the flat background colour
    // (the dark text is gone, filled with the surrounding blue). A solid blackout
    // would score ~255 here; a successful background-matching fill scores low.
    let meanDiff = EraseSupport.meanDiffFromColor(
        image,
        docRect: RedactionFixtures.flatTextRegion,
        color: RedactionFixtures.flatBackground
    )
    #expect(
        meanDiff < 24,
        "erase did not blend with the flat background (mean channel diff \(meanDiff) from background colour)"
    )
}

// MARK: - spec: Content-aware object removal

/// #### Scenario: Remove an object from a uniform background
/// Content-aware removal of an opaque object on a flat field fills it to be visually
/// continuous with the background (and, being destructive, leaves no original pixels).
@Test func removeObjectFromUniformBackground() throws {
    // Composite a bright object onto the flat background, mark it for erase.
    let provider = RedactionFixtures.flatProvider()
    let objectRegion = DocRect(x: 200, y: 120, width: 120, height: 60)
    let doc = AnnotationDocument(
        baseImage: RedactionFixtures.flatBaseRef(),
        annotations: [
            // An opaque "object" sitting on the flat field.
            .shape(ShapeAnnotation(
                id: Canonical.uuid(665),
                shape: .rectangle,
                rect: objectRegion,
                stroke: StrokeStyle(color: Canonical.red, width: 0),
                fill: Canonical.red
            )),
            // Content-aware removal over exactly the object.
            .redaction(RedactionAnnotation(id: Canonical.uuid(666), rect: objectRegion, style: .erase)),
        ]
    )
    let image = try AnnotationRasterizer.render(document: doc, images: provider, scale: 1)
    // The erased object region is filled to be continuous with the flat background.
    let meanDiff = EraseSupport.meanDiffFromColor(
        image,
        docRect: objectRegion,
        color: RedactionFixtures.flatBackground
    )
    #expect(
        meanDiff < 24,
        "content-aware removal did not blend the object region into the background (diff \(meanDiff))"
    )
    // And no red object pixels survive (destructive): the red channel must be low.
    let buf = try #require(RasterBuffer.rgba(image))
    let cx = Int(objectRegion.center.x), cy = Int(objectRegion.center.y)
    let idx = (cy * buf.width + cx) * 4
    #expect(buf.pixels[idx] < 120, "object's red pixels must not survive the erase")
}

// MARK: - "No legible residue" invariant (direct pixel check)

/// The erase fill is synthesized ONLY from surrounding pixels — even with an absurdly
/// high-contrast original (near-black text on the flat field), no original content
/// bleeds through. This guards the "no legible residue" invariant directly.
@Test func eraseFillIgnoresOriginalRegionContent() throws {
    let provider = RedactionFixtures.flatProvider()
    let doc = EraseSupport.flatEraseDocument(id: Canonical.uuid(667))
    let image = try AnnotationRasterizer.render(document: doc, images: provider, scale: 1)
    // The darkest pixel in the erased region must still be far lighter than the
    // near-black original text — proving the original did not leak into the fill.
    let buf = try #require(RasterBuffer.rgba(image))
    let region = RedactionFixtures.flatTextRegion
    var minLuma = 255
    for y in Int(region.minY) ..< Int(region.maxY) {
        for x in Int(region.minX) ..< Int(region.maxX) {
            let i = (y * buf.width + x) * 4
            let luma = (Int(buf.pixels[i]) + Int(buf.pixels[i + 1]) + Int(buf.pixels[i + 2])) / 3
            minLuma = min(minLuma, luma)
        }
    }
    // Original text luma ~ 8; flat background luma ~ 116. The fill must stay well
    // above the text level everywhere (no dark glyph residue survives).
    #expect(minLuma > 60, "erase region retains near-black residue from the original text (minLuma \(minLuma))")
}

// MARK: - Determinism + hardened export parity

/// Erase renders deterministically (golden / reproducibility prerequisite).
@Test func eraseRenderIsDeterministic() throws {
    let provider = RedactionFixtures.flatProvider()
    let doc = EraseSupport.flatEraseDocument(id: Canonical.uuid(668))
    let a = try HardenedExport.export(document: doc, images: provider, format: .png)
    let b = try HardenedExport.export(document: doc, images: provider, format: .png)
    #expect(a == b)
}

/// Erase hardens destructively across EVERY encodable format with exactly one
/// representation (parity with blur/pixelate/blackout in
/// `exportedFileContainsNoHiddenOriginalPixels`).
@Test func eraseHardensDestructivelyAcrossFormats() throws {
    let provider = RedactionFixtures.flatProvider()
    let doc = EraseSupport.flatEraseDocument(id: Canonical.uuid(669))
    for format in ImageFormat.allCases {
        guard HardenedExport.isEncodable(format) else { continue }
        let data = try HardenedExport.export(document: doc, images: provider, format: format)
        let src = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        // Exactly one representation (no embedded pre-erase thumbnail/alternate).
        #expect(CGImageSourceGetCount(src) == 1, "\(format) embedded an alternate representation")
        let image = try #require(CGImageSourceCreateImageAtIndex(src, 0, nil))
        let region = try #require(RedactionSupport.crop(image, docRect: RedactionFixtures.flatTextRegion))
        let recognized = RedactionSupport.recognizedText(in: region)
        #expect(
            !RedactionSupport.leaksAnyOriginalString(recognized),
            "\(format) erase export leaked original text: \(recognized)"
        )
    }
}
