import CoreGraphics
import Foundation
import GRDB
import OneShotCore
import OneShotOCR

/// Indexes captures into the Library (spec §9.2): runs on-device OCR, derives a
/// heuristic name via OneShotCore.`AutoNamer` (with store-backed collision
/// handling), detects "contains code", and ingests provenance.
///
/// Per-item failure isolation is a product law here: a failed OCR sets
/// `textIndexed = false`, leaves the item present and findable by name/provenance,
/// and NEVER throws to the caller. Graceful degradation IS honest failure.
public struct IndexingPipeline: Sendable {
    private let store: LibraryStore
    private let recognizer: any TextRecognizing
    private let options: RecognitionOptions

    public init(
        store: LibraryStore,
        recognizer: any TextRecognizing,
        options: RecognitionOptions = .default
    ) {
        self.store = store
        self.recognizer = recognizer
        self.options = options
    }

    /// Everything known at capture time, separate from the image so provenance
    /// ingest is testable without a real recognizer.
    public struct CaptureInput: Sendable {
        public var originalPath: String
        public var provenance: CaptureProvenance
        public var capturedAt: Date
        public var timeZone: TimeZone
        /// Content fingerprint for auto-imported files (§9.6 dedup). Nil for native
        /// captures, which dedup by their unique `originalPath` instead.
        public var contentHash: String?

        public init(
            originalPath: String,
            provenance: CaptureProvenance = CaptureProvenance(),
            capturedAt: Date = Date(),
            timeZone: TimeZone = .current,
            contentHash: String? = nil
        ) {
            self.originalPath = originalPath
            self.provenance = provenance
            self.capturedAt = capturedAt
            self.timeZone = timeZone
            self.contentHash = contentHash
        }
    }

    /// Index a freshly captured image end-to-end and return the stored record.
    ///
    /// The capture is ALWAYS inserted (present + findable by name/provenance)
    /// regardless of OCR outcome. OCR is attempted; on failure the item is stored
    /// with `textIndexed = false` and naming falls back to app/title/timestamp.
    /// This call never throws on OCR failure — only on a hard DB failure.
    @discardableResult
    public func index(image: CGImage, input: CaptureInput) async throws -> CaptureRecord {
        // OCR with per-item isolation: a thrown recognizer error degrades to "no
        // text indexed", never a thrown failure for the whole capture.
        let recognized: RecognizedText? = try? recognizer.recognizeText(in: image, options: options)
        let ocrText = recognized.flatMap { $0.isEmpty ? nil : Self.plainText($0) }
        let textIndexed = ocrText != nil

        let signals = CaptureNamingSignals(
            appName: input.provenance.appName,
            windowTitle: input.provenance.windowTitle,
            ocrText: ocrText,
            capturedAt: input.capturedAt,
            timeZone: input.timeZone
        )
        let slug = AutoNamer.slug(for: signals)
        let containsCode = ocrText.map(Self.detectContainsCode) ?? false

        // The base slug carries no id yet; the store resolves any collision and
        // inserts atomically so two concurrent indexes can't claim the same name.
        let record = CaptureRecord(
            originalPath: input.originalPath,
            name: slug,
            mediaType: .image,
            provenance: input.provenance,
            capturedAt: input.capturedAt,
            textIndexed: textIndexed,
            containsCode: containsCode,
            contentHash: input.contentHash
        )
        return try await store.insertResolvingCollision(record, baseSlug: slug, ocrText: ocrText)
    }

    /// Outcome of `indexIfNotDuplicate`: the newly indexed record, or a signal that an
    /// equivalent item (same path or content hash) was already present (§9.6 dedup).
    public enum IndexOutcome: Sendable {
        case indexed(CaptureRecord)
        case duplicate
    }

    /// Index a candidate ONLY if it isn't already in the Library, with the dedup probe
    /// and the insert in ONE store transaction (§9.6 "No duplicate entries"). OCR runs
    /// before the transaction (it's expensive and must not hold the write lock); the
    /// final dedup-check + collision-resolving insert are atomic in the store, closing
    /// the read-then-write TOCTOU window that a per-file insert + separate probe left
    /// open under concurrent watcher delivery. Never throws on OCR failure.
    @discardableResult
    public func indexIfNotDuplicate(image: CGImage, input: CaptureInput) async throws -> IndexOutcome {
        let recognized: RecognizedText? = try? recognizer.recognizeText(in: image, options: options)
        let ocrText = recognized.flatMap { $0.isEmpty ? nil : Self.plainText($0) }
        let textIndexed = ocrText != nil

        let signals = CaptureNamingSignals(
            appName: input.provenance.appName,
            windowTitle: input.provenance.windowTitle,
            ocrText: ocrText,
            capturedAt: input.capturedAt,
            timeZone: input.timeZone
        )
        let slug = AutoNamer.slug(for: signals)
        let containsCode = ocrText.map(Self.detectContainsCode) ?? false

        let record = CaptureRecord(
            originalPath: input.originalPath,
            name: slug,
            mediaType: .image,
            provenance: input.provenance,
            capturedAt: input.capturedAt,
            textIndexed: textIndexed,
            containsCode: containsCode,
            contentHash: input.contentHash
        )
        switch try await store.insertIfNotIndexed(record, baseSlug: slug, ocrText: ocrText) {
        case let .inserted(stored): return .indexed(stored)
        case .duplicate: return .duplicate
        }
    }

