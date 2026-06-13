import CoreGraphics
import OneShotCapture
import OneShotCore
import Testing
@testable import OneShot

private let retina = DisplayDescriptor(
    id: 1,
    logicalFrame: LogicalRect(x: 0, y: 0, width: 1512, height: 982),
    scale: 2.0
)
private let external1x = DisplayDescriptor(
    id: 2,
    logicalFrame: LogicalRect(x: 1512, y: 0, width: 1920, height: 1080),
    scale: 1.0
)
private let layout = DisplayLayout(displays: [retina, external1x])

// MARK: Mode catalog (Capture modes: invocable by hotkey + from the menu bar)

@Test func catalog_offersAllSixStillModes() {
    let modes = CaptureModeCatalog.entries.map(\.mode)
    #expect(CaptureModeCatalog.entries.count == 6)
    #expect(Set(modes) == [.area, .window, .fullscreen, .repeatArea, .delayed, .freezeScreen])
    #expect(CaptureModeCatalog.entries.allSatisfy { !$0.title.isEmpty })
}

@Test func catalog_mapsActionsToModes() {
    #expect(CaptureModeCatalog.mode(for: .captureFreeze) == .freezeScreen)
    #expect(CaptureModeCatalog.mode(for: .captureRepeat) == .repeatArea)
    #expect(CaptureModeCatalog.mode(for: .captureFullscreen) == .fullscreen)
    // Non-capture actions are not in the still-capture catalog.
    #expect(CaptureModeCatalog.mode(for: .historyTray) == nil)
    #expect(CaptureModeCatalog.mode(for: .captureScrolling) == nil)
}

// MARK: Fullscreen / delayed target

@Test func fullscreen_picksDisplayUnderCursor() {
    let onExternal = CaptureTargeting.fullscreenDisplay(in: layout, cursor: LogicalPoint(x: 2000, y: 500))
    #expect(onExternal?.id == 2)
    let onRetina = CaptureTargeting.fullscreenDisplay(in: layout, cursor: LogicalPoint(x: 100, y: 100))
    #expect(onRetina?.id == 1)
}

@Test func fullscreen_fallsBackToMainWhenCursorOffAllDisplays() {
    let off = CaptureTargeting.fullscreenDisplay(in: layout, cursor: LogicalPoint(x: -9000, y: -9000))
    #expect(off?.id == 1) // main is first in layout
}

// MARK: Repeat-previous-area decision

@MainActor
struct RepeatAreaModelTests {
    @Test func noPriorRegion_fallsBackToArea() {
        let model = RepeatAreaModel()
        #expect(model.decision(in: layout) == .fallbackToArea)
    }

    @Test func priorRegionOnAttachedDisplay_recaptures() {
        let model = RepeatAreaModel()
        model.record(displayID: 2, pixels: PixelRect(x: 10, y: 20, width: 100, height: 80))
        #expect(model.decision(in: layout) == .recapture(
            AreaRegion(displayID: 2, pixels: PixelRect(x: 10, y: 20, width: 100, height: 80))
        ))
    }

    @Test func priorRegionOnDetachedDisplay_fallsBackToArea() {
        let model = RepeatAreaModel()
        model.record(displayID: 99, pixels: PixelRect(x: 0, y: 0, width: 50, height: 50))
        #expect(model.decision(in: layout) == .fallbackToArea)
    }

    @Test func persistenceClosure_receivesRecordedRegion() {
        var saved: AreaRegion?
        let model = RepeatAreaModel(save: { saved = $0 })
        model.record(displayID: 1, pixels: PixelRect(x: 1, y: 2, width: 3, height: 4))
        #expect(saved == AreaRegion(displayID: 1, pixels: PixelRect(x: 1, y: 2, width: 3, height: 4)))
    }
}

// MARK: Delayed countdown

@MainActor
struct CaptureCountdownTests {
    @Test func firesAfterConfiguredTicks() {
        let countdown = CaptureCountdown(seconds: 3)
        #expect(countdown.tick() == false) // 2
        #expect(countdown.tick() == false) // 1
        #expect(countdown.tick() == true) // 0 → fire
        #expect(countdown.isFinished)
    }

    @Test func cancelDuringCountdownPreventsFiring() {
        let countdown = CaptureCountdown(seconds: 3)
        _ = countdown.tick() // 2
        countdown.cancel()
        #expect(countdown.tick() == false)
        #expect(countdown.isCancelled)
        #expect(!countdown.isFinished)
    }
}

// MARK: Freeze-screen — region extracted from the frozen snapshot

@Test func freezeCrop_extractsRegionFromSnapshotAtNativeDensity() {
    let snapshot = solidImage(width: 200, height: 200)
    let frame = AreaSelectionController.croppedFrame(
        from: snapshot,
        display: retina,
        pixels: PixelRect(x: 50, y: 50, width: 100, height: 100)
    )
    #expect(frame?.image.width == 100)
    #expect(frame?.image.height == 100)
    #expect(frame?.displayID == 1)
    #expect(frame?.scale == 2.0)
    #expect(frame?.pixels == PixelRect(x: 50, y: 50, width: 100, height: 100))
}

private func solidImage(width: Int, height: Int) -> CGImage {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}
