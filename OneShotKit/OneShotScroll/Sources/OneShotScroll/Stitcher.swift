import Accelerate
import CoreGraphics
import Foundation

// Frame stitcher (task 7.1, design D8: "estimate offset by NCC on downsampled
// luminance strips (vDSP), refine at full res → append tile"; spec:
// scrolling-capture "Honest failure messaging").
//
// Per frame the stitcher runs a TWO-PASS estimate against the previous tile:
//   1. COARSE — correlate decimated (downsampled) luminance profiles over the
//      whole advance range to localize the offset cheaply and robustly.
//   2. REFINE — correlate FULL-resolution profiles within a small window around
//      the coarse advance, to pin the offset to the exact pixel.
// The refined NCC is the stitch confidence. Below `confidenceThreshold` the
// stitcher returns `.lowConfidence` and appends nothing: a known-bad seam is
// never emitted as success (the "no silent garbage" product law).

/// Why a stitch step could not be trusted, surfaced to the user verbatim by the
/// session UI (honest-failure messaging, task 7.5). Every reason is explicit and
/// typed: the engine NEVER emits a known-bad stitch as success (the "no silent
/// garbage" product law). `.belowThreshold` carries the measured confidence and
/// the threshold it missed so the message can be specific.
enum StitchFailure: Equatable {
    /// The best correlation found was below the reliability threshold.
    case belowThreshold(confidence: Float, threshold: Float)
    /// No advance left a large-enough overlap to correlate (e.g. the frame
    /// didn't move, or the profiles were too short).
    case noOverlap
    /// The incoming tile's cross-axis size doesn't match the document — the
    /// viewport changed shape, so the seam can't be aligned by a 1-D advance.
    case crossAxisMismatch(expected: Int, found: Int)
    /// A tile's pixels could not be read for luminance extraction.
    case unreadableTile
    /// The detected advance was ~0 across the trusted-overlap search: the surface
    /// did not scroll between frames. Distinct from `.noOverlap` (which is "could
    /// not even correlate") — here we correlated and found the frame stationary.
    case targetDidNotScroll
    /// The frame content is too uniform (flat / near-constant luminance) to anchor
    /// a reliable correlation — any advance scores alike, so no offset is trustable.
    case contentTooUniform(variance: Float, minimum: Float)

    /// A short, user-facing explanation plus a remedy hint (spec: honest-failure
    /// messaging — "tell the user explicitly what went wrong and what to try").
    var explanation: String {
        switch self {
        case let .belowThreshold(confidence, threshold):
            "Couldn't stitch this surface reliably (match \(pct(confidence)) < \(pct(threshold)) required). "
                + "Try manual mode and scroll slowly."
        case .noOverlap:
            "Frames didn't overlap enough to stitch. Try a slower, smaller scroll, or manual mode."
        case let .crossAxisMismatch(expected, found):
            "The capture area changed size mid-scroll (\(expected)px → \(found)px). Restart the capture."
        case .unreadableTile:
            "A captured frame couldn't be read. Restart the capture."
        case .targetDidNotScroll:
            "The target didn't scroll. This surface may not be scrollable; try manual mode."
        case let .contentTooUniform(variance, minimum):
            "The content is too uniform to align (detail \(fine(variance)) < \(fine(minimum)) needed). "
                + "Nothing reliable to stitch."
        }
    }

    private func pct(_ value: Float) -> String {
        String(format: "%.0f%%", value * 100)
    }

    private func fine(_ value: Float) -> String {
        String(format: "%.4f", value)
    }
}

/// Outcome of stitching one new frame onto the running document.
enum StitchResult: Equatable {
    /// Stitched. `seam` describes where the new tile landed.
    case ok(Seam)
    /// Could not stitch reliably; the document is unchanged and the caller should
    /// stop, explain, and offer to keep what's valid.
    case lowConfidence(StitchFailure)

    static func == (lhs: StitchResult, rhs: StitchResult) -> Bool {
        switch (lhs, rhs) {
        case let (.ok(a), .ok(b)): a == b
        case let (.lowConfidence(a), .lowConfidence(b)): a == b
        default: false
        }
    }
}

