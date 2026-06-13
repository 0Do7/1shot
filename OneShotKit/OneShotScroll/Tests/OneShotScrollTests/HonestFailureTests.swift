import CoreGraphics
import Foundation
import Testing
@testable import OneShotScroll

// Task 7.5 — honest-failure formalization: confidence thresholds + explicit TYPED
// failure reasons + unsupported-surface detection (no overlap across N frames,
// content too uniform / too dynamic). Spec: scrolling-capture "Honest failure
// messaging". Test names follow the spec's "#### Scenario:" headings.

// MARK: - Scenario: Low-confidence stitch halts with explanation

@Test func lowConfidenceStitchHaltsWithExplanation() throws {
    // Two unrelated pages -> confidence below threshold -> typed belowThreshold
    // with a specific, user-facing explanation; the valid portion is kept.
    let pageA = ScrollFixtures.tallPage(width: 200, height: 800, seed: 1)
    let pageB = ScrollFixtures.tallPage(width: 200, height: 800, seed: 999_999)
    let tileA = try #require(pageA.cropping(to: CGRect(x: 0, y: 0, width: 200, height: 400)))
    let tileB = try #require(pageB.cropping(to: CGRect(x: 0, y: 0, width: 200, height: 400)))

    let stitcher = Stitcher()
    let document = ScrollDocument(axis: .vertical, tiles: [ScrollTile(image: tileA, offset: 0)])
    var grown = document
    let result = stitcher.stitch(incoming: tileB, onto: document, appended: &grown)
    guard case let .lowConfidence(.belowThreshold(confidence, threshold)) = result else {
        Issue.record("expected belowThreshold, got \(result)")
        return
    }
    #expect(confidence < threshold)
    // The valid portion (tile A) is retained — offered to keep.
    #expect(grown.tiles.count == 1)
    // Honest-failure messaging: explanation is specific and suggests manual mode.
    let message = StitchFailure.belowThreshold(confidence: confidence, threshold: threshold).explanation
    #expect(message.contains("manual mode"))
    #expect(!message.isEmpty)
}

// MARK: - Scenario: Unscrollable target

@Test func unscrollableTarget() {
    // The same frame captured twice (the surface didn't move): the stitcher must
    // report targetDidNotScroll, not a meaningless seam.
    let tile = ScrollFixtures.tallPage(width: 200, height: 400)
    let stitcher = Stitcher()
    let document = ScrollDocument(axis: .vertical, tiles: [ScrollTile(image: tile, offset: 0)])
    var grown = document
    let result = stitcher.stitch(incoming: tile, onto: document, appended: &grown)
    guard case .lowConfidence(.targetDidNotScroll) = result else {
        Issue.record("expected targetDidNotScroll, got \(result)")
        return
    }
    // Honest: no garbage single-frame stitch presented as a scroll.
    #expect(grown.tiles.count == 1)
    #expect(StitchFailure.targetDidNotScroll.explanation.contains("scroll"))
}

// MARK: - Scenario: No silent garbage

@Test func noSilentGarbage() {
    // Cross-axis mismatch (viewport resized) must surface a typed failure and
    // leave the document unchanged — never a misaligned stitch.
    let tile = ScrollFixtures.tallPage(width: 200, height: 400)
    let narrower = ScrollFixtures.tallPage(width: 150, height: 400)
    let stitcher = Stitcher()
    let document = ScrollDocument(axis: .vertical, tiles: [ScrollTile(image: tile, offset: 0)])
    var grown = document
    let result = stitcher.stitch(incoming: narrower, onto: document, appended: &grown)
    #expect(result == .lowConfidence(.crossAxisMismatch(expected: 200, found: 150)))
    #expect(grown.tiles.count == 1)
}

@Test func contentTooUniformIsTypedFailure() {
    // A flat, near-uniform incoming frame carries no alignable signal: the
    // stitcher must reject it as contentTooUniform rather than score a coincidence.
    let body = ScrollFixtures.tallPage(width: 120, height: 300)
    let uniform = ScrollFixtures.uniformTile(width: 120, height: 300, level: 0.5)
    let stitcher = Stitcher()
    let document = ScrollDocument(axis: .vertical, tiles: [ScrollTile(image: body, offset: 0)])
    var grown = document
    let result = stitcher.stitch(incoming: uniform, onto: document, appended: &grown)
    guard case let .lowConfidence(.contentTooUniform(variance, minimum)) = result else {
        Issue.record("expected contentTooUniform, got \(result)")
        return
    }
    #expect(variance <= minimum)
    #expect(grown.tiles.count == 1)
}

// MARK: - Unsupported-surface detection (sequence-level)

@Test func surfaceUnsupported_noOverlapAcrossFrames() {
    // Each frame is an unrelated page -> no adjacent pair correlates at a real
    // advance -> the surface is judged unsupported (e.g. virtualized).
    let frames = (0 ..< 4).map { seed -> CGImage in
        ScrollFixtures.tallPage(width: 200, height: 400, seed: UInt64(1 + seed * 777_777))
    }
    let verdict = SurfaceSupportAnalyzer().analyze(frames: frames, axis: .vertical)
    guard case let .unsupported(reason) = verdict else {
        Issue.record("expected unsupported, got \(verdict)")
        return
    }
    // Unrelated frames still "overlap-correlate" weakly; the reason is either
    // no-overlap or too-dynamic — both are honest unsupported verdicts.
    switch reason {
    case .noOverlapAcrossFrames, .contentTooDynamic:
        #expect(!reason.explanation.isEmpty)
    case .contentTooUniform:
        Issue.record("unexpected too-uniform for distinct pages")
    }
}

@Test func surfaceUnsupported_contentTooUniform() {
    // Every frame is flat -> nothing distinctive to align -> too-uniform verdict.
    let frames = (0 ..< 4).map { _ in ScrollFixtures.uniformTile(width: 160, height: 300, level: 0.4) }
    let verdict = SurfaceSupportAnalyzer().analyze(frames: frames, axis: .vertical)
    guard case .unsupported(.contentTooUniform) = verdict else {
        Issue.record("expected contentTooUniform, got \(verdict)")
        return
    }
}

@Test func surfaceSupported_realScrollSequence() {
    // A genuine overlapping scroll sequence is judged supported.
    let page = ScrollFixtures.tallPage(width: 180, height: 1800)
    let frames = ScrollFixtures.tiles(from: page, viewportHeight: 400, advance: 140, count: 5)
    #expect(SurfaceSupportAnalyzer().analyze(frames: frames, axis: .vertical) == .supported)
}

@Test func surfaceSupported_horizontalRealScrollSequence() {
    let page = ScrollFixtures.widePage(width: 1800, height: 180)
    let frames = ScrollFixtures.horizontalTiles(from: page, viewportWidth: 400, advance: 140, count: 5)
    #expect(SurfaceSupportAnalyzer().analyze(frames: frames, axis: .horizontal) == .supported)
}
