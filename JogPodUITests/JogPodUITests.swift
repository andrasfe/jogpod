import XCTest

/// UI Tests for the JogPod application.
///
/// This placeholder class provides the foundation for UI testing.
/// Add UI tests here as the application interface is developed.
final class JogPodUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Clean up after each test
    }

    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify the app launches successfully
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    @MainActor
    func testMainViewDisplays() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify the main navigation title is present
        let navigationBar = app.navigationBars["JogPod"]
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 5))
    }
}
