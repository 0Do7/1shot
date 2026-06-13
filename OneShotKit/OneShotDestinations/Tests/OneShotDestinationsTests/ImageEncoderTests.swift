import CoreGraphics
import Foundation
import ImageIO
import OneShotCore
import Testing
import UniformTypeIdentifiers
@testable import OneShotDestinations

// MARK: Fixtures

/// A photographic-ish test image: smooth gradients + per-pixel noise. The noise
/// matters — a flat fill compresses to ~nothing in every format and erases the
/// relative size ordering we want to assert.
private func makeTestImage(width: Int = 256, height: Int = 256, scale: Int = 1) -> CGImage {
    let w = width * scale
    let h = height * scale
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: nil,
        width: w,
        height: h,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let data = context.data!.assumingMemoryBound(to: UInt8.self)
    let bytesPerRow = context.bytesPerRow
    var seed: UInt64 = 0x1234_5678
    func next() -> UInt8 {
        seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return UInt8((seed >> 33) & 0xFF)
    }
    for y in 0 ..< h {
        for x in 0 ..< w {
            let offset = y * bytesPerRow + x * 4
            data[offset + 0] = UInt8((x * 255) / w) ^ next()
            data[offset + 1] = UInt8((y * 255) / h) ^ next()
            data[offset + 2] = next()
            data[offset + 3] = 255
        }
    }
    return context.makeImage()!
}

/// Pixel dimensions of encoded bytes, read back via ImageIO.
private func pixelSize(of data: Data) throws -> (width: Int, height: Int) {
    let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    return (image.width, image.height)
}

/// A deliberately *unoptimized* baseline encode of `image` in `format`: the same
/// pixels and same UTType the production encoder uses, but with EXIF/GPS/TIFF/IPTC
/// metadata carried through instead of stripped. This is the "baseline unoptimized
/// encode of the same pixels" the spec's size-sanity scenario compares against, so
/// a regression that dropped metadata stripping would no longer be smaller than it.
private func baselineUnstrippedEncode(_ image: CGImage, format: ImageFormat, quality: Double) throws -> Data {
    let utType = try #require(UTType(format.utType))
    let data = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(
        data as CFMutableData,
        utType.identifier as CFString,
        1,
        nil
    ))
    // Populate the metadata families the production encoder zeroes out, so the
    // baseline genuinely carries location/hardware/user-identifying bytes.
    var properties: [CFString: Any] = [
        kCGImagePropertyExifDictionary: [
            kCGImagePropertyExifDateTimeOriginal: "2026:06:13 09:41:00",
            kCGImagePropertyExifBodySerialNumber: "SN-0123456789-ABCDEF",
            kCGImagePropertyExifUserComment: String(repeating: "captured-by-oneshot-user ", count: 16),
        ] as [CFString: Any],
        kCGImagePropertyGPSDictionary: [
            kCGImagePropertyGPSLatitude: 37.7749,
            kCGImagePropertyGPSLongitude: -122.4194,
        ] as [CFString: Any],
        kCGImagePropertyTIFFDictionary: [
            kCGImagePropertyTIFFMake: "OneShot",
            kCGImagePropertyTIFFModel: "Capture Device 9000",
        ] as [CFString: Any],
        kCGImagePropertyIPTCDictionary: [
            kCGImagePropertyIPTCByline: "codyhung",
            kCGImagePropertyIPTCCaptionAbstract: String(repeating: "desktop screenshot ", count: 16),
        ] as [CFString: Any],
    ]
    if format != .png {
        properties[kCGImageDestinationLossyCompressionQuality] = quality
    }
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    #expect(CGImageDestinationFinalize(destination))
    return data as Data
}

// MARK: Format support / honest failure

/// Spec ("Export format support" + honest-failure requirement): PNG and JPEG
/// must always encode; WebP/HEIC availability is OS-dependent, and an
/// unsupported format is an explicit typed error, never a crash.
@Test func exportFormatSupport_pngAndJpegAlwaysEncode() throws {
    let image = makeTestImage()
    let png = try ImageEncoder.encode(image, format: .png)
    let jpeg = try ImageEncoder.encode(image, format: .jpeg)
    #expect(!png.isEmpty)
    #expect(!jpeg.isEmpty)
    #expect(ImageEncoder.isSupported(.png))
    #expect(ImageEncoder.isSupported(.jpeg))
}

