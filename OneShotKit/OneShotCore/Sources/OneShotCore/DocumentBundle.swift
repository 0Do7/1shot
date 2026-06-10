import Foundation

/// In-memory form of a `.1shot` bundle (design D3): the document JSON, every
/// referenced image's encoded bytes (PNG), and an optional pre-rendered thumbnail.
/// This layer stores bytes — it never decodes pixels (that's OneShotRender's job),
/// which keeps it portable and trivially testable.
public struct DocumentBundle: Hashable, Sendable {
    public var document: AnnotationDocument
    /// Keyed by `ImageReference.fileName`. Must contain the base image and every
    /// placed image the document references.
    public var images: [String: Data]
    /// PNG preview for Library grids / QuickLook; regenerated on save by the app.
    public var thumbnail: Data?

    public init(document: AnnotationDocument, images: [String: Data], thumbnail: Data? = nil) {
        self.document = document
        self.images = images
        self.thumbnail = thumbnail
    }

    /// Every image fileName the document requires to render.
    public var requiredImageNames: [String] {
        var names = [document.baseImage.fileName]
        for annotation in document.annotations {
            if case let .placedImage(placed) = annotation {
                names.append(placed.image.fileName)
            }
        }
        return names
    }
}

public enum DocumentBundleError: Error, Equatable, Sendable {
    case notABundle(String)
    case missingDocumentJSON
    case missingImage(String)
    /// Image names are bundle-relative file names; anything path-like is hostile.
    case invalidImageName(String)
}

/// Reads/writes `.1shot` bundles on disk.
///
/// Layout (the documented format, task 2.2):
/// ```
/// Name.1shot/
/// ├── document.json   — AnnotationDocument (DocumentCodec, schema-versioned)
/// ├── base.png        — untouched base capture (name per document.baseImage)
/// ├── image-<id>.png  — placed images, if any
/// └── thumbnail.png   — optional preview
/// ```
public enum DocumentBundleIO {
    public static let pathExtension = "1shot"
    public static let documentFileName = "document.json"
    public static let thumbnailFileName = "thumbnail.png"

    /// Atomic write: the bundle is staged in a temporary directory and swapped in
    /// with `replaceItemAt`, so a crash mid-save never corrupts an existing file.
    public static func write(_ bundle: DocumentBundle, to destination: URL) throws {
        for name in bundle.requiredImageNames where bundle.images[name] == nil {
            throw DocumentBundleError.missingImage(name)
        }
        let allNames = Array(bundle.images.keys) + [documentFileName, thumbnailFileName]
        for name in allNames where name.contains("/") || name.contains("..") || name.isEmpty {
            throw DocumentBundleError.invalidImageName(name)
        }

        let fileManager = FileManager.default
        let staging = destination
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).saving-\(UUID().uuidString)")
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }

        try DocumentCodec.encode(bundle.document)
            .write(to: staging.appendingPathComponent(documentFileName))
        for (name, data) in bundle.images {
            try data.write(to: staging.appendingPathComponent(name))
        }
        if let thumbnail = bundle.thumbnail {
            try thumbnail.write(to: staging.appendingPathComponent(thumbnailFileName))
        }

        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: staging)
        } else {
            try fileManager.moveItem(at: staging, to: destination)
        }
    }

    public static func read(from url: URL) throws -> DocumentBundle {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw DocumentBundleError.notABundle(url.lastPathComponent)
        }
        let documentURL = url.appendingPathComponent(documentFileName)
        guard let documentData = try? Data(contentsOf: documentURL) else {
            throw DocumentBundleError.missingDocumentJSON
        }
        let document = try DocumentCodec.decode(documentData)

        var bundle = DocumentBundle(document: document, images: [:])
        for name in bundle.requiredImageNames {
            guard !name.contains("/"), !name.contains(".."), !name.isEmpty else {
                throw DocumentBundleError.invalidImageName(name)
            }
            guard let data = try? Data(contentsOf: url.appendingPathComponent(name)) else {
                throw DocumentBundleError.missingImage(name)
            }
            bundle.images[name] = data
        }
        bundle.thumbnail = try? Data(contentsOf: url.appendingPathComponent(thumbnailFileName))
        return bundle
    }
}
