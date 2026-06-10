import Testing
@testable import OneShotLibrary

@Test func packageBuildsAndLinks() {
    #expect(OneShotLibraryInfo.packageName == "OneShotLibrary")
}
