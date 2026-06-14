import CoreGraphics
import Foundation

// Full-resolution guarantee + honest partial result (task 7.9, spec:
// scrolling-capture "Full-resolution output": "MUST NOT downscale the result
// regardless of total stitched size; if a hard resource limit would be exceeded,
// the system MUST stop with an explicit explanation and deliver the
// full-resolution content captured so far rather than silently delivering a
// downscaled image").
//
// `ScrollCaptureSession` drives the Stitcher frame-by-frame while enforcing an
// injected `ResourceLimit`. The law is absolute: tiles are NEVER downscaled. When
// the NEXT frame would push the rendered canvas past the limit, the session
// stops and returns a `.partial` carrying the full-resolution document built so
// far plus the typed limit it hit — it does not shrink anything to "fit".

/// A hard ceiling on stitched output size, injected so tests (and production
/// surface presets) can set a small, deterministic bound. A limit of `nil` on a
/// field means "no limit for that dimension".
struct ResourceLimit: Equatable {
    /// Maximum rendered extent ALONG the scroll axis, in pixels.
    var maxAxisExtent: Int?
    /// Maximum total rendered pixel area (width * height), in pixels.
    var maxPixelArea: Int?
    /// Maximum number of retained tiles.
    var maxTileCount: Int?

    static let unlimited = ResourceLimit(maxAxisExtent: nil, maxPixelArea: nil, maxTileCount: nil)

    /// True iff `document` is within every set ceiling.
    func admits(_ document: ScrollDocument) -> Bool {
        let size = document.renderedSize()
        let axisExtent = Int(document.axis == .vertical ? size.height : size.width)
        if let maxAxisExtent, axisExtent > maxAxisExtent { return false }
        if let maxPixelArea, Int(size.width) * Int(size.height) > maxPixelArea { return false }
        if let maxTileCount, document.tiles.count > maxTileCount { return false }
        return true
    }
}

/// Why a session stopped before consuming every frame.
enum ResourceLimitHit: Equatable {
    case axisExtentExceeded(limit: Int)
    case pixelAreaExceeded(limit: Int)
    case tileCountExceeded(limit: Int)

    var explanation: String {
        switch self {
        case let .axisExtentExceeded(limit):
            "Reached the maximum stitched length (\(limit)px). Delivered the full-resolution capture so far."
        case let .pixelAreaExceeded(limit):
            "Reached the maximum image size (\(limit)px²). Delivered the full-resolution capture so far."
        case let .tileCountExceeded(limit):
            "Reached the maximum number of segments (\(limit)). Delivered the full-resolution capture so far."
        }
    }
}

/// Terminal outcome of feeding a frame sequence to a session. Not `Equatable`:
/// it carries a `ScrollDocument`, whose `CGImage` tiles have no value equality.
/// Tests destructure it and assert on `document.tiles` + the typed reason.
enum CaptureOutcome {
    /// Every frame stitched within the resource limit.
    case complete(ScrollDocument)
    /// A resource limit was hit; `document` is the FULL-RESOLUTION content captured
    /// before the offending frame (honest partial, never downscaled).
    case partial(ScrollDocument, ResourceLimitHit)
    /// A frame could not be stitched reliably; `document` is what was valid before
    /// the failure (offered to keep, per honest-failure messaging).
    case stitchFailed(ScrollDocument, StitchFailure)

    /// The document carried by any outcome (complete/partial/failed all retain the
    /// valid full-resolution content captured so far).
    var document: ScrollDocument {
        switch self {
        case let .complete(doc), let .partial(doc, _), let .stitchFailed(doc, _): doc
        }
    }
}

struct ScrollCaptureSession {
    var stitcher = Stitcher()
    var limit: ResourceLimit = .unlimited
    /// Scroll axis of the session's document (task 7.7: horizontal sessions set
    /// this to `.horizontal`). The stitcher itself reads the document's axis.
    var axis: ScrollAxis = .vertical

    /// Feed a whole frame sequence. Anchors the first frame, then stitches each
    /// subsequent frame, checking the limit AFTER a successful stitch: if the grown
    /// document would breach the limit it is rolled back and a `.partial` is
    /// returned holding the pre-breach (full-resolution) document. A stitch failure
    /// returns `.stitchFailed` with the valid prefix. Reaching the end is
    /// `.complete`.
    func run(frames: [CGImage]) -> CaptureOutcome {
        var document = ScrollDocument(axis: axis, tiles: [])
        for frame in frames {
            switch step(frame, into: document) {
            case let .stitched(grown):
                document = grown
            case let .limited(hit):
                return .partial(document, hit)
            case let .failed(failure):
                return .stitchFailed(document, failure)
            }
        }
        return .complete(document)
    }

    private enum Step {
        case stitched(ScrollDocument)
        case limited(ResourceLimitHit)
        case failed(StitchFailure)
    }

    /// One frame: stitch, then admit-or-reject against the limit. Crucially, the
    /// tile is appended at FULL resolution; if it doesn't fit, we discard the grown
    /// document (keeping the smaller one) — we never downscale to make it fit.
    private func step(_ frame: CGImage, into document: ScrollDocument) -> Step {
        var grown = document
        switch stitcher.stitch(incoming: frame, onto: document, appended: &grown) {
        case .ok:
            if let hit = breach(grown, previous: document) {
                return .limited(hit)
            }
            return .stitched(grown)
        case let .lowConfidence(failure):
            return .failed(failure)
        }
    }

    /// The specific ceiling `grown` breaches, or nil if it fits. Anchoring the
    /// first tile is always admitted (an empty-document limit is meaningless).
    private func breach(_ grown: ScrollDocument, previous: ScrollDocument) -> ResourceLimitHit? {
        guard !previous.isEmpty, !limit.admits(grown) else { return nil }
        let size = grown.renderedSize()
        let axisExtent = Int(grown.axis == .vertical ? size.height : size.width)
        if let max = limit.maxAxisExtent, axisExtent > max { return .axisExtentExceeded(limit: max) }
        if let max = limit.maxPixelArea, Int(size.width) * Int(size.height) > max {
            return .pixelAreaExceeded(limit: max)
        }
        if let max = limit.maxTileCount, grown.tiles.count > max { return .tileCountExceeded(limit: max) }
        return nil
    }
}
