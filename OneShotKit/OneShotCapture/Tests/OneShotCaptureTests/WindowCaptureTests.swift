import AppKit
import CoreGraphics
import Foundation
import OneShotCore
import Testing
@testable import OneShotCapture

// MARK: - Pick-list filtering (pure, no permission)

private func window(
    id: UInt32,
    bundleID: String? = "com.example.app",
    frame: LogicalRect = LogicalRect(x: 0, y: 0, width: 400, height: 300),
    onScreen: Bool = true,
    layer: Int = 0
) -> WindowDescriptor {
    WindowDescriptor(
        windowID: id,
        owningAppBundleID: bundleID,
        frame: frame,
        isOnScreen: onScreen,
        windowLayer: layer
    )
}

private func snapshot(_ windows: [WindowDescriptor]) -> ShareableContentSnapshot {
    ShareableContentSnapshot(layout: DisplayLayout(displays: []), windows: windows)
}

@Test func capturableWindows_keepsNormalOnScreenWindowsInSnapshotOrder() {
    let windows = [window(id: 1), window(id: 2), window(id: 3)]
    #expect(ShareableContentService.capturableWindows(from: snapshot(windows)).map(\.windowID) == [1, 2, 3])
}

@Test func capturableWindows_dropsNonZeroLayers() {
    let windows = [window(id: 1, layer: 25), window(id: 2), window(id: 3, layer: 3)]
    #expect(ShareableContentService.capturableWindows(from: snapshot(windows)).map(\.windowID) == [2])
}

@Test func capturableWindows_dropsOffScreenWindows() {
    let windows = [window(id: 1, onScreen: false), window(id: 2)]
    #expect(ShareableContentService.capturableWindows(from: snapshot(windows)).map(\.windowID) == [2])
}

@Test func capturableWindows_dropsTinyWindows() {
    let windows = [
        window(id: 1, frame: LogicalRect(x: 0, y: 0, width: 49, height: 300)),
        window(id: 2, frame: LogicalRect(x: 0, y: 0, width: 300, height: 49)),
        window(id: 3, frame: LogicalRect(x: 0, y: 0, width: 50, height: 50)),
    ]
    #expect(ShareableContentService.capturableWindows(from: snapshot(windows)).map(\.windowID) == [3])
}

@Test func capturableWindows_dropsOurOwnWindows() {
    let windows = [
        window(id: 1, bundleID: "com.sidequests.oneshot"),
        window(id: 2, bundleID: nil),
        window(id: 3),
    ]
    #expect(ShareableContentService.capturableWindows(from: snapshot(windows)).map(\.windowID) == [2, 3])
}

// MARK: - Configuration mapping (pure, no permission)

private let retina2x = DisplayDescriptor(
    id: 1,
    logicalFrame: LogicalRect(x: 0, y: 0, width: 1512, height: 982),
    scale: 2
)

@Test func shadowConfiguration_expandsByMarginAtNativeDensity() {
    let (configuration, region) = StillCaptureService.shadowConfiguration(
        windowFrame: LogicalRect(x: 300, y: 200, width: 400, height: 300),
        display: retina2x,
        options: CaptureOptions()
    )
    // 100pt margin on every side, in display-local points.
    #expect(configuration.sourceRect == CGRect(x: 200, y: 100, width: 600, height: 500))
    // Output pinned to native pixels of the same rect (2x).
    #expect(configuration.width == 1200)
    #expect(configuration.height == 1000)
    #expect(configuration.shouldBeOpaque == false)
    #expect(configuration.showsCursor == false)
    #expect(configuration.pixelFormat == kCVPixelFormatType_32BGRA)
    #expect(region == PixelRect(x: 400, y: 200, width: 1200, height: 1000))
}

@Test func shadowConfiguration_regionMayExtendPastDisplayEdges() {
    // Window hugging the display's top-left corner: the margin goes negative
    // instead of being clamped (ScreenCaptureKit maps sourceRect 1:1 there).
    let (configuration, region) = StillCaptureService.shadowConfiguration(
        windowFrame: LogicalRect(x: 10, y: 20, width: 400, height: 300),
        display: retina2x,
        options: CaptureOptions()
    )
    #expect(configuration.sourceRect.origin == CGPoint(x: -90, y: -80))
    #expect(region == PixelRect(x: -180, y: -160, width: 1200, height: 1000))
}

@Test func tightConfiguration_matchesWindowFrameAtNativeDensity() {
    let (configuration, region) = StillCaptureService.tightConfiguration(
        windowFrame: LogicalRect(x: 300, y: 200, width: 400, height: 300),
        display: retina2x,
        options: CaptureOptions(includeCursor: true)
    )
    #expect(configuration.width == 800)
    #expect(configuration.height == 600)
    #expect(configuration.ignoreShadowsSingleWindow == true)
    #expect(configuration.shouldBeOpaque == false)
    #expect(configuration.showsCursor == true)
    #expect(region == PixelRect(x: 600, y: 400, width: 800, height: 600))
}

