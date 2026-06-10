import Testing
@testable import OneShotLicensing

@Test func packageBuildsAndLinks() {
    #expect(OneShotLicensingInfo.packageName == "OneShotLicensing")
}
