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
/// session UI (honest-failure messaging). `.belowThreshold` carries the measured
/// confidence and the threshold it missed so the message can be specific.
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

    private var estimator: OverlapEstimator {
        OverlapEstimator()
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

        // Only the vertical path is implemented for 7.1/7.2 (horizontal = 7.7).
        let expectedCross = lastTile.crossExtent(axis: document.axis)
        let incomingCross = document.axis == .vertical ? incoming.width : incoming.height
        guard incomingCross == expectedCross else {
            appended = document
            return .lowConfidence(.crossAxisMismatch(expected: expectedCross, found: incomingCross))
        }

        guard
            let previousProfile = LuminanceExtractor.verticalProfile(of: lastTile.image),
            let incomingProfile = LuminanceExtractor.verticalProfile(of: incoming)
        else {
            appended = document
            return .lowConfidence(.unreadableTile)
        }

        guard let match = estimate(previous: previousProfile, next: incomingProfile) else {
            appended = document
            return .lowConfidence(.noOverlap)
        }

        guard match.confidence >= confidenceThreshold else {
            appended = document
            return .lowConfidence(.belowThreshold(confidence: match.confidence, threshold: confidenceThreshold))
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
        // result back up to full-res pixels.
        let coarsePrev = decimate(previous, factor: coarseFactor)
        let coarseNext = decimate(next, factor: coarseFactor)
        guard let coarse = estimator.estimate(previous: coarsePrev, next: coarseNext) else {
            // Profiles too short to decimate meaningfully — correlate full-res
            // directly rather than failing the pass.
            return estimator.estimate(previous: previous, next: next)
        }
        let coarseAdvance = coarse.advance * coarseFactor

        // PASS 2 — refine. Search ±refineRadius around the coarse advance at full
        // resolution for the exact pixel.
        let low = Swift.max(1, coarseAdvance - refineRadius)
        let high = Swift.min(height - 1, coarseAdvance + refineRadius)
        return estimator.estimate(previous: previous, next: next, searchLow: low, searchHigh: high)
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
