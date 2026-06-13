import CoreGraphics
import Foundation
import OneShotCore
import Testing
@testable import OneShotCapture

/// Raw values are routing keys persisted in user settings (OutputRouting) and
/// filename templates — this test freezes them.
@Test func captureMode_rawValuesAreStableRoutingKeys() {
    #expect(CaptureMode.area.rawValue == "area")
    #expect(CaptureMode.window.rawValue == "window")
    #expect(CaptureMode.fullscreen.rawValue == "fullscreen")
    #expect(CaptureMode.repeatArea.rawValue == "repeatArea")
    #expect(CaptureMode.delayed.rawValue == "delayed")
    #expect(CaptureMode.freezeScreen.rawValue == "freezeScreen")
    #expect(CaptureMode.scrolling.rawValue == "scrolling")
    #expect(CaptureMode.allCases.count == 7)
}

// Spec: Domain model carries capture type — the type system admits a video
// case without modification of consumer interfaces (verified at compile time
// by instantiating the reserved case).
@Test func captureType_reservedVideoCaseInstantiatesInConsumerInterfaces() {
    let frame = CapturedFrame(
        type: .video,
        image: solidImage(width: 1, height: 1),
        displayID: 1,
        pixels: PixelRect(x: 0, y: 0, width: 1, height: 1),
        scale: 2
    )
    #expect(frame.type == .video)
    #expect(CaptureType.allCases == [.image, .video])
}

func solidImage(width: Int, height: Int) -> CGImage {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    return context.makeImage()!
}
