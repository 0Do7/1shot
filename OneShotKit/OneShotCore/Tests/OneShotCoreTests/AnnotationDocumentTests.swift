import Foundation
import Testing
@testable import OneShotCore

private func sampleDocument() -> AnnotationDocument {
    let stroke = StrokeStyle(color: .black, width: 3)
    return AnnotationDocument(
        baseImage: ImageReference(fileName: "base.png", pixelWidth: 800, pixelHeight: 600, scale: 2),
        annotations: [
            .arrow(ArrowAnnotation(
                start: DocPoint(x: 10, y: 10),
                end: DocPoint(x: 100, y: 80),
                control: DocPoint(x: 40, y: 70),
                stroke: stroke
            )),
            .line(LineAnnotation(start: .zero, end: DocPoint(x: 50, y: 0), stroke: stroke)),
            .shape(ShapeAnnotation(
                shape: .rectangle,
                rect: DocRect(x: 5, y: 5, width: 60, height: 40),
                stroke: stroke,
                fill: DocColor(red: 1, green: 0, blue: 0, alpha: 0.3),
                cornerRadius: 4
            )),
            .text(TextAnnotation(
                text: "Hello",
                origin: DocPoint(x: 20, y: 20),
                style: TextStyle(pointSize: 16, weight: .bold, color: .white, backgroundColor: .black)
            )),
            .highlight(HighlightAnnotation(
                mode: .snapped,
                rects: [DocRect(x: 0, y: 0, width: 100, height: 14), DocRect(x: 0, y: 16, width: 80, height: 14)],
                color: DocColor(red: 1, green: 0.9, blue: 0, alpha: 0.5)
            )),
            .spotlight(SpotlightAnnotation(region: DocRect(x: 30, y: 30, width: 100, height: 100))),
            .counter(CounterAnnotation(center: DocPoint(x: 70, y: 70), color: .black)),
            .freehand(FreehandAnnotation(
                points: [.zero, DocPoint(x: 5, y: 9), DocPoint(x: 11, y: 2)],
                stroke: stroke
            )),
            .magnifier(MagnifierAnnotation(
                sourceRect: DocRect(x: 0, y: 0, width: 50, height: 50),
                calloutRect: DocRect(x: 200, y: 200, width: 150, height: 150),
                border: stroke
            )),
            .redaction(RedactionAnnotation(rect: DocRect(x: 10, y: 10, width: 90, height: 20), style: .blur)),
            .placedImage(PlacedImageAnnotation(
                image: ImageReference(fileName: "image-2.png", pixelWidth: 400, pixelHeight: 300, scale: 2),
                rect: DocRect(x: 0, y: 620, width: 400, height: 300)
            )),
        ],
        canvas: CanvasConfiguration(
            insets: DocEdgeInsets(top: 0, left: 0, bottom: 320, right: 0),
            background: .color(.white)
        ),
        crop: CropState(rect: DocRect(x: 0, y: 0, width: 800, height: 900))
    )
}

// Spec: Document round-trips through serialization
@Test func document_roundTripsThroughSerialization_valueEqual() throws {
    let original = sampleDocument()
    let decoded = try DocumentCodec.decode(DocumentCodec.encode(original))
    #expect(decoded == original)
    #expect(decoded.annotations.map(\.id) == original.annotations.map(\.id)) // order preserved
}

@Test func document_schemaVersionIsExplicitInJSON() throws {
    let data = try DocumentCodec.encode(sampleDocument())
    let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(json["schemaVersion"] as? Int == AnnotationDocument.currentSchemaVersion)
}

// Spec: Old documents open in newer app versions — the v1 wire format is pinned
// here; if this fixture stops decoding, a migration step is missing.
@Test func pinnedV1Fixture_decodes() throws {
    let v1JSON = """
    {
      "schemaVersion": 1,
      "baseImage": {"fileName": "base.png", "pixelWidth": 100, "pixelHeight": 50, "scale": 2},
      "annotations": [
        {"kind": "arrow", "props": {
          "id": "00000000-0000-0000-0000-000000000001",
          "start": {"x": 1, "y": 2}, "end": {"x": 3, "y": 4},
          "stroke": {"color": {"red": 0, "green": 0, "blue": 0, "alpha": 1}, "width": 2}
        }},
        {"kind": "redaction", "props": {
          "id": "00000000-0000-0000-0000-000000000002",
          "rect": {"origin": {"x": 0, "y": 0}, "size": {"width": 10, "height": 5}},
          "style": "pixelate", "strength": 14, "detectedText": true
        }}
      ],
      "canvas": {"insets": {"top": 0, "left": 0, "bottom": 0, "right": 0}, "background": {"kind": "transparent"}}
    }
    """
    let document = try DocumentCodec.decode(Data(v1JSON.utf8))
    #expect(document.annotations.count == 2)
    guard case let .arrow(arrow) = document.annotations[0] else {
        Issue.record("expected arrow")
        return
    }
    #expect(arrow.control == nil) // absent optional → straight arrow
    guard case let .redaction(redaction) = document.annotations[1] else {
        Issue.record("expected redaction")
        return
    }
    #expect(redaction.style == .pixelate)
    #expect(redaction.detectedText)
    #expect(document.crop == nil)
}