@Test func tightConfiguration_usesOwningDisplayScaleFor1x() {
    let external1x = DisplayDescriptor(
        id: 2,
        logicalFrame: LogicalRect(x: 1512, y: 0, width: 1920, height: 1080),
        scale: 1
    )
    let (configuration, region) = StillCaptureService.tightConfiguration(
        windowFrame: LogicalRect(x: 1600, y: 100, width: 400, height: 300),
        display: external1x,
        options: CaptureOptions()
    )
    #expect(configuration.width == 400)
    #expect(configuration.height == 300)
    #expect(region == PixelRect(x: 88, y: 100, width: 400, height: 300))
}

// MARK: - Alpha-extent trim (pure, no permission)

private struct SeedPixel {
    var x: Int
    var y: Int
    var alpha: UInt8
}

private func bitmap(width: Int, height: Int, opaque: [SeedPixel]) -> BGRABitmap {
    var data = Data(count: width * height * 4)
    for pixel in opaque {
        data[(pixel.y * width + pixel.x) * 4 + 3] = pixel.alpha
    }
    return BGRABitmap(data: data, width: width, height: height)
}

@Test func alphaBounds_findsExtentWithPadding() {
    let map = bitmap(
        width: 100,
        height: 80,
        opaque: [SeedPixel(x: 30, y: 20, alpha: 128), SeedPixel(x: 60, y: 50, alpha: 255)]
    )
    #expect(map.alphaBounds(padding: 2) == PixelRect(x: 28, y: 18, width: 35, height: 35))
}

@Test func alphaBounds_clampsPaddingToBitmap() {
    let map = bitmap(
        width: 10,
        height: 10,
        opaque: [SeedPixel(x: 0, y: 0, alpha: 1), SeedPixel(x: 9, y: 9, alpha: 255)]
    )
    #expect(map.alphaBounds(padding: 3) == PixelRect(x: 0, y: 0, width: 10, height: 10))
}

@Test func alphaBounds_nilWhenFullyTransparent() {
    let map = bitmap(width: 8, height: 8, opaque: [])
    #expect(map.alphaBounds(padding: 2) == nil)
}

@Test func bgraBitmap_makeImagePreservesAlphaChannel() throws {
    let map = bitmap(width: 4, height: 4, opaque: [SeedPixel(x: 1, y: 2, alpha: 200)])
    let image = try #require(map.makeImage())
    let sampler = AlphaSampler(image)
    #expect(sampler.alpha(1, 2) == 200)
    #expect(sampler.alpha(0, 0) == 0)
}

// MARK: - Live window capture (needs Screen Recording; runs on dev machines)

private let hasScreenRecording = CGPreflightScreenCaptureAccess()

/// Renders a CGImage into straight RGBA8 so per-pixel alpha is assertable.
private struct AlphaSampler {
    let width: Int
    let height: Int
    private let buffer: [UInt8]

    init(_ image: CGImage) {
        width = image.width
        height = image.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        self.buffer = buffer
    }

    func alpha(_ x: Int, _ y: Int) -> UInt8 {
        buffer[(y * width + x) * 4 + 3]
    }

    var partialAlphaCount: Int {
        var count = 0
        for index in stride(from: 3, to: buffer.count, by: 4) where buffer[index] > 0 && buffer[index] < 255 {
            count += 1
        }
        return count
    }
}

private struct HostWindowError: Error {}

/// Synchronous on purpose: `RunLoop.run(until:)` is unavailable from async
/// contexts, but hopping through a sync function is exactly the supported way
/// to pump AppKit from an async test.
@MainActor
private func pumpMainRunLoop(for interval: TimeInterval) {
    RunLoop.current.run(until: Date().addingTimeInterval(interval))
}

