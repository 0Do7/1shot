import CoreGraphics
import Foundation

// Unsupported-surface detection (task 7.5, spec:scrolling-capture "Honest failure
// messaging": the system must stop and explain when it "cannot capture or stitch
// a surface reliably ... target does not scroll, content unscrollable or
// virtualized beyond tracking"). Per-frame the Stitcher already produces typed
// `StitchFailure`s; this analyzer looks at a SEQUENCE of consecutive frames to
// catch failure modes that are only visible across frames:
//
//   • NO OVERLAP ACROSS N FRAMES — every pair fails to correlate (e.g. a
//     virtualized list that repaints wholesale): unsupported.
//   • TOO UNIFORM — frames carry near-zero along-axis detail in every frame:
//     nothing to align on.
//   • TOO DYNAMIC — frames change so much between captures that no two correlate
//     above threshold (animation, video, content churning faster than capture).
//
// The verdict is advisory: the session uses it to fail honestly BEFORE building a
// garbage document, and to suggest a remedy. It NEVER fabricates a result.

/// Why a whole surface is judged unstitchable, with a user-facing explanation.
enum SurfaceUnsupported: Equatable {
    /// No pair of the sampled frames overlapped enough to correlate.
    case noOverlapAcrossFrames(frames: Int)
    /// Every sampled frame's along-axis detail was below the uniform floor.
    case contentTooUniform(maxVariance: Float, minimum: Float)
    /// Frames correlated but never above threshold: content changes too fast.
    case contentTooDynamic(bestConfidence: Float, threshold: Float)

    var explanation: String {
        switch self {
        case let .noOverlapAcrossFrames(frames):
            "None of the \(frames) sampled frames overlapped — this surface may be virtualized or "
                + "not scrollable. Try manual mode."
        case .contentTooUniform:
            "The content is too uniform to stitch — there's nothing distinctive to align frame to frame."
        case let .contentTooDynamic(bestConfidence, threshold):
            "The content changed too fast between frames (best match "
                + String(format: "%.0f%%", bestConfidence * 100)
                + " < " + String(format: "%.0f%%", threshold * 100)
                + " needed). Try scrolling slower, or manual mode."
        }
    }
}

/// Verdict of a pre-flight surface analysis.
enum SurfaceVerdict: Equatable {
    /// The sampled frames look stitchable; capture may proceed.
    case supported
    /// The surface cannot be stitched reliably; stop and explain.
    case unsupported(SurfaceUnsupported)
}

struct SurfaceSupportAnalyzer {
    /// The stitcher whose thresholds/estimator define "reliable" — kept in sync so
    /// the pre-flight verdict matches what real stitching would accept.
    var stitcher = Stitcher()
    /// Minimum frames required to judge a surface. Fewer than this is "supported"
    /// by default (insufficient evidence to declare a failure).
    var minimumFrames: Int = 3

    /// Classify a consecutive frame sequence along `axis`. Returns `.supported`
    /// when at least one adjacent pair correlates above threshold at a real scroll
    /// advance; otherwise the most specific unsupported reason.
    func analyze(frames: [CGImage], axis: ScrollAxis) -> SurfaceVerdict {
        guard frames.count >= minimumFrames else { return .supported }
        let profiles = frames.map { LuminanceExtractor.profile(of: $0, axis: axis) }
        guard profiles.allSatisfy({ $0 != nil }) else { return .supported }
        let unwrapped = profiles.compactMap(\.self)

        let maxVariance = unwrapped.map { StickyChromeDetector.variance($0) }.max() ?? 0
        if maxVariance <= stitcher.minimumProfileVariance {
            return .unsupported(.contentTooUniform(maxVariance: maxVariance, minimum: stitcher.minimumProfileVariance))
        }

        return correlateAdjacentPairs(unwrapped, frameCount: frames.count)
    }

    /// Walk adjacent profile pairs and reduce to a verdict. Supported as soon as
    /// any pair beats the threshold; otherwise distinguishes "never overlapped"vs
    /// "overlapped but too dynamic" by whether ANY pair could be correlated.
    private func correlateAdjacentPairs(_ profiles: [[Float]], frameCount: Int) -> SurfaceVerdict {
        var anyOverlap = false
        var bestConfidence: Float = -1
        for index in 1 ..< profiles.count where profiles[index].count == profiles[index - 1].count {
            guard let match = stitcher.estimate(previous: profiles[index - 1], next: profiles[index]) else { continue }
            anyOverlap = true
            bestConfidence = Swift.max(bestConfidence, match.confidence)
            if match.confidence >= stitcher.confidenceThreshold, match.advance > stitcher.minimumScrollAdvance {
                return .supported
            }
        }
        if !anyOverlap {
            return .unsupported(.noOverlapAcrossFrames(frames: frameCount))
        }
        return .unsupported(.contentTooDynamic(bestConfidence: bestConfidence, threshold: stitcher.confidenceThreshold))
    }
}
