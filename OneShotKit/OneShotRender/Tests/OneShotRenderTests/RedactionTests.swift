import CoreGraphics
import Foundation
import ImageIO
import OneShotCore
import OneShotOCR
import Testing
@testable import OneShotRender

// Redaction render + hardened export suite (tasks 6.1, 6.2).
// Each `#### Scenario:` in specs/redaction/spec.md maps to a test named after it.
// The OCR-defeat tests run the REAL VisionTextRecognizer (test-only OCR dependency)
// headless over a CGImage — no screen-recording permission needed.

// MARK: - Helpers

enum RedactionSupport {
    /// Decodes PNG/any bytes into a CGImage.
    static func decode(_ data: Data) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    /// Crops a document-space rect (scale 1) out of an exported image. Document
    /// space is top-left origin; CGImage.cropping uses top-left origin too, so this
    /// is a direct map at scale 1.
    static func crop(_ image: CGImage, docRect: DocRect) -> CGImage? {
        let rect = CGRect(x: docRect.minX, y: docRect.minY, width: docRect.size.width, height: docRect.size.height)
        return image.cropping(to: rect.integral)
    }

    /// All non-whitespace recognized strings (joined) the real recognizer reads in
    /// `image`. Lowercased for a case-insensitive substring check.
    static func recognizedText(in image: CGImage) -> String {
        let recognizer = VisionTextRecognizer()
        let result = (try? recognizer.recognizeText(in: image, options: .default)) ?? RecognizedText()
        return result.lines.map(\.text).joined(separator: " ").lowercased()
    }

    /// Mean per-channel absolute difference (0–255) between two equal-size RGBA
    /// buffers restricted to a document-space rect (scale 1, top-left origin).
    static func regionMeanDiff(
        _ a: RGBAImage,
        _ b: RGBAImage,
        docRect: DocRect
    ) -> Double {
        let x0 = max(0, Int(docRect.minX)), y0 = max(0, Int(docRect.minY))
        let x1 = min(a.width, Int(docRect.maxX)), y1 = min(a.height, Int(docRect.maxY))
        guard x1 > x0, y1 > y0 else { return 0 }
        var total: UInt64 = 0
        var count = 0
        for y in y0 ..< y1 {
            for x in x0 ..< x1 {
                let i = (y * a.width + x) * 4
                for channel in 0 ..< 4 {
                    total += UInt64(abs(Int(a.pixels[i + channel]) - Int(b.pixels[i + channel])))
                    count += 1
                }
            }
        }
        return count == 0 ? 0 : Double(total) / Double(count)
    }

    /// True when none of the fixture's original strings (or distinctive fragments)
    /// survive in the recognized text of the redacted region.
    static func leaksAnyOriginalString(_ recognized: String) -> Bool {
        for original in RedactionFixtures.strings {
            let needle = original.lowercased()
            if recognized.contains(needle) { return true }
            // Also reject long alphanumeric fragments (≥6 chars) to catch partial
            // legibility, not just a perfect full-string read.
            let fragments = needle.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            for fragment in fragments where fragment.count >= 6 {
                if recognized.contains(fragment) { return true }
            }
        }
        return false
    }
}

// MARK: - spec: Effective obscuring strength

/// Sanity control: the real recognizer DOES read the synthetic strings on the
/// untouched capture. Without this, an OCR-defeat pass could be a false positive
/// (Vision simply failing to read crisp 12pt text proves nothing).
@Test func ocrControlReadsUnredactedCapture() throws {
    let data = RedactionFixtures.capturePNG()
    let image = try #require(RedactionSupport.decode(data))
    let recognized = RedactionSupport.recognizedText(in: image)
    // Expect at least one of the known strings to be read on the clean capture.
    let readsSomething = RedactionFixtures.strings.contains { recognized.contains($0.lowercased()) }
    #expect(
        readsSomething,
        "control failed: Vision read none of the strings on the clean capture (recognized: \(recognized))"
    )
}

