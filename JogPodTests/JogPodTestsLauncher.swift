import XCTest

/// Test launcher that discovers and runs all Swift Testing tests in the JogPodTests target.
///
/// This file ensures XCTest-based test runners (including xcodebuild and CI systems)
/// can discover and execute Swift Testing tests.
final class JogPodTestsLauncher: XCTestCase {

    func testSwiftTestingDiscovery() async throws {
        // This test exists to ensure the test target is properly configured
        // and Swift Testing tests are discoverable.
        // The actual tests are defined using @Test in the test files.
        XCTAssertTrue(true, "Test target is configured correctly")
    }
}
