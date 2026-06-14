import CoreGraphics
import Foundation
import ImageIO
import OneShotCapture
import OneShotLibrary
import OneShotLicensing
import OneShotOCR
import Testing
import UniformTypeIdentifiers
@testable import OneShot

// Dispatcher routing + gate-integration coverage with a fully faked environment.
// This is where the spec's end-to-end scenarios live: an expired-trial workflow
// fails capture honestly while search keeps working; a missing-permission capture
// names the permission; a disabled scheme is rejected; confirmation can decline.

// MARK: Fakes

private struct FakeRecognizer: TextRecognizing {
    let text: String
    func recognizeText(in _: CGImage, options _: RecognitionOptions) throws -> RecognizedText {
        guard !text.isEmpty else { return RecognizedText() }
        let line = RecognizedTextLine(
            text: text,
            boundingBox: NormalizedRect(x: 0, y: 0, width: 1, height: 0.1),
            confidence: 0.99
        )
        return RecognizedText(lines: [line], languages: ["en-US"])
    }
}

private struct FakeBarcodes: BarcodeDetecting {
    func detectCodes(in _: CGImage) throws -> [DetectedCode] {
        []
    }
}

@MainActor
private final class FakeEnvironment: AutomationEnvironment {
    var licenseState: LicenseState = .licensed
    var urlSchemeEnabled = true
    var confirmationMode: ConfirmationMode = .silent
    var screenRecordingGranted = true
    var confirmResponse = true
    var ocrRegionText = "region text"

    private(set) var startedCaptures: [CaptureMode] = []
    private(set) var pinnedPaths: [String?] = []
    private(set) var togglePinsCount = 0
    private(set) var searchQueries: [String] = []
    private(set) var openedPanes: [SettingsPane] = []
    private(set) var confirmedActions: [AutomationAction] = []

    var ocrPipeline = OCRPipeline(recognizer: FakeRecognizer(text: "fileText"), barcodeDetector: FakeBarcodes())

    func startCapture(_ mode: CaptureMode) {
        startedCaptures.append(mode)
    }

    func ocrRegion() async throws -> String {
        ocrRegionText
    }

    func pin(path: String?) throws {
        pinnedPaths.append(path)
    }

    func toggleAllPins() {
        togglePinsCount += 1
    }

    func openSearch(query: String) {
        searchQueries.append(query)
    }

    func openSettings(pane: SettingsPane) {
        openedPanes.append(pane)
    }

    func confirm(action: AutomationAction) async -> Bool {
        confirmedActions.append(action)
        return confirmResponse
    }

    func librarySearch() -> LibrarySearch? {
        nil
    }
}

@MainActor
private func makeDispatcher(_ configure: (FakeEnvironment) -> Void = { _ in
}) -> (AutomationDispatcher, FakeEnvironment) {
    let env = FakeEnvironment()
    configure(env)
    return (AutomationDispatcher(environment: env), env)
}

// MARK: Capture routing (spec: "Capture intent feeds a shortcut" / "Spotlight action invocation")

@MainActor @Test func dispatch_captureFullscreen_routesToCoordinator() async throws {
    let (dispatcher, env) = makeDispatcher()
    let result = try await dispatcher.run(.capture(.fullscreen), source: .appIntent)
    #expect(result == .ok)
    #expect(env.startedCaptures == [.fullscreen])
}

@MainActor @Test func dispatch_captureArea_startsAreaFlow() async throws {
    let (dispatcher, env) = makeDispatcher()
    _ = try await dispatcher.run(.capture(.area), source: .appIntent)
    #expect(env.startedCaptures == [.area])
}

// MARK: OCR on file (spec: "OCR intent returns text" — on-device, returns string)

@MainActor @Test func dispatch_ocrImage_returnsRecognizedText() async throws {
    let (dispatcher, _) = makeDispatcher { $0.ocrPipeline = OCRPipeline(
        recognizer: FakeRecognizer(text: "extracted code"),
        barcodeDetector: FakeBarcodes()
    ) }
    let path = try writeTempImage()
    defer { try? FileManager.default.removeItem(atPath: path) }

    let result = try await dispatcher.run(.ocrImage(path: path), source: .appIntent)
    #expect(result == .text("extracted code"))
}

@MainActor @Test func dispatch_ocrImage_emptyRecognition_returnsEmptyString() async throws {
    // Honest empty result: no text found is "", never garbage (spec law).
    let (dispatcher, _) = makeDispatcher { $0.ocrPipeline = OCRPipeline(
        recognizer: FakeRecognizer(text: ""),
        barcodeDetector: FakeBarcodes()
    ) }
    let path = try writeTempImage()
    defer { try? FileManager.default.removeItem(atPath: path) }

    let result = try await dispatcher.run(.ocrImage(path: path), source: .appIntent)
    #expect(result == .text(""))
}

@MainActor @Test func dispatch_ocrImage_missingFile_throwsFileNotReadable() async {
    let (dispatcher, _) = makeDispatcher()
    await #expect(throws: AutomationError.fileNotReadable("/no/such/file.png")) {
        _ = try await dispatcher.run(.ocrImage(path: "/no/such/file.png"), source: .appIntent)
    }
}

