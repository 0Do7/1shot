import Foundation
import Testing
@testable import OneShotCore

/// Task 2.4: 50-fixture corpus. Expected slugs are EXACT — the namer must be
/// deterministic, and any behavior change must be reviewed against all 50.
private struct Fixture {
    let line: UInt
    let app: String?
    let title: String?
    let ocr: String?
    let expected: String

    init(_ app: String?, _ title: String?, _ ocr: String?, _ expected: String, line: UInt = #line) {
        self.app = app
        self.title = title
        self.ocr = ocr
        self.expected = expected
        self.line = line
    }
}

private let corpus: [Fixture] = [
    // 1 — the spec's flagship example shape (browser + site title + error OCR)
    Fixture(
        "Safari",
        "Webhooks – Stripe Dashboard",
        "Error: webhook delivery failed with status 500",
        "webhooks-stripe-error-delivery"
    ),
    // 2–6 browsers: chrome apps never name the capture
    Fixture(
        "Google Chrome",
        "Fix login race · Pull Request #482 · acme/auth · GitHub",
        nil,
        "fix-login-race-pull"
    ),
    Fixture("Arc", "Design System — Figma", nil, "design-system-figma"),
    Fixture("Firefox", "Inbox (3) - you@example.com - Gmail", nil, "inbox-example-gmail"),
    Fixture("Microsoft Edge", "PROJ-1234 Fix crash on launch - Jira", nil, "proj-fix-crash-launch"),
    Fixture("Brave", "Getting Started | Tailwind CSS", nil, "getting-started-tailwind-css"),
    // 7–10 developer tools
    Fixture("Xcode", "OneShotCore — Package.swift", nil, "xcode-oneshotcore-package-swift"),
    Fixture("Code", "main.swift — myapp", nil, "code-main-swift-myapp"),
    Fixture("Terminal", "~/Sidequests/screenshot — zsh — 120×40", nil, "terminal-sidequests-zsh"),
    Fixture("iTerm2", "ssh prod-web-01", nil, "iterm2-ssh-prod-web"),
    // 11–14 communication
    Fixture("Slack", "#eng-infra | Acme Corp - Slack", nil, "slack-eng-infra-acme-corp"),
    Fixture("Discord", "#general - Dev Server - Discord", nil, "discord-general-dev-server"),
    Fixture("Messages", "Mom", nil, "messages-mom"),
    Fixture("zoom.us", "Zoom Meeting", nil, "zoom-us-meeting"),
    // 15–18 design tools
    Fixture("Figma", "Design System – Components", nil, "figma-design-system-components"),
    Fixture("Sketch", "icons.sketch", nil, "sketch-icons"),
    Fixture("Adobe Photoshop", "hero-banner.psd @ 50%", nil, "adobe-photoshop-hero-banner-psd"),
    Fixture("Pixelmator Pro", "poster final v3", nil, "pixelmator-pro-poster-final-v3"),
    // 19–22 documents
    Fixture("Microsoft Word", "Q3 Report.docx", nil, "word-q3-report-docx"),
    Fixture("Pages", "Essay draft", nil, "pages-essay-draft"),
    Fixture("Notion", "Roadmap 2026 – Acme", nil, "notion-roadmap-acme"),
    Fixture("Google Chrome", "Untitled document - Google Docs", nil, "docs"),
    // 23–26 OCR-driven (no app/title signal)
    Fixture(nil, nil, "func main() { print(\"hello world\") }", "func-main"),
    Fixture(nil, nil, "TOTAL $42.50 Thank you for shopping at Acme Market TOTAL", "total-thank"),
    Fixture(nil, nil, "error error error connection timeout", "error-connection"),
    Fixture("Preview", "imported", nil, "imported"),
    // 27–30 fallback shapes are asserted separately (regex); here: weak signals
    Fixture(nil, "Quarterly Review", nil, "quarterly-review"),
    Fixture("Xcode", nil, nil, "xcode"),
    Fixture(nil, nil, "deploy succeeded", "deploy-succeeded"),
    Fixture("WeChat", "微信", nil, "wechat"), // non-Latin title drops; app still signals
    // 31–35 unicode & normalization
    Fixture("Safari", "Café Müller – Menü", nil, "cafe-muller-menu"),
    Fixture(nil, "🎉 Launch day! 🎉", nil, "launch-day"),
    Fixture("Safari", "Über uns – Straßenbahn München", nil, "uber-uns-strassenbahn-munchen"),
    Fixture("Notes", "Meeting notes 2026-06-09", nil, "notes-meeting"),
    Fixture(nil, "RÉSUMÉ FINAL", nil, "resume-final"),
    // 36–40 edge cases
    Fixture(
        "Adventureworks Enterprises",
        "Extraordinarily Comprehensive Documentation Specification Overview",
        nil,
        "adventureworks-enterprises-extraordinarily-comprehensive"
    ), // 60-char cap at token boundary
    Fixture("Xcode", "Xcode Xcode Build build", nil, "xcode-build"), // dedupe
    Fixture("Calculator", "1234567890", nil, "calculator"), // numbers-only tokens drop
    Fixture("App Store", "Slack 4.39.95", nil, "store-slack"), // version numbers drop
    Fixture("Finder", "/Users/cody/Projects", nil, "users-cody-projects"),
    // 41–45 separator variants
    Fixture(nil, "Dashboard | Analytics | Acme", nil, "analytics-acme"),
    Fixture(nil, "Pricing · Linear", nil, "pricing-linear"),
    Fixture(nil, "docs::api::reference", nil, "docs-api-reference"),
    Fixture(nil, "main - branch - repo", nil, "main-branch-repo"),
    Fixture(nil, "Error: connection refused", nil, "error-connection-refused"),
    // 46–50 combined signals
    Fixture(nil, "Webhooks", "webhook webhooks delivery failed", "webhooks-delivery-failed"), // near-dup OCR filtered
    Fixture("Slack", "DM with Casey", "deploy failed at step build", "slack-dm-casey-deploy-failed"),
    Fixture("Google Chrome", "localhost:3000/admin – DevTools", nil, "localhost-admin-devtools"),
    Fixture(
        "Safari",
        "Plans & Pricing — Acme",
        "Choose the plan that fits your team",
        "plans-pricing-acme-choose-fits"
    ),
    Fixture("QuickTime Player", "Screen Recording 2026-06-09 at 09.41.00", nil, "quicktime-player-screen-recording"),
]

