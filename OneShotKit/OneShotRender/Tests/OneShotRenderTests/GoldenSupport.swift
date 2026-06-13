import CoreGraphics
import Foundation
import ImageIO
import OneShotCore
@testable import OneShotRender

// Golden-snapshot harness for the render core (design D13 / build-guide DoD #3:
// annotation render quality is regression-guarded by reviewed golden images).
//
// The comparison is AA-tolerant: tiny anti-aliasing / subpixel differences between
// runs and machines must not flake the suite, so we allow a per-pixel epsilon and
// cap the mean per-channel difference. Committed baselines under Goldens/ are DRAFT
// product assets pending human visual review.

enum Golden {
    /// Mean per-channel difference (0–255) allowed across the whole image.
    static let meanTolerance: Double = 3.0
    /// Fraction of pixels permitted to exceed the hard per-pixel epsilon.
    static let maxOutlierFraction: Double = 0.02
    /// Per-pixel per-channel hard epsilon (0–255) before a pixel counts as an outlier.
    static let pixelEpsilon: Int = 24

    /// Set ONESHOT_RECORD_GOLDENS=1 to (re)write baselines instead of asserting.
    static var isRecording: Bool {
        ProcessInfo.processInfo.environment["ONESHOT_RECORD_GOLDENS"] == "1"
    }

    /// Where committed baselines live in the test bundle.
    static func baselineURL(_ name: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Goldens")
    }

    /// Directory to write into when recording. Resolves the source tree from this
    /// file's path so recorded baselines land next to the committed ones.
    static func recordDirectory() -> URL {
        // .../Tests/OneShotRenderTests/GoldenSupport.swift -> .../Tests/OneShotRenderTests/Goldens
        let thisFile = URL(fileURLWithPath: #filePath)
        return thisFile.deletingLastPathComponent().appendingPathComponent("Goldens")
    }
}

struct ComparisonResult {
    let meanDifference: Double
    let outlierFraction: Double
    let dimensionsMatch: Bool
    let candidateWidth: Int
    let candidateHeight: Int
    let baselineWidth: Int
    let baselineHeight: Int

    var passes: Bool {
        dimensionsMatch
            && meanDifference <= Golden.meanTolerance
            && outlierFraction <= Golden.maxOutlierFraction
    }

    var summary: String {
        """
        dims candidate=\(candidateWidth)x\(candidateHeight) baseline=\(baselineWidth)x\(baselineHeight) \
        match=\(dimensionsMatch) mean=\(String(format: "%.3f", meanDifference)) \
        outlierFraction=\(String(format: "%.4f", outlierFraction))
        """
    }
}

enum GoldenError: Error, CustomStringConvertible {
    case missingBaseline(String)
    case rasterizeFailed(String)

    var description: String {
        switch self {
        case let .missingBaseline(name): "missing baseline PNG: \(name) (record with ONESHOT_RECORD_GOLDENS=1)"
        case let .rasterizeFailed(name): "could not rasterize candidate or baseline: \(name)"
        }
    }
}

enum RasterBuffer {
    /// Decodes a CGImage into a tight 8-bit RGBA sRGB buffer for comparison. We
    /// re-render into a known-format context so two images are always compared in
    /// the same layout regardless of how they were produced.
    static func rgba(_ image: CGImage) -> (pixels: [UInt8], width: Int, height: Int)? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let result: Bool = pixels.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return result ? (pixels, width, height) : nil
    }

    static func decodePNG(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

enum GoldenComparator {
    static func compare(candidate: CGImage, baseline: CGImage) -> ComparisonResult {
        guard let a = RasterBuffer.rgba(candidate), let b = RasterBuffer.rgba(baseline) else {
            return ComparisonResult(
                meanDifference: .greatestFiniteMagnitude,
                outlierFraction: 1,
                dimensionsMatch: false,
                candidateWidth: candidate.width, candidateHeight: candidate.height,
                baselineWidth: baseline.width, baselineHeight: baseline.height
            )
        }
        let dimsMatch = a.width == b.width && a.height == b.height
        guard dimsMatch else {
            return ComparisonResult(
                meanDifference: .greatestFiniteMagnitude,
                outlierFraction: 1,
                dimensionsMatch: false,
                candidateWidth: a.width, candidateHeight: a.height,
                baselineWidth: b.width, baselineHeight: b.height
            )
        }

        var totalDiff: UInt64 = 0
        var outliers = 0
        let count = a.pixels.count
        var i = 0
        while i < count {
            for c in 0 ..< 4 {
                let d = abs(Int(a.pixels[i + c]) - Int(b.pixels[i + c]))
                totalDiff += UInt64(d)
                if d > Golden.pixelEpsilon { outliers += 1 }
            }
            i += 4
        }
        let mean = Double(totalDiff) / Double(count)
        let outlierFraction = Double(outliers) / Double(count)
        return ComparisonResult(
            meanDifference: mean,
            outlierFraction: outlierFraction,
            dimensionsMatch: true,
            candidateWidth: a.width, candidateHeight: a.height,
            baselineWidth: b.width, baselineHeight: b.height
        )
    }
}