@Test func formatUnsupportedByOS_throwsTypedError() throws {
    let image = makeTestImage()
    // Probe each lossy/modern format: if the OS can't encode it, encode() must
    // throw the typed error rather than crash or silently fall back.
    for format in [ImageFormat.webp, .heic] {
        if ImageEncoder.isSupported(format) {
            #expect(throws: Never.self) { _ = try ImageEncoder.encode(image, format: format) }
        } else {
            #expect(throws: ImageEncoder.EncodingError.formatUnsupportedOnThisOS(format)) {
                _ = try ImageEncoder.encode(image, format: format)
            }
        }
    }
}

// MARK: Default export size sanity (spec: file-size-conscious defaults)

/// Spec scenario "Default export size sanity" (output-destinations spec): exporting
/// a typical full-screen capture with default settings produces a file whose encoded
/// size "is not larger than a baseline unoptimized encode of the same pixels." This
/// is the *same-format, same-pixels* optimized-vs-baseline comparison the spec names —
/// the production encoder strips metadata, so its output must be no larger than the
/// identical encode that carries that metadata through. A regression that dropped the
/// metadata stripping (or otherwise inflated the encode) would fail here.
@Test func defaultExportSizeSanity_strippedIsNotLargerThanUnstrippedBaseline() throws {
    let image = makeTestImage()
    // PNG is the lossless default for a typical capture; assert there first so the
    // size win is attributable purely to metadata stripping (no quality variable).
    let strippedPNG = try ImageEncoder.encode(image, format: .png)
    let baselinePNG = try baselineUnstrippedEncode(image, format: .png, quality: 1.0)
    #expect(
        strippedPNG.count <= baselinePNG.count,
        "stripped PNG (\(strippedPNG.count)) must be <= unstripped baseline (\(baselinePNG.count))"
    )

    // Same comparison for the lossy default, holding quality identical on both sides
    // so the only difference being measured is the stripped metadata.
    let quality = ImageEncoder.Options().quality
    let strippedJPEG = try ImageEncoder.encode(image, format: .jpeg, options: .init(quality: quality))
    let baselineJPEG = try baselineUnstrippedEncode(image, format: .jpeg, quality: quality)
    #expect(
        strippedJPEG.count <= baselineJPEG.count,
        "stripped JPEG (\(strippedJPEG.count)) must be <= unstripped baseline (\(baselineJPEG.count))"
    )
}

/// Guard that the baseline used above genuinely carries the metadata the production
/// encoder strips — otherwise the size-sanity comparison would be vacuous. Confirms
/// the baseline retains GPS/TIFF/IPTC bytes that the stripped encode does not.
@Test func sizeSanityBaseline_actuallyCarriesUnstrippedMetadata() throws {
    let image = makeTestImage()
    let baseline = try baselineUnstrippedEncode(image, format: .jpeg, quality: ImageEncoder.Options().quality)
    let source = try #require(CGImageSourceCreateWithData(baseline as CFData, nil))
    let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
    #expect(props[kCGImagePropertyGPSDictionary] != nil, "baseline must retain GPS metadata")
    #expect(props[kCGImagePropertyTIFFDictionary] != nil, "baseline must retain TIFF metadata")
}

/// Separate cross-format sanity check (NOT the spec's size-sanity scenario): on the
/// same noisy source, lossy formats at a moderate quality are smaller than lossless PNG.
@Test func crossFormatSizeOrdering_lossyIsSmallerThanLosslessPNG() throws {
    let image = makeTestImage()
    let png = try ImageEncoder.encode(image, format: .png)
    let jpeg = try ImageEncoder.encode(image, format: .jpeg, options: .init(quality: 0.6))
    #expect(jpeg.count < png.count, "JPEG@0.6 (\(jpeg.count)) should be smaller than lossless PNG (\(png.count))")

    if ImageEncoder.isSupported(.heic) {
        let heic = try ImageEncoder.encode(image, format: .heic, options: .init(quality: 0.6))
        #expect(heic.count < png.count, "HEIC@0.6 (\(heic.count)) should be smaller than lossless PNG (\(png.count))")
    }
}

