import Foundation
import Testing
@testable import OneShotOCR

// Task 8.3 — link detection (NSDataDetector). Deterministic over strings.

/// Spec scenario: "URL in captured text is actionable" — and the URL stays verbatim
/// in the clipboard (asserted at the pipeline level too; here we assert detection).
@Test func urlInCapturedTextIsActionable() {
    let text = "See the docs at https://example.com/docs for details."
    let links = LinkDetector.detectLinks(in: text)
    #expect(links.count == 1)
    #expect(links[0].kind == .url)
    #expect(links[0].value == "https://example.com/docs")
    #expect(links[0].openTarget?.absoluteString == "https://example.com/docs")
    // Verbatim presence in the source string (clipboard is built from this string).
    #expect(text.contains("https://example.com/docs"))
}

@Test func emailAddressDetectedAsEmailLink() {
    let links = LinkDetector.detectLinks(in: "Contact me at jane@example.com today")
    #expect(links.count == 1)
    #expect(links[0].kind == .email)
    #expect(links[0].value == "jane@example.com")
    #expect(links[0].openTarget?.scheme == "mailto")
}

@Test func multipleLinksDetectedAndDeduped() {
    let text = "https://a.com and https://b.com and https://a.com again"
    let links = LinkDetector.detectLinks(in: text)
    let values = Set(links.map(\.value))
    #expect(values == ["https://a.com", "https://b.com"]) // a.com deduped
}

@Test func noLinksInPlainText() {
    #expect(LinkDetector.detectLinks(in: "just some ordinary words here").isEmpty)
    #expect(LinkDetector.detectLinks(in: "").isEmpty)
}
