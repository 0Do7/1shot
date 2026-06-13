import Foundation
import OneShotCore
import ScreenCaptureKit
import Testing
@testable import OneShotCapture

// MARK: - CaptureError mapping (S0: -3801 must be distinguishable)

@Test func errorMapping_userDeclined3801_isPermissionDenied() {
    let error = NSError(domain: SCStreamErrorDomain, code: -3801)
    #expect(CaptureError(wrapping: error) == .permissionDenied)
}

@Test func errorMapping_otherSCStreamCode_isCaptureFailed() {
    let error = NSError(domain: SCStreamErrorDomain, code: -3802)
    #expect(CaptureError(wrapping: error) == .captureFailed(domain: SCStreamErrorDomain, code: -3802))
}

@Test func errorMapping_foreignDomain_isCaptureFailed() {
    let error = NSError(domain: NSCocoaErrorDomain, code: -3801)
    #expect(CaptureError(wrapping: error) == .captureFailed(domain: NSCocoaErrorDomain, code: -3801))
}

@Test func errorMapping_captureErrorPassesThrough() {
    #expect(CaptureError(wrapping: CaptureError.displayNotFound(7)) == .displayNotFound(7))
}

// MARK: - Pixel→point configuration mapping (mixed-DPI contract, no permission needed)

private let retina2x = DisplayDescriptor(
    id: 1,
    logicalFrame: LogicalRect(x: 0, y: 0, width: 1512, height: 982),
    scale: 2
)

@Test func stillCapture_configurationPinsNativePixelOutput() {
    let configuration = StillCaptureService.configuration(
        display: retina2x,
        pixels: PixelRect(x: 100, y: 120, width: 200, height: 200),
        options: CaptureOptions()
    )
    // sourceRect is points (pixel / scale); width/height stay in pixels.
    #expect(configuration.sourceRect == CGRect(x: 50, y: 60, width: 100, height: 100))
    #expect(configuration.width == 200)
    #expect(configuration.height == 200)
    #expect(configuration.showsCursor == false)
}

@Test func stillCapture_includeCursorMapsToShowsCursor() {
    let configuration = StillCaptureService.configuration(
        display: retina2x,
        pixels: PixelRect(x: 0, y: 0, width: 100, height: 100),
        options: CaptureOptions(includeCursor: true)
    )
    #expect(configuration.showsCursor == true)
}

@Test func stillCapture_emptyRectThrowsInvalidRect() async {
    await #expect(throws: CaptureError.invalidRect) {
        _ = try await StillCaptureService().capture(
            display: retina2x,
            pixels: PixelRect(x: 0, y: 0, width: 0, height: 100)
        )
    }
}
