import CoreGraphics
import OneShotCore
import Testing
@testable import OneShotCapture

/// Live ScreenCaptureKit tests: they need Screen Recording granted to the test
/// host. CI machines without the permission skip them (never fail) via the
/// enabled trait.
private let hasScreenRecording = CGPreflightScreenCaptureAccess()

@Test(.enabled(if: hasScreenRecording))
func enumeration_returnsMainDisplayFirstWithDerivedScale() async throws {
    let snapshot = try await ShareableContentService.snapshot()
    let displays = snapshot.layout.displays
    #expect(!displays.isEmpty)
    #expect(displays.first?.id == CGMainDisplayID())
    for display in displays {
        #expect(display.scale > 0)
        #expect(display.pixelWidth > 0)
        #expect(display.pixelHeight > 0)
        #expect(!display.logicalFrame.isEmpty)
    }
}

@Test(.enabled(if: hasScreenRecording))
func enumeration_returnsOnScreenWindows() async throws {
    let snapshot = try await ShareableContentService.snapshot()
    // A live GUI session always has at least one on-screen window.
    #expect(!snapshot.windows.isEmpty)
    let offScreen = snapshot.windows.filter { !$0.isOnScreen }
    #expect(offScreen.isEmpty)
}

// Spec: mixed-DPI contract — a 100×100 PIXEL request yields exactly a 100×100
// pixel image regardless of the display's scale factor.
@Test(.enabled(if: hasScreenRecording))
func stillCapture_100PixelRectProducesExactly100PixelImage() async throws {
    let snapshot = try await ShareableContentService.snapshot()
    let display = try #require(snapshot.layout.displays.first)
    let frame = try await StillCaptureService().capture(
        display: display,
        pixels: PixelRect(x: 0, y: 0, width: 100, height: 100)
    )
    #expect(frame.image.width == 100)
    #expect(frame.image.height == 100)
    #expect(frame.type == .image)
    #expect(frame.displayID == display.id)
}

@Test(.enabled(if: hasScreenRecording))
func fullscreenCapture_matchesDisplayNativePixels() async throws {
    let snapshot = try await ShareableContentService.snapshot()
    let display = try #require(snapshot.layout.displays.first)
    let frame = try await StillCaptureService().captureFullDisplay(display)
    #expect(frame.image.width == display.pixelWidth)
    #expect(frame.image.height == display.pixelHeight)
}

@Test(.enabled(if: hasScreenRecording))
func permissionMonitor_livePreflightReportsGranted() async {
    let monitor = PermissionMonitor()
    #expect(await monitor.refreshFromPreflight() == .granted)
}
