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
        /// Normalized x-gap (fraction of image width) that maps to one indent
        /// unit. ~0.012 ≈ one monospace column at common capture sizes.
        public static let indentUnitWidth = 0.012
        /// Spaces emitted per detected indent unit.
        public static let spacesPerIndentUnit = 4
        /// Two lines belong to the same paragraph (merge candidates) when their
        /// left edges differ by less than this — protects indentation from being
        /// read as a new paragraph.
        public static let sameColumnTolerance = 0.01
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
    private static func preserveLayout(_ lines: [RecognizedTextLine]) -> String {
        let minX = lines.map(\.boundingBox.minX).min() ?? 0
        return lines.map { line -> String in
            let gap = line.boundingBox.minX - minX
            let units = Int((gap / Tuning.indentUnitWidth).rounded())
            let indent = String(
                repeating: " ",
                count: Swift.max(0, units) * Tuning.spacesPerIndentUnit
            )
            return indent + line.text.trimmingCharacters(in: .whitespaces)
        }
        .joined(separator: "\n")
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