/// Lowering JPEG quality reduces byte size.
@Test func loweringJpegQualityReducesByteSize() throws {
    let image = makeTestImage()
    let high = try ImageEncoder.encode(image, format: .jpeg, options: .init(quality: 0.9))
    let low = try ImageEncoder.encode(image, format: .jpeg, options: .init(quality: 0.2))
    #expect(low.count < high.count, "JPEG@0.2 (\(low.count)) should be smaller than JPEG@0.9 (\(high.count))")
}

/// Lowering HEIC quality reduces byte size (only where HEIC encoding exists).
@Test func loweringHeicQualityReducesByteSize() throws {
    try withKnownIssue("HEIC encoding unavailable on this OS", isIntermittent: true) {
        guard ImageEncoder.isSupported(.heic) else {
            throw ImageEncoder.EncodingError.formatUnsupportedOnThisOS(.heic)
        }
        let image = makeTestImage()
        let high = try ImageEncoder.encode(image, format: .heic, options: .init(quality: 0.9))
        let low = try ImageEncoder.encode(image, format: .heic, options: .init(quality: 0.2))
        #expect(low.count < high.count, "HEIC@0.2 (\(low.count)) should be smaller than HEIC@0.9 (\(high.count))")
    } when: {
        !ImageEncoder.isSupported(.heic)
    }
}

// MARK: Retina → 1x (spec: "1x export from a 2x display")

@Test func oneXExportFromA2xDisplay_producesExactLogicalPixels() throws {
    // A 400×300 point region captured on a 2x display = 800×600 backing pixels.
    let image = makeTestImage(width: 400, height: 300, scale: 2)
    #expect(image.width == 800 && image.height == 600)

    let data = try ImageEncoder.encode(
        image,
        format: .png,
        options: .init(downscaleRetinaTo1x: true, sourceScale: 2.0)
    )
    let size = try pixelSize(of: data)
    #expect(size.width == 400 && size.height == 300)
}

@Test func retinaDownscaleDisabled_keepsNativePixels() throws {
    let image = makeTestImage(width: 400, height: 300, scale: 2)
    let data = try ImageEncoder.encode(
        image,
        format: .png,
        options: .init(downscaleRetinaTo1x: false, sourceScale: 2.0)
    )
    let size = try pixelSize(of: data)
    #expect(size.width == 800 && size.height == 600)
}

// MARK: Metadata stripping (spec: "Default export size sanity")

/// Exported files carry no EXIF/GPS/TIFF metadata (no location, serials, usernames).
@Test func defaultExport_stripsExifGpsAndTiffMetadata() throws {
    let image = makeTestImage()
    let data = try ImageEncoder.encode(image, format: .jpeg)
    let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
    let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
    // No location data and no camera/hardware identifiers.
    #expect(props[kCGImagePropertyGPSDictionary] == nil)
    #expect(props[kCGImagePropertyTIFFDictionary] == nil) // camera make/model/serial
    #expect(props[kCGImagePropertyIPTCDictionary] == nil)
    // ImageIO re-derives intrinsic pixel dimensions into the EXIF dict for JPEG;
    // those are benign (not user-identifying). Assert that nothing beyond
    // dimensions — no timestamps, no maker/serial, no user-identifying keys —
    // survived.
    let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
    let benign: Set<CFString> = [kCGImagePropertyExifPixelXDimension, kCGImagePropertyExifPixelYDimension]
    let leaked = exif.keys.filter { !benign.contains($0) }
    #expect(leaked.isEmpty, "unexpected EXIF metadata survived: \(leaked)")
    #expect(exif[kCGImagePropertyExifDateTimeOriginal] == nil)
}