/// Where a newly appended tile sits relative to its predecessor.
struct Seam: Equatable {
    /// Advance in tile pixels from the previous tile's origin to this tile's.
    let advance: Int
    /// Absolute offset of the new tile from tile 0 (the value stored on the tile).
    let offset: Int
    /// Confidence (refined NCC) of the match, in [-1, 1].
    let confidence: Float
}

struct Stitcher {
    /// Minimum refined NCC to accept a seam. 0.8 is a deliberately strict default
    /// (real overlapping scroll frames correlate ~0.95+); tune per surface.
    var confidenceThreshold: Float = 0.8
    /// Decimation factor for the coarse pass (average this many rows per coarse
    /// sample). 4 keeps the coarse profile cheap while preserving large features.
    var coarseFactor: Int = 4
    /// Half-width (in full-res pixels) of the refinement search window around the
    /// coarse advance. Must comfortably exceed `coarseFactor`.
    var refineRadius: Int = 8
    /// Smallest advance (in pixels) that counts as "the surface scrolled". An
    /// estimate at or below this means the frame was effectively stationary, which
    /// is reported as `.targetDidNotScroll` rather than a (meaningless) seam.
    var minimumScrollAdvance: Int = 1
    /// Minimum along-axis luminance variance of the incoming profile for it to
    /// carry alignable detail. Below this the content is too uniform to stitch
    /// (`.contentTooUniform`). 1e-5 matches the chrome-detector's static tolerance.
    var minimumProfileVariance: Float = 1e-5
    /// If the incoming profile correlates with the previous at advance 0 (no shift)
    /// at or above this NCC, the frame essentially didn't move: report
    /// `.targetDidNotScroll`. 0.999 only fires for an effectively identical frame.
    var stationaryThreshold: Float = 0.999

    private var estimator: OverlapEstimator {
        OverlapEstimator()
    }

    /// True when `incoming` is essentially the same as `previous` (advance-0 NCC at
    /// or above `stationaryThreshold`): the surface did not scroll between frames.
    private func didNotScroll(previous: [Float], incoming: [Float]) -> Bool {
        guard previous.count == incoming.count, !previous.isEmpty else { return false }
        let score = previous.withUnsafeBufferPointer { prev in
            incoming.withUnsafeBufferPointer { nxt in
                OverlapEstimator.ncc(a: prev.baseAddress!, b: nxt.baseAddress!, count: previous.count)
            }
        }
        return score >= stationaryThreshold
    }

    /// Stitch `incoming` onto `document`. An empty document just anchors the
    /// first tile (always `.ok` with advance 0). Otherwise: extract profiles,
    /// run coarse→refine, gate on confidence, and on success return the seam plus
    /// the grown document via `appended`.
    func stitch(
        incoming: CGImage,
        onto document: ScrollDocument,
        appended: inout ScrollDocument
    ) -> StitchResult {
        guard let lastTile = document.tiles.last else {
            appended = document.appending(incoming, advance: 0)
            return .ok(Seam(advance: 0, offset: 0, confidence: 1))
        }

        // Axis-agnostic: vertical correlates row profiles, horizontal correlates
        // column profiles (task 7.7). Cross-axis size must match either way.
        let expectedCross = lastTile.crossExtent(axis: document.axis)
        let incomingTile = ScrollTile(image: incoming, offset: 0)
        let incomingCross = incomingTile.crossExtent(axis: document.axis)
        guard incomingCross == expectedCross else {
            appended = document
            return .lowConfidence(.crossAxisMismatch(expected: expectedCross, found: incomingCross))
        }

        guard
            let previousProfile = LuminanceExtractor.profile(of: lastTile.image, axis: document.axis),
            let incomingProfile = LuminanceExtractor.profile(of: incoming, axis: document.axis)
        else {
            appended = document
            return .lowConfidence(.unreadableTile)
        }

        // Too-uniform content carries no alignable signal: any advance correlates
        // alike, so a "confident" seam would be a coincidence. Reject explicitly.
        let detail = StickyChromeDetector.variance(incomingProfile)
        guard detail > minimumProfileVariance else {
            appended = document
            return .lowConfidence(.contentTooUniform(variance: detail, minimum: minimumProfileVariance))
        }

        // Stationary frame (identical to the previous): the target didn't scroll.
        guard !didNotScroll(previous: previousProfile, incoming: incomingProfile) else {
            appended = document
            return .lowConfidence(.targetDidNotScroll)
        }

        guard let match = estimate(previous: previousProfile, next: incomingProfile) else {
            appended = document
            return .lowConfidence(.noOverlap)
        }

        guard match.confidence >= confidenceThreshold else {
            appended = document
            return .lowConfidence(.belowThreshold(confidence: match.confidence, threshold: confidenceThreshold))
        }

        // A confident match at a near-zero advance means the surface didn't move.
        guard match.advance > minimumScrollAdvance else {
            appended = document
            return .lowConfidence(.targetDidNotScroll)
        }

        appended = document.appending(incoming, advance: match.advance)
        let offset = lastTile.offset + match.advance
        return .ok(Seam(advance: match.advance, offset: offset, confidence: match.confidence))
    }