/// #### Scenario: Default blur defeats OCR
@Test func defaultBlurDefeatsOCR() throws {
    // Default strength is RedactionAnnotation's default (12) — render, harden-encode
    // to PNG, decode, OCR the redacted region.
    let doc = RedactionFixtures.redactedDocument(style: .blur, strength: 12)
    let exported = try HardenedExport.export(
        document: doc,
        images: RedactionFixtures.provider(),
        format: .png
    )
    let image = try #require(RedactionSupport.decode(exported))
    let region = try #require(RedactionSupport.crop(image, docRect: RedactionFixtures.textRegion))
    let recognized = RedactionSupport.recognizedText(in: region)
    #expect(
        !RedactionSupport.leaksAnyOriginalString(recognized),
        "default blur leaked text to OCR: \(recognized)"
    )
}

/// #### Scenario: Strength cannot be lowered below the floor
@Test func strengthCannotBeLoweredBelowTheFloor() throws {
    // Ask for an absurdly low strength (1) — the renderer must clamp up to the
    // OCR-defeat floor, so the export still defeats OCR.
    let belowFloor: Double = 1
    #expect(belowFloor < RedactionRenderer.RedactionFloor.blurSigma, "test premise: request is below the floor")

    let doc = RedactionFixtures.redactedDocument(style: .blur, strength: belowFloor)
    let exported = try HardenedExport.export(
        document: doc,
        images: RedactionFixtures.provider(),
        format: .png
    )
    let image = try #require(RedactionSupport.decode(exported))
    let region = try #require(RedactionSupport.crop(image, docRect: RedactionFixtures.textRegion))
    let recognized = RedactionSupport.recognizedText(in: region)
    #expect(
        !RedactionSupport.leaksAnyOriginalString(recognized),
        "floor-strength blur leaked text to OCR: \(recognized)"
    )

    // The effective sigma is never below the floor regardless of the requested value.
    #expect(RedactionRenderer.effectiveBlurSigma(strength: belowFloor, scale: 1) >= RedactionRenderer.RedactionFloor
        .blurSigma)
    #expect(RedactionRenderer.effectivePixelCell(strength: belowFloor, scale: 1) >= RedactionRenderer.RedactionFloor
        .pixelCell)
}

/// Floor-strength PIXELATE also defeats OCR (the floor applies to both styles).
@Test func floorPixelateDefeatsOCR() throws {
    let doc = RedactionFixtures.redactedDocument(style: .pixelate, strength: 1)
    let exported = try HardenedExport.export(
        document: doc,
        images: RedactionFixtures.provider(),
        format: .png
    )
    let image = try #require(RedactionSupport.decode(exported))
    let region = try #require(RedactionSupport.crop(image, docRect: RedactionFixtures.textRegion))
    let recognized = RedactionSupport.recognizedText(in: region)
    #expect(
        !RedactionSupport.leaksAnyOriginalString(recognized),
        "floor-strength pixelate leaked text to OCR: \(recognized)"
    )
}

// MARK: - spec: Three redaction styles

/// #### Scenario: Apply each style
@Test func applyEachStyle() throws {
    // Three regions over distinct areas, one of each style, all render to pixels
    // that differ from the unredacted base in their region.
    let provider = RedactionFixtures.provider()
    let r1 = DocRect(x: 20, y: 30, width: 200, height: 30)
    let r2 = DocRect(x: 20, y: 70, width: 200, height: 30)
    let r3 = DocRect(x: 20, y: 110, width: 200, height: 30)
    let doc = AnnotationDocument(
        baseImage: RedactionFixtures.baseRef(),
        annotations: [
            .redaction(RedactionAnnotation(id: Canonical.uuid(610), rect: r1, style: .blur, strength: 12)),
            .redaction(RedactionAnnotation(id: Canonical.uuid(611), rect: r2, style: .pixelate, strength: 12)),
            .redaction(RedactionAnnotation(id: Canonical.uuid(612), rect: r3, style: .blackout)),
        ]
    )
    let plain = AnnotationDocument(baseImage: RedactionFixtures.baseRef(), annotations: [])

    let redacted = try AnnotationRasterizer.render(document: doc, images: provider, scale: 1)
    let base = try AnnotationRasterizer.render(document: plain, images: provider, scale: 1)
    let red = try #require(RasterBuffer.rgba(redacted))
    let bas = try #require(RasterBuffer.rgba(base))

    // Each style must measurably change its region's pixels vs the unredacted base.
    #expect(RedactionSupport.regionMeanDiff(red, bas, docRect: r1) > 1, "blur region must change pixels")
    #expect(RedactionSupport.regionMeanDiff(red, bas, docRect: r2) > 1, "pixelate region must change pixels")
    #expect(RedactionSupport.regionMeanDiff(red, bas, docRect: r3) > 1, "blackout region must change pixels")

    // Blackout interior is pure opaque black.
    let bx = Int(r3.minX) + 50, by = Int(r3.minY) + 15
    let bi = (by * red.width + bx) * 4
    #expect(red.pixels[bi] == 0 && red.pixels[bi + 1] == 0 && red.pixels[bi + 2] == 0 && red.pixels[bi + 3] == 255)
}

