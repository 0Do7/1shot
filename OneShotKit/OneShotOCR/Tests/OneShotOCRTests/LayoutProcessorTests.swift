import Foundation
import Testing
@testable import OneShotOCR

// Task 8.2 — three layout modes. Tests are deterministic over seeded line
// geometry (no Vision). Indentation correctness for code is the load-bearing
// case and is asserted explicitly.

/// Spec scenario: "Code block keeps its indentation" (preserve-layout)
@Test func codeBlockKeepsItsIndentation() {
    // A small indented code block. One indent step = `indentUnitWidth` (0.012)
    // in normalized x. Left edges: base 0.10, +0.012 (one step), +0.024 (two).
    let recognized = RecognizedText(lines: [
        line("func main() {", left: 0.100, top: 0.90),
        line("if ready {", left: 0.112, top: 0.80), // indented one level
        line("print(\"go\")", left: 0.124, top: 0.70), // indented two levels
        line("}", left: 0.112, top: 0.60),
        line("}", left: 0.100, top: 0.50),
    ])

    let out = LayoutProcessor.format(recognized, mode: .preserveLayout)
    let lines = out.components(separatedBy: "\n")

    #expect(lines.count == 5) // original linebreaks preserved
    #expect(lines[0] == "func main() {") // base column, no indent
    #expect(lines[1] == "    if ready {") // one 4-space indent unit
    #expect(lines[2] == "        print(\"go\")") // two indent units
    #expect(lines[3] == "    }")
    #expect(lines[4] == "}")
}

/// Indentation must scale monotonically with the x-gap (a deeper line never gets
/// fewer spaces than a shallower one).
@Test func preserveLayout_indentationIsMonotonicWithLeftEdge() {
    let recognized = RecognizedText(lines: [
        line("a", left: 0.10, top: 0.9),
        line("b", left: 0.13, top: 0.8),
        line("c", left: 0.16, top: 0.7),
        line("d", left: 0.22, top: 0.6),
    ])
    let lines = LayoutProcessor.format(recognized, mode: .preserveLayout)
        .components(separatedBy: "\n")
    func leadingSpaces(_ s: String) -> Int {
        s.prefix { $0 == " " }.count
    }
    #expect(leadingSpaces(lines[0]) == 0)
    #expect(leadingSpaces(lines[1]) <= leadingSpaces(lines[2]))
    #expect(leadingSpaces(lines[2]) <= leadingSpaces(lines[3]))
    #expect(leadingSpaces(lines[3]) > 0)
}

/// Spec scenario: "Paragraph capture in merge-lines mode"
@Test func paragraphCaptureInMergeLinesMode() {
    // A soft-wrapped paragraph: all lines share the same left edge, none ends on
    // sentence-final punctuation until the last.
    let recognized = RecognizedText(lines: [
        line("The quick brown fox jumps over", left: 0.10, top: 0.90),
        line("the lazy dog and then keeps", left: 0.10, top: 0.84),
        line("running into the sunset.", left: 0.10, top: 0.78),
    ])
    let out = LayoutProcessor.format(recognized, mode: .mergeLines)
    #expect(out == "The quick brown fox jumps over the lazy dog and then keeps running into the sunset.")
    #expect(!out.contains("\n")) // no mid-sentence linebreaks
}

/// merge-lines starts a new paragraph after sentence-final punctuation.
@Test func mergeLines_splitsParagraphsOnSentenceEnd() {
    let recognized = RecognizedText(lines: [
        line("First paragraph wraps", left: 0.1, top: 0.9),
        line("onto a second line.", left: 0.1, top: 0.84),
        line("Second paragraph begins", left: 0.1, top: 0.74),
        line("here and wraps too.", left: 0.1, top: 0.68),
    ])
    let out = LayoutProcessor.format(recognized, mode: .mergeLines)
    let paragraphs = out.components(separatedBy: "\n\n")
    #expect(paragraphs.count == 2)
    #expect(paragraphs[0] == "First paragraph wraps onto a second line.")
    #expect(paragraphs[1] == "Second paragraph begins here and wraps too.")
}

// raw-lines: one recognized line per output line, no indentation reconstruction.
@Test func rawLines_oneLinePerLineNoIndent() {
    let recognized = RecognizedText(lines: [
        line("func main() {", left: 0.10, top: 0.9),
        line("indented body", left: 0.20, top: 0.8), // deep indent ignored
        line("}", left: 0.10, top: 0.7),
    ])
    let out = LayoutProcessor.format(recognized, mode: .rawLines)
    #expect(out == "func main() {\nindented body\n}")
    #expect(!out.contains("  ")) // no reconstructed indentation
}

/// Empty recognition yields an empty string in every mode (the pipeline turns this
/// into the honest empty result; the processor itself never fabricates).
@Test func layoutProcessor_emptyInputYieldsEmptyString() {
    for mode in LayoutMode.allCases {
        #expect(LayoutProcessor.format(RecognizedText(), mode: mode) == "")
        #expect(LayoutProcessor.format(RecognizedText(lines: [line("   ", left: 0.1, top: 0.5)]), mode: mode) == "")
    }
}

/// LayoutMode is Codable (it persists in settings — spec: "Mode change persists").
@Test func layoutMode_isCodableForPersistence() throws {
    for mode in LayoutMode.allCases {
        let data = try JSONEncoder().encode(mode)
        let decoded = try JSONDecoder().decode(LayoutMode.self, from: data)
        #expect(decoded == mode)
    }
}