    /// Coarse→refine offset estimate between two equal-length full-res profiles.
    func estimate(previous: [Float], next: [Float]) -> OverlapMatch? {
        let height = previous.count
        guard height > 0, next.count == height else { return nil }

        // PASS 1 — coarse. Decimate both profiles by averaging blocks of
        // `coarseFactor`, correlate over the full advance range, scale the
        // result back up to full-res pixels. Overlap-weighted selection so a
        // short-overlap coincidence on a smooth gradient can't beat the true peak.
        let coarsePrev = decimate(previous, factor: coarseFactor)
        let coarseNext = decimate(next, factor: coarseFactor)
        var coarseEstimator = estimator
        coarseEstimator.overlapWeightedSelection = true
        guard let coarse = coarseEstimator.estimate(previous: coarsePrev, next: coarseNext) else {
            // Profiles too short to decimate meaningfully — correlate full-res
            // directly rather than failing the pass.
            return estimator.estimate(previous: previous, next: next)
        }
        let coarseAdvance = coarse.advance * coarseFactor

        // PASS 2 — refine. Search ±refineRadius around the coarse advance at full
        // resolution for the exact pixel.
        let low = Swift.max(1, coarseAdvance - refineRadius)
        let high = Swift.min(height - 1, coarseAdvance + refineRadius)
        let refined = estimator.estimate(previous: previous, next: next, searchLow: low, searchHigh: high)

        // PASS 3 — fallback. If the refined match is below the acceptance threshold
        // the coarse pass likely mis-localized (broad-gradient surfaces can fool the
        // cheap decimated search). Rather than emit a wrong seam, pay for a full-res
        // global search; keep whichever match is more confident. Honest over fast.
        guard let refined, refined.confidence >= confidenceThreshold else {
            var globalEstimator = estimator
            globalEstimator.overlapWeightedSelection = true
            let global = globalEstimator.estimate(previous: previous, next: next)
            return bestOf(refined, global)
        }
        return refined
    }

    /// The higher-confidence of two optional matches (nil-tolerant).
    private func bestOf(_ lhs: OverlapMatch?, _ rhs: OverlapMatch?) -> OverlapMatch? {
        switch (lhs, rhs) {
        case let (left?, right?): left.confidence >= right.confidence ? left : right
        case let (left?, nil): left
        case let (nil, right?): right
        case (nil, nil): nil
        }
    }

    /// Average non-overlapping blocks of `factor` samples into one coarse sample.
    /// A trailing partial block is averaged over its actual length.
    func decimate(_ profile: [Float], factor: Int) -> [Float] {
        guard factor > 1, profile.count >= factor * 2 else { return profile }
        let outCount = profile.count / factor
        var out = [Float](repeating: 0, count: outCount)
        profile.withUnsafeBufferPointer { src in
            for i in 0 ..< outCount {
                var mean: Float = 0
                vDSP_meanv(src.baseAddress! + i * factor, 1, &mean, vDSP_Length(factor))
                out[i] = mean
            }
        }
        return out
    }
}