/// #### Scenario: Switch style on an existing redaction
@Test func switchStyleOnAnExistingRedaction() throws {
    // Same region + id, only the style differs → different pixels, no re-drag.
    let provider = RedactionFixtures.provider()
    let region = DocRect(x: 20, y: 30, width: 240, height: 60)
    func doc(_ style: RedactionAnnotation.Style) -> AnnotationDocument {
        let redaction = RedactionAnnotation(id: Canonical.uuid(620), rect: region, style: style, strength: 12)
        return AnnotationDocument(
            baseImage: RedactionFixtures.baseRef(),
            annotations: [.redaction(redaction)]
        )
    }
    let blur = try AnnotationRasterizer.render(document: doc(.blur), images: provider, scale: 1)
    let pixelate = try AnnotationRasterizer.render(document: doc(.pixelate), images: provider, scale: 1)
    let blurBuf = try #require(RasterBuffer.rgba(blur))
    let pixBuf = try #require(RasterBuffer.rgba(pixelate))
    #expect(blur.width == pixelate.width && blur.height == pixelate.height)
    // Compare WITHIN the redaction region: same region, different style → different
    // pixels there (re-rendered without re-dragging).
    let regionDiff = RedactionSupport.regionMeanDiff(blurBuf, pixBuf, docRect: region)
    #expect(
        regionDiff > Golden.meanTolerance,
        "blur and pixelate of the same region must differ (region mean=\(regionDiff))"
    )
}

/// #### Scenario: Preview matches export
@Test func previewMatchesExport() throws {
    // The on-canvas preview (render) and the exported PNG decode to the same pixels
    // in each redaction region — same rasterizer path, WYSIWYG by construction.
    let doc = AnnotationDocument(
        baseImage: RedactionFixtures.baseRef(),
        annotations: [
            .redaction(RedactionAnnotation(
                id: Canonical.uuid(630),
                rect: DocRect(x: 20, y: 30, width: 200, height: 30),
                style: .blur,
                strength: 12
            )),
            .redaction(RedactionAnnotation(
                id: Canonical.uuid(631),
                rect: DocRect(x: 20, y: 70, width: 200, height: 30),
                style: .pixelate,
                strength: 12
            )),
            .redaction(RedactionAnnotation(
                id: Canonical.uuid(632),
                rect: DocRect(x: 20, y: 110, width: 200, height: 30),
                style: .blackout
            )),
        ]
    )
    let provider = RedactionFixtures.provider()
    let canvas = try AnnotationRasterizer.render(document: doc, images: provider, scale: 1)
    // PNG is lossless, so the exported pixels must match the canvas within tolerance.
    let pngData = try HardenedExport.export(document: doc, images: provider, format: .png)
    let exported = try #require(RasterBuffer.decodePNG(pngData))
    let result = GoldenComparator.compare(candidate: exported, baseline: canvas)
    #expect(result.dimensionsMatch)
    #expect(
        result.meanDifference <= Golden.meanTolerance,
        "exported redaction pixels must match the preview: \(result.summary)"
    )
}

// MARK: - spec: Hardened, non-reversible export (task 6.2)

