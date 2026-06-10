import Testing
@testable import DarkroomLicensing

@Test func packageBuildsAndLinks() {
    #expect(DarkroomLicensingInfo.packageName == "DarkroomLicensing")
}
