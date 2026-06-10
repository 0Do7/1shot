import Foundation
import Testing
@testable import OneShotCore

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("oneshot-bundle-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func sampleBundle() -> DocumentBundle {
    let placed = PlacedImageAnnotation(
        image: ImageReference(fileName: "image-2.png", pixelWidth: 4, pixelHeight: 4, scale: 1),
        rect: DocRect(x: 0, y: 0, width: 4, height: 4)
    )
    let document = AnnotationDocument(
        baseImage: ImageReference(fileName: "base.png", pixelWidth: 8, pixelHeight: 8, scale: 2),
        annotations: [.placedImage(placed)]
    )
    return DocumentBundle(
        document: document,
        images: [
            "base.png": Data([0x01, 0x02, 0x03]),
            "image-2.png": Data([0x04, 0x05]),
        ],
        thumbnail: Data([0x09])
    )
}

@Test func bundle_writeReadRoundTrip() throws {
    let dir = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("sample.1shot")

    let original = sampleBundle()
    try DocumentBundleIO.write(original, to: url)
    let read = try DocumentBundleIO.read(from: url)

    #expect(read.document == original.document)
    #expect(read.images == original.images)
    #expect(read.thumbnail == original.thumbnail)
}

// Atomicity: overwriting an existing bundle either fully succeeds or leaves the
// old content — verified here by overwrite-then-read.
@Test func bundle_overwriteIsAtomicSwap() throws {
    let dir = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("sample.1shot")

    try DocumentBundleIO.write(sampleBundle(), to: url)
    var updated = sampleBundle()
    updated.document.annotations = []
    updated.images = ["base.png": Data([0xFF])]
    updated.thumbnail = nil
    try DocumentBundleIO.write(updated, to: url)

    let read = try DocumentBundleIO.read(from: url)
    #expect(read.document.annotations.isEmpty)
    #expect(read.images["base.png"] == Data([0xFF]))
    // No staging directories left behind.
    let leftovers = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        .filter { $0.contains(".saving-") }
    #expect(leftovers.isEmpty)
}

@Test func bundle_writeRefusesWhenReferencedImageMissing() throws {
    let dir = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    var bundle = sampleBundle()
    bundle.images.removeValue(forKey: "image-2.png")

    #expect(throws: DocumentBundleError.missingImage("image-2.png")) {
        try DocumentBundleIO.write(bundle, to: dir.appendingPathComponent("broken.1shot"))
    }
}

@Test func bundle_readRefusesTraversalImageNames() throws {
    let dir = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    var bundle = sampleBundle()
    bundle.document.baseImage.fileName = "../escape.png"
    bundle.images["../escape.png"] = Data([0x00])

    #expect(throws: DocumentBundleError.invalidImageName("../escape.png")) {
        try DocumentBundleIO.write(bundle, to: dir.appendingPathComponent("hostile.1shot"))
    }
}

@Test func bundle_missingDocumentJSON_isExplicit() throws {
    let dir = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("empty.1shot")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

    #expect(throws: DocumentBundleError.missingDocumentJSON) {
        try DocumentBundleIO.read(from: url)
    }
}

/// Golden fixture: a committed v1 bundle must always open (spec: old documents
/// open in newer app versions). Never regenerate this fixture — migrate it.
@Test func goldenV1Bundle_opens() throws {
    let fixtures = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
    let bundle = try DocumentBundleIO.read(from: fixtures.appendingPathComponent("golden-v1.1shot"))

    #expect(bundle.document.schemaVersion == 1)
    #expect(bundle.document.annotations.count == 2)
    #expect(bundle.document.counterNumber(for: bundle.document.annotations[1].id) == 1)
    #expect(bundle.images["base.png"]?.isEmpty == false)
    #expect(bundle.thumbnail != nil)
}