/// #### Scenario: Exported file contains no hidden original pixels
@Test func exportedFileContainsNoHiddenOriginalPixels() throws {
    // For each encodable format: export, then (a) metadata scan shows no GPS/no
    // sensitive (camera/timestamp/original) EXIF, (b) exactly ONE representation —
    // no alternate/thumbnail layer — and (c) the redacted region OCR-reveals nothing.
    let doc = RedactionFixtures.redactedDocument(style: .blackout, strength: 12)
    let provider = RedactionFixtures.provider()

    // EXIF keys that would expose capture provenance or a pre-redaction original.
    // (ImageIO unavoidably writes benign geometry keys — PixelXDimension/
    // PixelYDimension/ColorSpace — which leak nothing about the redacted content;
    // we assert the *sensitive* keys are absent.)
    let sensitiveExifKeys: [CFString] = [
        kCGImagePropertyExifDateTimeOriginal,
        kCGImagePropertyExifDateTimeDigitized,
        kCGImagePropertyExifLensModel,
        kCGImagePropertyExifUserComment,
        kCGImagePropertyExifMakerNote,
    ]
    // TIFF keys that expose provenance. (HEIC unavoidably writes benign
    // Orientation/TileWidth/TileLength geometry keys — those leak nothing about the
    // redacted content; we assert the *provenance* keys are absent.)
    let sensitiveTiffKeys: [CFString] = [
        kCGImagePropertyTIFFMake,
        kCGImagePropertyTIFFModel,
        kCGImagePropertyTIFFSoftware,
        kCGImagePropertyTIFFDateTime,
        kCGImagePropertyTIFFArtist,
        kCGImagePropertyTIFFCopyright,
    ]

    for format in ImageFormat.allCases {
        guard HardenedExport.isEncodable(format) else { continue } // skip non-encodable on this OS
        let data = try HardenedExport.export(document: doc, images: provider, format: format)
        let src = try #require(CGImageSourceCreateWithData(data as CFData, nil))

        // (a) No GPS dictionary; no sensitive EXIF keys.
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] ?? [:]
        #expect(props[kCGImagePropertyGPSDictionary] == nil, "\(format) leaked GPS metadata")
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        for key in sensitiveExifKeys {
            #expect(exif[key] == nil, "\(format) leaked sensitive EXIF key \(key)")
        }
        let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        for key in sensitiveTiffKeys {
            #expect(tiff[key] == nil, "\(format) leaked sensitive TIFF key \(key)")
        }

        // (b) Exactly one representation — no embedded alternate image / thumbnail
        // layer that could hold a pre-redaction copy.
        let count = CGImageSourceGetCount(src)
        #expect(count == 1, "\(format) embedded \(count) representations (expected 1, no alternate/thumbnail)")

        // (c) The blackout region in the exported image OCR-reveals nothing.
        let image = try #require(CGImageSourceCreateImageAtIndex(src, 0, nil))
        let region = try #require(RedactionSupport.crop(image, docRect: RedactionFixtures.textRegion))
        let recognized = RedactionSupport.recognizedText(in: region)
        #expect(
            !RedactionSupport.leaksAnyOriginalString(recognized),
            "\(format) export leaked original text: \(recognized)"
        )
    }
}

/// A magnifier whose source overlaps a lower-z redaction must NOT re-expose the
/// original pixels: the callout has to sample the already-redacted canvas, not a
/// pristine re-decode of the base image. Both blackout and blur are checked because
/// the leak (a fresh `ImageCodec.decode` of the original capture) bypassed either.
@Test func magnifierOverRedactionDoesNotLeak() throws {
    let provider = RedactionFixtures.provider()
    // The first text line sits high in the capture; redact a band over it and put a
    // magnifier whose source covers that same band, displayed in a clear callout.
    let line = DocRect(x: 20, y: 30, width: 440, height: 40)
    let callout = DocRect(x: 20, y: 90, width: 440, height: 80)

    for style in [RedactionAnnotation.Style.blackout, .blur] {
        let doc = AnnotationDocument(
            baseImage: RedactionFixtures.baseRef(),
            annotations: [
                .redaction(RedactionAnnotation(id: Canonical.uuid(650), rect: line, style: style, strength: 12)),
                .magnifier(MagnifierAnnotation(
                    id: Canonical.uuid(651),
                    sourceRect: line,
                    calloutRect: callout,
                    border: StrokeStyle(color: .white, width: 2)
                )),
            ]
        )
        let exported = try HardenedExport.export(document: doc, images: provider, format: .png)
        let image = try #require(RedactionSupport.decode(exported))
        // The callout shows a magnified copy of the redacted line — OCR it.
        let region = try #require(RedactionSupport.crop(image, docRect: callout))
        let recognized = RedactionSupport.recognizedText(in: region)
        #expect(
            !RedactionSupport.leaksAnyOriginalString(recognized),
            "magnifier over \(style) redaction re-exposed original text: \(recognized)"
        )
    }
}

