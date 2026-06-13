import CoreGraphics
import Foundation
import Testing
@testable import OneShotScroll

// Task 7.9 — full-resolution guarantee: a resource limit yields an honest PARTIAL
// result, NEVER a downscaled full-length image; tiles always keep native
// resolution. Spec: scrolling-capture "Full-resolution output". Test names follow
// the spec's "#### Scenario:" headings.

/// A synthetic retina fixture: the sliced frames plus the geometry used to build
/// them, so assertions can reason about full-resolution density and extent.
private struct RetinaFixture {
    let frames: [CGImage]
    let vh: Int
    let advance: Int
    let width: Int
}

private func retinaFrames(scale: Int, viewports: Int) -> RetinaFixture {
    let width = 100 * scale
    let vh = 200 * scale
    // Advance leaves a healthy overlap (~40%) at any scale, like a real scroll.
    let advance = 120 * scale
    let page = ScrollFixtures.tallPage(width: width, height: vh + advance * viewports)
    let frames = ScrollFixtures.tiles(from: page, viewportHeight: vh, advance: advance, count: viewports)
    return RetinaFixture(frames: frames, vh: vh, advance: advance, width: width)
}

// MARK: - Scenario: Long Retina capture stays at 2x

@Test func longRetinaCaptureStaysAt2x() {
    // A long capture on a simulated 2x display: every tile keeps native 2x density;
    // the output pixel dimensions equal the traversed logical content × 2.
    let scale = 2
    let viewports = 30
    let fixture = retinaFrames(scale: scale, viewports: viewports)
    let session = ScrollCaptureSession() // unlimited

    let outcome = session.run(frames: fixture.frames)
    guard case let .complete(document) = outcome else {
        Issue.record("expected complete, got partial/failed")
        return
    }
    // Full 2x density everywhere: no tile downscaled.
    #expect(document.tiles.allSatisfy { $0.pixelWidth == fixture.width })
    #expect(Int(document.renderedSize().width) == fixture.width)
    // Output height matches the traversal at full density (±1px per seam).
    let expected = fixture.vh + (viewports - 1) * fixture.advance
    #expect(abs(Int(document.renderedSize().height) - expected) <= viewports)
}

// MARK: - Scenario: Resource limit reached honestly

@Test func resourceLimitReachedHonestly() {
    // A small injected axis-extent limit is hit partway: the session stops and
    // delivers the FULL-RESOLUTION content captured so far, NOT a downscaled full.
    let scale = 2
    let fixture = retinaFrames(scale: scale, viewports: 10)
    // Limit at ~3 tiles' worth of extent.
    let limitExtent = fixture.vh + 3 * fixture.advance
    var session = ScrollCaptureSession()
    session.limit = ResourceLimit(maxAxisExtent: limitExtent, maxPixelArea: nil, maxTileCount: nil)

    let outcome = session.run(frames: fixture.frames)
    guard case let .partial(document, hit) = outcome else {
        Issue.record("expected partial, got \(outcome)")
        return
    }
    guard case let .axisExtentExceeded(limit) = hit else {
        Issue.record("expected axisExtentExceeded, got \(hit)")
        return
    }
    #expect(limit == limitExtent)
    // Honest partial: it stopped short of all 10 frames...
    #expect(document.tiles.count < 10)
    #expect(document.tiles.count >= 1)
    // ...the delivered content is WITHIN the limit (not over it)...
    #expect(Int(document.renderedSize().height) <= limitExtent)
    // ...and crucially it is FULL RESOLUTION, not a downscaled full-length image:
    // every retained tile keeps native width, and the canvas width is native.
    #expect(document.tiles.allSatisfy { $0.pixelWidth == fixture.width })
    #expect(Int(document.renderedSize().width) == fixture.width)
    // The message explains the limit.
    #expect(hit.explanation.contains("\(limitExtent)"))
}

@Test func tileCountLimitYieldsHonestPartial() {
    let fixture = retinaFrames(scale: 1, viewports: 8)
    var session = ScrollCaptureSession()
    session.limit = ResourceLimit(maxAxisExtent: nil, maxPixelArea: nil, maxTileCount: 3)
    let outcome = session.run(frames: fixture.frames)
    guard case let .partial(document, .tileCountExceeded(limit)) = outcome else {
        Issue.record("expected tileCountExceeded partial, got \(outcome)")
        return
    }
    #expect(limit == 3)
    #expect(document.tiles.count == 3) // stopped before the 4th would breach
}

@Test func pixelAreaLimitYieldsHonestPartial() {
    let scale = 1
    let fixture = retinaFrames(scale: scale, viewports: 12)
    let areaLimit = fixture.width * (fixture.vh + 4 * fixture.advance)
    var session = ScrollCaptureSession()
    session.limit = ResourceLimit(maxAxisExtent: nil, maxPixelArea: areaLimit, maxTileCount: nil)
    let outcome = session.run(frames: fixture.frames)
    guard case let .partial(document, .pixelAreaExceeded(limit)) = outcome else {
        Issue.record("expected pixelAreaExceeded partial, got \(outcome)")
        return
    }
    #expect(limit == areaLimit)
    let size = document.renderedSize()
    #expect(Int(size.width) * Int(size.height) <= areaLimit)
    #expect(document.tiles.allSatisfy { $0.pixelWidth == fixture.width }) // full res
}

@Test func unlimitedSessionCompletesWholeSequence() {
    let fixture = retinaFrames(scale: 1, viewports: 6)
    let outcome = ScrollCaptureSession().run(frames: fixture.frames)
    guard case let .complete(document) = outcome else {
        Issue.record("expected complete, got \(outcome)")
        return
    }
    #expect(document.tiles.count == 6)
}

@Test func sessionStopsHonestlyOnStitchFailureKeepingValidPrefix() {
    // A mid-sequence unrelated frame fails to stitch: the session returns the valid
    // prefix, never a garbage stitch.
    let page = ScrollFixtures.tallPage(width: 160, height: 1400)
    var frames = ScrollFixtures.tiles(from: page, viewportHeight: 300, advance: 120, count: 4)
    let alien = ScrollFixtures.tallPage(width: 160, height: 300, seed: 424_242)
    frames.insert(alien, at: 2) // breaks continuity at index 2

    let outcome = ScrollCaptureSession().run(frames: frames)
    guard case let .stitchFailed(document, failure) = outcome else {
        Issue.record("expected stitchFailed, got \(outcome)")
        return
    }
    // Valid prefix retained (the two good frames before the alien).
    #expect(document.tiles.count == 2)
    #expect(!failure.explanation.isEmpty)
}

@Test func horizontalSessionRunsToCompletion() {
    let page = ScrollFixtures.widePage(width: 1600, height: 160)
    let frames = ScrollFixtures.horizontalTiles(from: page, viewportWidth: 400, advance: 150, count: 6)
    var session = ScrollCaptureSession()
    session.axis = .horizontal
    let outcome = session.run(frames: frames)
    guard case let .complete(document) = outcome else {
        Issue.record("expected complete horizontal, got \(outcome)")
        return
    }
    #expect(document.axis == .horizontal)
    #expect(document.tiles.count == 6)
    #expect(Int(document.renderedSize().height) == 160) // cross-axis intact
}