// MARK: Permission (spec: "Intent without required permission")

@MainActor @Test func dispatch_captureWithoutPermission_throwsNamingPermission() async {
    let (dispatcher, env) = makeDispatcher { $0.screenRecordingGranted = false }
    await #expect(throws: AutomationError.screenRecordingPermissionMissing) {
        _ = try await dispatcher.run(.capture(.fullscreen), source: .appIntent)
    }
    #expect(env.startedCaptures.isEmpty) // no blank capture attempted
}

@MainActor @Test func dispatch_ocrImageWithoutPermission_stillWorks() async throws {
    // OCR-on-file needs no Screen Recording permission (spec privacy posture).
    let (dispatcher, _) = makeDispatcher { $0.screenRecordingGranted = false }
    let path = try writeTempImage()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let result = try await dispatcher.run(.ocrImage(path: path), source: .appIntent)
    #expect(result == .text("fileText"))
}

// MARK: Expired trial honesty (spec: "Expired trial blocks automated capture honestly")

@MainActor @Test func dispatch_expiredTrial_captureFails_searchStillWorks() async throws {
    let (dispatcher, env) = makeDispatcher { $0.licenseState = .expired }

    // Capture in the same "workflow" fails with the contracted licensing error…
    await #expect(throws: AutomationError.captureRequiresLicense) {
        _ = try await dispatcher.run(.capture(.fullscreen), source: .appIntent)
    }
    #expect(env.startedCaptures.isEmpty)

    // …while the Library-search step in the same workflow still runs.
    let searchResult = try await dispatcher.run(.search(query: "stripe"), source: .appIntent)
    #expect(searchResult == .ok)
    #expect(env.searchQueries == ["stripe"])
}

// MARK: URL scheme disabled (spec: "Scheme call while disabled")

@MainActor @Test func dispatch_schemeDisabled_rejects_noAction() async {
    let (dispatcher, env) = makeDispatcher { $0.urlSchemeEnabled = false }
    await #expect(throws: AutomationError.urlSchemeDisabled) {
        _ = try await dispatcher.run(.capture(.fullscreen), source: .urlScheme)
    }
    #expect(env.startedCaptures.isEmpty)
}

@MainActor @Test func dispatch_schemeDisabled_appIntentUnaffected() async throws {
    // The same action via an AppIntent is not gated by the URL switch.
    let (dispatcher, env) = makeDispatcher { $0.urlSchemeEnabled = false }
    _ = try await dispatcher.run(.capture(.fullscreen), source: .appIntent)
    #expect(env.startedCaptures == [.fullscreen])
}

// MARK: Confirmation (spec: "Confirmation mode")

@MainActor @Test func dispatch_alwaysConfirm_approve_proceeds() async throws {
    let (dispatcher, env) = makeDispatcher {
        $0.confirmationMode = .alwaysConfirm
        $0.confirmResponse = true
    }
    _ = try await dispatcher.run(.capture(.fullscreen), source: .urlScheme)
    #expect(env.confirmedActions == [.capture(.fullscreen)])
    #expect(env.startedCaptures == [.fullscreen])
}

@MainActor @Test func dispatch_alwaysConfirm_decline_cancels() async {
    let (dispatcher, env) = makeDispatcher {
        $0.confirmationMode = .alwaysConfirm
        $0.confirmResponse = false
    }
    await #expect(throws: AutomationError.cancelledByUser) {
        _ = try await dispatcher.run(.capture(.fullscreen), source: .urlScheme)
    }
    #expect(env.startedCaptures.isEmpty) // declined → no capture
}

@MainActor @Test func dispatch_forceConfirm_promptsEvenUnderSilentMode() async throws {
    // The per-call confirm=1 flag forces a prompt even when the mode is silent.
    let (dispatcher, env) = makeDispatcher { $0.confirmationMode = .silent }
    _ = try await dispatcher.run(.capture(.fullscreen), source: .urlScheme, forceConfirm: true)
    #expect(env.confirmedActions == [.capture(.fullscreen)])
}

// MARK: Non-side-effecting routing

@MainActor @Test func dispatch_pinsToggle_routes() async throws {
    let (dispatcher, env) = makeDispatcher()
    _ = try await dispatcher.run(.hideShowAllPins, source: .appIntent)
    #expect(env.togglePinsCount == 1)
}

@MainActor @Test func dispatch_openSettings_routes() async throws {
    let (dispatcher, env) = makeDispatcher()
    _ = try await dispatcher.run(.openSettings(pane: .automation), source: .appIntent)
    #expect(env.openedPanes == [.automation])
}

// MARK: Helpers

/// Write a tiny valid PNG to a temp path so `ocrImage` can decode it.
@MainActor
private func writeTempImage() throws -> String {
    let context = CGContext(
        data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let image = context.makeImage()!
    let dir = NSTemporaryDirectory()
    let path = (dir as NSString).appendingPathComponent("oneshot-test-\(UUID().uuidString).png")
    let url = URL(fileURLWithPath: path)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    #expect(CGImageDestinationFinalize(dest))
    return path
}