@Test func newerSchemaThanSupported_refusesExplicitly() {
    let futureJSON = #"{"schemaVersion": 999, "baseImage": {}, "annotations": []}"#
    #expect(throws: DocumentCodecError.schemaNewerThanSupported(
        found: 999,
        supported: AnnotationDocument.currentSchemaVersion
    )) {
        try DocumentCodec.decode(Data(futureJSON.utf8))
    }
}

@Test func invalidSchemaVersion_refusesExplicitly() {
    let badJSON = #"{"schemaVersion": 0, "baseImage": {}, "annotations": []}"#
    #expect(throws: DocumentCodecError.invalidSchemaVersion(found: 0)) {
        try DocumentCodec.decode(Data(badJSON.utf8))
    }
}

// Spec: Counter badges auto-increment (numbering derives from document order)
@Test func counterBadges_autoIncrement_andRenumberOnDelete() {
    var document = AnnotationDocument(
        baseImage: ImageReference(fileName: "base.png", pixelWidth: 100, pixelHeight: 100, scale: 1)
    )
    let c1 = CounterAnnotation(center: DocPoint(x: 1, y: 1), color: .black)
    let c2 = CounterAnnotation(center: DocPoint(x: 2, y: 2), color: .black)
    let c3 = CounterAnnotation(center: DocPoint(x: 3, y: 3), color: .black)
    document.annotations = [
        .counter(c1),
        .arrow(ArrowAnnotation(start: .zero, end: .zero, stroke: StrokeStyle(color: .black, width: 1))),
        .counter(c2),
        .counter(c3),
    ]
    #expect(document.counterNumber(for: c1.id) == 1)
    #expect(document.counterNumber(for: c2.id) == 2)
    #expect(document.counterNumber(for: c3.id) == 3)

    document.annotations.removeAll { $0.id == c2.id }
    #expect(document.counterNumber(for: c1.id) == 1)
    #expect(document.counterNumber(for: c3.id) == 2)
    #expect(document.counterNumber(for: c2.id) == nil)
}

// Spec: Canvas expansion adds space (geometry side; fill rendering is task 5.1)
@Test func canvasExpansion_extendsCanvasRect() {
    var document = AnnotationDocument(
        baseImage: ImageReference(fileName: "base.png", pixelWidth: 800, pixelHeight: 600, scale: 2)
    )
    #expect(document.canvasRect == DocRect(x: 0, y: 0, width: 800, height: 600))

    document.canvas = CanvasConfiguration(
        insets: DocEdgeInsets(top: 10, left: 20, bottom: 30, right: 40),
        background: .color(.white)
    )
    #expect(document.canvasRect == DocRect(x: -20, y: -10, width: 860, height: 640))
    #expect(document.visibleRect == document.canvasRect)
}

// Spec: Crop is re-adjustable (model side: crop never discards content)
@Test func crop_isNonDestructive_contentRetained() throws {
    var document = sampleDocument()
    let annotationsBeforeCrop = document.annotations

    document.crop = CropState(rect: DocRect(x: 100, y: 100, width: 200, height: 150))
    #expect(document.visibleRect == DocRect(x: 100, y: 100, width: 200, height: 150))
    #expect(document.annotations == annotationsBeforeCrop) // nothing dropped

    // Round-trip through persistence keeps the cropped-out content too.
    var reopened = try DocumentCodec.decode(DocumentCodec.encode(document))
    reopened.crop = nil
    #expect(reopened.annotations == annotationsBeforeCrop)
    #expect(reopened.visibleRect == reopened.canvasRect)
}

@Test func magnifierMagnification_derivedFromRects() {
    let magnifier = MagnifierAnnotation(
        sourceRect: DocRect(x: 0, y: 0, width: 50, height: 50),
        calloutRect: DocRect(x: 0, y: 0, width: 150, height: 150),
        border: StrokeStyle(color: .black, width: 1)
    )
    #expect(magnifier.magnification == 3)
}