/// Live tests host a real titled NSWindow (package test targets on macOS may
/// import AppKit). Serialized: they share the main actor, a real window
/// server session, and z-order assumptions.
@MainActor
@Suite(.serialized, .enabled(if: hasScreenRecording))
struct LiveWindowCaptureTests {
    /// Shows a window, waits until ScreenCaptureKit can enumerate it AND its
    /// reported frame is stable. Pumping the main run loop lets AppKit flush
    /// the window to the server — the test process has no NSApplication run
    /// loop of its own. Stability matters: for ~150ms after ordering front,
    /// the window server transiently reports the frame 1pt wider per side
    /// (observed live on macOS 26.3), which would skew tight-bounds asserts.
    private func withHostWindow<T>(
        _ body: (WindowDescriptor, ShareableContentSnapshot) async throws -> T
    ) async throws -> T {
        _ = NSApplication.shared
        let host = NSWindow(
            contentRect: NSRect(x: 320, y: 320, width: 360, height: 240),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        host.title = "OneShotWindowCaptureTest"
        host.backgroundColor = .systemOrange
        host.isReleasedWhenClosed = false
        host.orderFrontRegardless()
        defer { host.orderOut(nil) }
        var previous: (WindowDescriptor, ShareableContentSnapshot)?
        var stableRounds = 0
        for _ in 0 ..< 50 {
            pumpMainRunLoop(for: 0.1)
            let snapshot = try await ShareableContentService.snapshot()
            guard let descriptor = snapshot.windows.first(where: { $0.windowID == UInt32(host.windowNumber) })
            else { continue }
            stableRounds = descriptor.frame == previous?.0.frame ? stableRounds + 1 : 0
            previous = (descriptor, snapshot)
            if stableRounds >= 2 {
                return try await body(descriptor, snapshot)
            }
        }
        throw HostWindowError()
    }

    /// Spec scenario: "Window captured with transparent shadow".
    @Test func windowCapture_shadowMode_producesTrueAlphaShadow() async throws {
        try await withHostWindow { descriptor, snapshot in
            let frame = try await StillCaptureService().captureWindow(descriptor, shadow: true)
            let display = try #require(snapshot.layout.display(bestFor: descriptor.frame))
            #expect(frame.scale == display.scale)
            // Output is wider than the bare window: shadow + trim padding.
            let windowPixelWidth = Int((descriptor.frame.width * display.scale).rounded())
            #expect(frame.image.width > windowPixelWidth)
            #expect(frame.image.width == frame.pixels.width)
            #expect(frame.image.height == frame.pixels.height)

            let sampler = AlphaSampler(frame.image)
            // Corners: fully transparent (outside window + shadow).
            #expect(sampler.alpha(0, 0) == 0)
            #expect(sampler.alpha(sampler.width - 1, 0) == 0)
            #expect(sampler.alpha(0, sampler.height - 1) == 0)
            #expect(sampler.alpha(sampler.width - 1, sampler.height - 1) == 0)
            // Window interior: fully opaque.
            #expect(sampler.alpha(sampler.width / 2, sampler.height / 2) == 255)
            // Shadow band: a substantial number of partially transparent
            // pixels (live probe measured >100k for a 400x300pt window; the
            // window's anti-aliased corners alone are only a few hundred).
            #expect(sampler.partialAlphaCount > 5000)
        }
    }

    /// Spec scenario: "Shadowless window capture" — tight bounds, no shadow.
    @Test func windowCapture_shadowlessMode_tightBoundsNoShadowPixels() async throws {
        try await withHostWindow { descriptor, snapshot in
            let frame = try await StillCaptureService().captureWindow(descriptor, shadow: false)
            let display = try #require(snapshot.layout.display(bestFor: descriptor.frame))
            #expect(frame.image.width == Int((descriptor.frame.width * display.scale).rounded()))
            #expect(frame.image.height == Int((descriptor.frame.height * display.scale).rounded()))

            let sampler = AlphaSampler(frame.image)
            // Edge midpoints are window content, fully opaque (corners are
            // legitimately transparent: macOS windows have rounded corners).
            #expect(sampler.alpha(sampler.width / 2, 0) == 255)
            #expect(sampler.alpha(sampler.width / 2, sampler.height - 1) == 255)
            #expect(sampler.alpha(0, sampler.height / 2) == 255)
            #expect(sampler.alpha(sampler.width - 1, sampler.height / 2) == 255)
            // No shadow band: only the rounded-corner anti-aliasing is
            // partially transparent (hundreds of pixels, not tens of thousands).
            #expect(sampler.partialAlphaCount < 5000)
        }
    }

    /// Spec scenario: "Window capture of a window on a secondary display" —
    /// single-display machines exercise the same path: output density matches
    /// the owning display's scale.
    @Test func windowCapture_outputMatchesOwningDisplayDensity() async throws {
        try await withHostWindow { descriptor, snapshot in
            let display = try #require(snapshot.layout.display(bestFor: descriptor.frame))
            let frame = try await StillCaptureService().captureWindow(descriptor, shadow: false)
            #expect(frame.scale == display.scale)
            #expect(frame.displayID == display.id)
            #expect(Double(frame.image.width) == (descriptor.frame.width * display.scale).rounded())
        }
    }

    @Test func windowCapture_goneWindowThrowsWindowNotFound() async throws {
        let ghost = WindowDescriptor(
            windowID: .max,
            frame: LogicalRect(x: 0, y: 0, width: 100, height: 100),
            isOnScreen: true,
            windowLayer: 0
        )
        await #expect(throws: CaptureError.windowNotFound(.max)) {
            _ = try await StillCaptureService().captureWindow(ghost)
        }
    }
}
