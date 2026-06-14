import Accelerate
import CoreGraphics
import Foundation

// Overlap estimation by normalized cross-correlation (task 7.1, design D8).
//
// Given the previous tile and the next tile of a vertical scroll, we recover the
// ADVANCE d: how many pixels the content moved between frames. By construction
// row r of the previous tile shows the same content as row (r - d) of the next
// tile, so the previous tile's bottom band [d, H) overlaps the next tile's top
// band [0, H-d). We score each candidate d by the normalized cross-correlation
// (Pearson correlation) of those two equal-length luminance windows and pick the
// d with the highest score. NCC is brightness/contrast invariant (zero-mean,
// unit-norm), so a fade or gamma shift between frames doesn't fool it.
//
// The score at the winning d is the stitch CONFIDENCE in [-1, 1]; 1.0 is a
// perfect match. The Stitcher gates on this for honest failure.
//
// vDSP carries the per-candidate dot products and norms (vDSP_dotpr / vDSP_meanv
// / vDSP_svesq) — the hot loop over O(H) candidates each touching O(H) samples.

/// Result of correlating two adjacent tiles along the scroll axis.
struct OverlapMatch: Equatable {
    /// Recovered advance in pixels: the next tile's content is shifted this many
    /// pixels past the previous tile's content.
    let advance: Int
    /// Normalized cross-correlation at `advance`, in [-1, 1]. Higher = better.
    let confidence: Float
    /// Number of overlapping samples scored at the winning advance.
    let overlapCount: Int
}

struct OverlapEstimator {
    /// Smallest overlap (in profile samples) we will trust a correlation on.
    /// Too-small overlaps produce spuriously high NCC from noise; the estimator
    /// refuses to consider advances that leave fewer than this many samples.
    var minimumOverlap: Int = 8

    /// When true, candidates are RANKED by NCC weighted by overlap fraction
    /// (`score * sqrt(overlap / height)`) rather than raw NCC, while the returned
    /// `confidence` stays the raw NCC. This breaks the coarse pass's tendency to
    /// prefer a short-overlap coincidence (a few samples of a smooth gradient
    /// correlate spuriously high) over a long-overlap true match — a real defect
    /// that threatens both axes; the coarse pass enables it, refine leaves it off
    /// (its narrow window has near-equal overlaps, so weighting is a no-op there).
    var overlapWeightedSelection: Bool = false

    /// Correlate two equal-orientation row profiles (previous, next), searching
    /// advances in `[searchLow, searchHigh]` (clamped to the valid range). The
    /// profiles are the per-row mean luma from `LuminanceExtractor`. Returns nil
    /// only if no advance leaves a large-enough overlap.
    func estimate(
        previous: [Float],
        next: [Float],
        searchLow: Int = 1,
        searchHigh: Int? = nil
    ) -> OverlapMatch? {
        let height = previous.count
        guard height > 0, next.count == height else { return nil }
        // An advance d leaves height - d overlapping samples; cap so the overlap
        // never drops below the minimum, and never exceeds the profile.
        let maxAdvance = Swift.min(searchHigh ?? (height - 1), height - minimumOverlap)
        let low = Swift.max(0, searchLow)
        guard low <= maxAdvance else { return nil }

        var best = OverlapMatch(advance: low, confidence: -.greatestFiniteMagnitude, overlapCount: 0)
        var bestRank = -Float.greatestFiniteMagnitude
        previous.withUnsafeBufferPointer { prev in
            next.withUnsafeBufferPointer { nxt in
                for advance in low ... maxAdvance {
                    let overlap = height - advance
                    guard overlap >= minimumOverlap else { continue }
                    // previous[advance ..< height] vs next[0 ..< overlap]
                    let score = Self.ncc(a: prev.baseAddress! + advance, b: nxt.baseAddress!, count: overlap)
                    let rank = overlapWeightedSelection
                        ? score * (Float(overlap) / Float(height)).squareRoot()
                        : score
                    if rank > bestRank {
                        bestRank = rank
                        best = OverlapMatch(advance: advance, confidence: score, overlapCount: overlap)
                    }
                }
            }
        }
        return best.overlapCount == 0 ? nil : best
    }

    /// Pearson correlation of two equal-length sample windows, computed with
    /// Accelerate. Returns 0 when either window is flat (zero variance): a flat
    /// band carries no alignment information, so it must not score as a match.
    static func ncc(a: UnsafePointer<Float>, b: UnsafePointer<Float>, count: Int) -> Float {
        guard count > 0 else { return 0 }
        let n = vDSP_Length(count)

        var meanA: Float = 0
        var meanB: Float = 0
        vDSP_meanv(a, 1, &meanA, n)
        vDSP_meanv(b, 1, &meanB, n)

        // Zero-mean copies.
        var ca = [Float](repeating: 0, count: count)
        var cb = [Float](repeating: 0, count: count)
        var negMeanA = -meanA
        var negMeanB = -meanB
        vDSP_vsadd(a, 1, &negMeanA, &ca, 1, n)
        vDSP_vsadd(b, 1, &negMeanB, &cb, 1, n)

        var dot: Float = 0
        var sumSqA: Float = 0
        var sumSqB: Float = 0
        ca.withUnsafeBufferPointer { pa in
            cb.withUnsafeBufferPointer { pb in
                vDSP_dotpr(pa.baseAddress!, 1, pb.baseAddress!, 1, &dot, n)
                vDSP_svesq(pa.baseAddress!, 1, &sumSqA, n)
                vDSP_svesq(pb.baseAddress!, 1, &sumSqB, n)
            }
        }
        let denom = (sumSqA * sumSqB).squareRoot()
        guard denom > 1e-9 else { return 0 }
        return dot / denom
    }
}