    /// Re-index an existing item (e.g. after a later OCR pass). Honors manual-rename
    /// stickiness via the store. OCR failure degrades to `textIndexed = false` and
    /// never throws.
    public func reindex(image: CGImage, id: Int64) async throws {
        guard let existing = try await store.record(id: id) else {
            throw LibraryError.recordNotFound(id)
        }
        let recognized: RecognizedText? = try? recognizer.recognizeText(in: image, options: options)
        let ocrText = recognized.flatMap { $0.isEmpty ? nil : Self.plainText($0) }
        let textIndexed = ocrText != nil

        let signals = CaptureNamingSignals(
            appName: existing.provenance.appName,
            windowTitle: existing.provenance.windowTitle,
            ocrText: ocrText,
            capturedAt: existing.capturedAt
        )
        let slug = AutoNamer.slug(for: signals)
        let containsCode = ocrText.map(Self.detectContainsCode) ?? false

        // The store resolves the collision (excluding this row's own name) and
        // applies the result atomically; a manual rename is honored there.
        try await store.applyIndexResult(
            id: id,
            baseSlug: slug,
            ocrText: ocrText,
            textIndexed: textIndexed,
            containsCode: containsCode
        )
    }

    // MARK: - Heuristics

    /// Flatten recognized lines into newline-joined plain text for the FTS index.
    static func plainText(_ recognized: RecognizedText) -> String {
        recognized.lines
            .map(\.text)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
    }

    /// Structural language tokens for the contains-code heuristic. Ubiquitous English
    /// words (if/for/return/let/case/class/string/int/true/false/var/else/while/
    /// public/private/static/void/bool/null/nil) are deliberately EXCLUDED: they fire
    /// constantly in ordinary prose and were misfiling articles, emails, and chats
    /// into the code folder. Only tokens rare in English remain.
    private static let codeKeywords: Set<String> = [
        "func", "def", "struct", "enum", "import", "throws", "guard", "extension",
        "const", "async", "await", "typedef", "namespace", "interface", "println",
        "fn", "impl", "lambda", "elif", "fileprivate",
    ]
    /// Punctuation that is dense in code but sparse in prose.
    private static let codePunctuation = CharacterSet(charactersIn: "{}[]();=<>|&/\\")

    /// Heuristic "contains code" detector (spec: "contains-code folder … heuristic
    /// detection from OCR content … no AI"). Purely lexical: density of code-shaped
    /// tokens (braces, semicolons, operators, structural keywords, camelCase/path
    /// ids). No model, on-device or remote.
    static func detectContainsCode(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard !lines.isEmpty else { return false }

        var signalLines = 0
        var totalWords = 0
        for line in lines {
            let words = line.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
            totalWords += words.count
            if Self.lineLooksLikeCode(line, words: words) { signalLines += 1 }
        }

        // Prose guard: code is punctuation-dense and word-sparse. Text that reads like
        // prose (many words per line, few code-punctuation chars) is never code, even
        // when it happens to mention a domain, a product name, or a camelCase word.
        let totalPunctuation = text.unicodeScalars.count { Self.codePunctuation.contains($0) }
        let avgWordsPerLine = Double(totalWords) / Double(lines.count)
        if avgWordsPerLine >= 6, totalPunctuation < lines.count { return false }

        // A majority of lines (or a strong single-line signal) must be code-shaped so
        // prose with one stray semicolon never lands in the code folder.
        if lines.count == 1 {
            return signalLines == 1 && (text.contains("{") || text.contains(";") || text.contains("()"))
        }
        return Double(signalLines) / Double(lines.count) >= 0.5
    }

    /// One line counts as a code signal when it has a structural keyword, dense code
    /// punctuation (>= 2), OR a camelCase/dotted/arrow token PAIRED with at least one
    /// code-punctuation char. The camelCase/dotted branch is weak alone (iPhone,
    /// apple.com, JavaScript all trip it), so it only counts beside real punctuation.
    private static func lineLooksLikeCode(_ line: String, words: [String]) -> Bool {
        let hasKeyword = words.contains { codeKeywords.contains($0) }
        let punctuationCount = line.unicodeScalars.count { codePunctuation.contains($0) }
        let hasCamelOrPath = line.range(
            of: "[a-z][A-Z]|[A-Za-z0-9_]+\\.[A-Za-z0-9_]+|->|::|=>",
            options: .regularExpression
        ) != nil
        return hasKeyword || punctuationCount >= 2 || (hasCamelOrPath && punctuationCount >= 1)
    }
}
