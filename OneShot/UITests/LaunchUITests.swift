import XCTest

/// Scaffold XCUITest. Runs only on the self-hosted runner (design D8/D13);
/// onboarding/capture flows land via tasks 12.4 and 15.1.
final class LaunchUITests: XCTestCase {
    @MainActor
    func test_app_launches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertEqual(app.state, .runningBackground, "menu-bar app runs without a foreground window")
    }
}