/// #### Scenario: Clipboard copy is hardened
@Test func clipboardCopyIsHardened() throws {
    // Clipboard placement is a UI-layer concern; the render layer's contract is that
    // EVERY representation it produces for sharing carries only flattened, redacted
    // pixels. Verify each encodable format's bytes never contain the original text.
    let doc = RedactionFixtures.redactedDocument(style: .blur, strength: 12)
    let provider = RedactionFixtures.provider()
    for format in ImageFormat.allCases {
        guard HardenedExport.isEncodable(format) else { continue }
        let data = try HardenedExport.export(document: doc, images: provider, format: format)
        let image = try #require(RedactionSupport.decode(data))
        let region = try #require(RedactionSupport.crop(image, docRect: RedactionFixtures.textRegion))
        let recognized = RedactionSupport.recognizedText(in: region)
        #expect(
            !RedactionSupport.leaksAnyOriginalString(recognized),
            "\(format) clipboard rep leaked original text: \(recognized)"
        )
    }
}

/// Non-encodable formats fail honestly (typed error), never silently swap format.
@Test func hardenedExportFailsHonestlyForUnencodableFormat() throws {
    // WebP commonly has no ImageIO encoder on macOS — if so, export must throw a
    // typed `formatNotEncodable`, not silently produce a different format.
    if HardenedExport.isEncodable(.webp) { return } // skip where WebP IS encodable
    let doc = RedactionFixtures.redactedDocument(style: .blackout, strength: 12)
    #expect(throws: HardenedExportError.formatNotEncodable(.webp)) {
        _ = try HardenedExport.export(document: doc, images: RedactionFixtures.provider(), format: .webp)
    }
}

// MARK: - Determinism

/// Real blur/pixelate render deterministically (golden-stability prerequisite).
@Test func redactionRenderIsDeterministic() throws {
    let doc = RedactionFixtures.redactedDocument(style: .blur, strength: 14)
    let provider = RedactionFixtures.provider()
    let a = try HardenedExport.export(document: doc, images: provider, format: .png)
    let b = try HardenedExport.export(document: doc, images: provider, format: .png)
    #expect(a == b)
}

/// Redaction honors z-order: an annotation drawn AFTER a redaction composites on
/// top of the obscured pixels (the redaction does not erase later layers).
@Test func redactionHonorsZOrder() throws {
    let provider = RedactionFixtures.provider()
    let region = DocRect(x: 20, y: 30, width: 240, height: 80)
    // A red rectangle stroked on top of the redaction must still be visible.
    let doc = AnnotationDocument(
        baseImage: RedactionFixtures.baseRef(),
        annotations: [
            .redaction(RedactionAnnotation(id: Canonical.uuid(640), rect: region, style: .blackout)),
            .shape(ShapeAnnotation(
                id: Canonical.uuid(641),
                shape: .rectangle,
                rect: DocRect(x: 30, y: 40, width: 100, height: 40),
                stroke: StrokeStyle(color: Canonical.red, width: 6),
                fill: Canonical.red
            )),
        ]
    )
    let image = try AnnotationRasterizer.render(document: doc, images: provider, scale: 1)
    let buf = try #require(RasterBuffer.rgba(image))
    // A point inside the red rectangle (over the blackout) must read red, not black.
    let x = 60, y = 55
    let i = (y * buf.width + x) * 4
    #expect(buf.pixels[i] > 150, "annotation above the redaction must composite on top (red channel high)")
}