@Test func corpus_of50Fixtures_producesExactSlugs() throws {
    #expect(corpus.count == 50)
    let date = Date(timeIntervalSince1970: 1_780_000_000)
    for fixture in corpus {
        let slug = try AutoNamer.slug(for: CaptureNamingSignals(
            appName: fixture.app,
            windowTitle: fixture.title,
            ocrText: fixture.ocr,
            capturedAt: date,
            timeZone: #require(TimeZone(identifier: "America/Los_Angeles"))
        ))
        #expect(
            slug == fixture.expected,
            "app=\(fixture.app ?? "nil") title=\(fixture.title ?? "nil") → \(slug), expected \(fixture.expected)",
            sourceLocation: SourceLocation(fileID: #fileID, filePath: #filePath, line: Int(fixture.line), column: 1)
        )
    }
}

// Spec: Signal-free capture → timestamp-based fallback, never empty
@Test func signalFreeCapture_getsTimestampFallback() {
    let cases: [CaptureNamingSignals] = [
        .init(capturedAt: Date(timeIntervalSince1970: 1_780_000_000)),
        .init(appName: "", windowTitle: "", ocrText: "", capturedAt: Date(timeIntervalSince1970: 0)),
        .init(windowTitle: "   ", capturedAt: Date(timeIntervalSince1970: 1)),
        .init(appName: "Safari", windowTitle: "Safari", capturedAt: Date(timeIntervalSince1970: 2)),
        .init(ocrText: "to of in at it is", capturedAt: Date(timeIntervalSince1970: 3)),
    ]
    for signals in cases {
        let slug = AutoNamer.slug(for: signals)
        #expect(slug.wholeMatch(of: /capture-\d{4}-\d{2}-\d{2}-at-\d{2}-\d{2}-\d{2}/) != nil, "got: \(slug)")
    }
}

@Test func fallbackTimestamp_usesProvidedTimeZone() throws {
    let signals = try CaptureNamingSignals(
        capturedAt: Date(timeIntervalSince1970: 1_780_000_000),
        timeZone: #require(TimeZone(identifier: "UTC"))
    )
    #expect(AutoNamer.slug(for: signals) == "capture-2026-05-28-at-20-26-40")
}

// Spec: Collision handling — deterministic numeric suffix
@Test func collision_resolvesWithDeterministicSuffix() {
    #expect(AutoNamer.resolvingCollision(of: "shot") { _ in false } == "shot")

    var taken: Set = ["shot"]
    #expect(AutoNamer.resolvingCollision(of: "shot") { taken.contains($0) } == "shot-2")

    taken = ["shot", "shot-2", "shot-3"]
    let resolved = AutoNamer.resolvingCollision(of: "shot") { taken.contains($0) }
    #expect(resolved == "shot-4")
    // Deterministic: same inputs, same answer.
    #expect(AutoNamer.resolvingCollision(of: "shot") { taken.contains($0) } == resolved)
}

@Test func slug_neverExceedsMaxLength_andEndsOnTokenBoundary() {
    for fixture in corpus {
        #expect(fixture.expected.count <= AutoNamer.maxLength)
        #expect(!fixture.expected.hasSuffix("-"))
    }
}
