import Foundation

/// The three text-layout modes the spec mandates (Requirement: "Indentation and
/// linebreak preservation modes"). The active mode persists in settings and is
/// switchable from the toast (app layer); this enum is the portable contract.
public enum LayoutMode: String, Codable, CaseIterable, Sendable {
    /// Reproduce original linebreaks AND leading indentation (with spaces).
    /// The mode that makes code screenshots paste correctly.
    case preserveLayout
    /// Join soft-wrapped lines into continuous paragraphs.
    case mergeLines
    /// One recognized line per output line; no indentation reconstruction.
    case rawLines
}

/// Turns recognizer line geometry into a clipboard string under a chosen
/// `LayoutMode` (task 8.2). Pure and deterministic — runs against a fake
/// recognizer's output with no Vision involvement.
///
/// Indentation reconstruction is the load-bearing feature: a line that starts
/// further from the left edge than the block's leftmost line is prefixed with
/// spaces proportional to that gap, so an indented code block keeps its shape
/// when pasted into a plain-text editor.
public enum LayoutProcessor {
    /// Tuning constants for indentation reconstruction. Public so callers/tests
    /// can reason about the mapping; defaults are chosen for typical code shots.
    public enum Tuning {
        /// Spaces emitted per detected indent unit.
        public static let spacesPerIndentUnit = 4
        /// Two lines belong to the same paragraph (merge candidates) when their
        /// left edges differ by less than this — protects indentation from being
        /// read as a new paragraph.
        public static let sameColumnTolerance = 0.01
        /// A left-edge gap is treated as real indentation only when it is at
        /// least this fraction of the block's LARGEST gap. Indentation steps in a
        /// block are integer multiples of one unit, so the smallest real step is
        /// a sizable fraction of the deepest gap; sub-glyph OCR jitter is orders
        /// of magnitude smaller and falls below this, so it never becomes the
        /// unit. Both gaps scale with capture width together, so the test is
        /// invariant to how wide the region was captured.
        public static let minIndentFractionOfMaxGap = 0.1
    }

    /// Produce the layout-formatted string for `recognized` under `mode`.
    /// Empty input yields an empty string (the caller decides honest-failure UX).
    public static func format(_ recognized: RecognizedText, mode: LayoutMode) -> String {
        let lines = recognized.lines.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !lines.isEmpty else { return "" }

        switch mode {
        case .rawLines:
            return lines.map { $0.text.trimmingCharacters(in: .whitespaces) }
                .joined(separator: "\n")
        case .preserveLayout:
            return preserveLayout(lines)
        case .mergeLines:
            return mergeLines(lines)
        }
    }

    // MARK: Preserve layout

    /// Reproduce indentation by measuring each line's left edge against the
    /// block's leftmost edge and converting the gap into leading spaces.
    ///
    /// The size of one indent level is derived from the recognized block's OWN
    /// geometry (the smallest real left-edge gap among its lines), not from the
    /// image width. A code indent is a fixed number of columns regardless of how
    /// wide the captured region is, so a width-relative unit over- or
    /// under-indents narrow/wide captures; a gap-relative unit is invariant to
    /// capture width and reproduces the block's structure at any size.
    private static func preserveLayout(_ lines: [RecognizedTextLine]) -> String {
        let minX = lines.map(\.boundingBox.minX).min() ?? 0
        let gaps = lines.map { $0.boundingBox.minX - minX }
        guard let unit = indentUnit(gaps: gaps) else {
            // No real indentation in the block — emit text with linebreaks only.
            return lines.map { $0.text.trimmingCharacters(in: .whitespaces) }
                .joined(separator: "\n")
        }
        return zip(lines, gaps).map { line, gap -> String in
            let units = Swift.max(0, Int((gap / unit).rounded()))
            let indent = String(repeating: " ", count: units * Tuning.spacesPerIndentUnit)
            return indent + line.text.trimmingCharacters(in: .whitespaces)
        }
        .joined(separator: "\n")
    }

    /// One indent level's width, in normalized x: the smallest left-edge gap that
    /// is large enough to be a real indent step rather than sub-glyph OCR jitter.
    /// Returns nil when the block has no real gap (everything left-aligned).
    ///
    /// Derived purely from the block's OWN gap distribution, so it is invariant
    /// to capture width — scale every left edge by the same factor (a wider/
    /// narrower capture of the same content) and both the candidate gaps and the
    /// chosen unit scale together, leaving each line's column count unchanged.
    private static func indentUnit(gaps: [Double]) -> Double? {
        guard let maxGap = gaps.max(), maxGap > 0 else { return nil }
        let floor = Tuning.minIndentFractionOfMaxGap * maxGap
        return gaps.filter { $0 >= floor }.min()
    }

    // MARK: Merge lines

    /// Join soft-wrapped lines into paragraphs. A new paragraph begins when a
    /// line is indented relative to its predecessor (left edge moves right beyond
    /// tolerance) or when the previous line ended on sentence-final punctuation —
    /// otherwise lines are concatenated with a single space.
    private static func mergeLines(_ lines: [RecognizedTextLine]) -> String {
        var paragraphs: [String] = []
        var current = ""
        var previousLeft: Double?

        for line in lines {
            let text = line.text.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            let left = line.boundingBox.minX

            let startsNewParagraph: Bool = {
                guard let prevLeft = previousLeft, !current.isEmpty else { return false }
                // Indentation jump → new block (e.g. list item, new code/quote).
                if left > prevLeft + Tuning.sameColumnTolerance { return true }
                // Hard paragraph end on the previous line.
                if endsParagraph(current) { return true }
                return false
            }()

            if startsNewParagraph {
                paragraphs.append(current)
                current = text
            } else if current.isEmpty {
                current = text
            } else {
                current += " " + text
            }
            previousLeft = left
        }
        if !current.isEmpty { paragraphs.append(current) }
        return paragraphs.joined(separator: "\n\n")
    }

    /// A line ends a paragraph when it terminates in sentence-final punctuation.
    private static func endsParagraph(_ text: String) -> Bool {
        guard let last = text.trimmingCharacters(in: .whitespaces).last else { return false }
        return ".!?。！？".contains(last)
    }
}
