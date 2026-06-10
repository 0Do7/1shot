import Testing
@testable import OneShotCapture

@Test func packageBuildsAndLinks() {
    #expect(OneShotCaptureInfo.packageName == "OneShotCapture")
}
