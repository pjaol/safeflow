import XCTest

final class SafeflowUITestsLaunchTests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify initial launch screen
        XCTAssertTrue(app.otherElements["LaunchScreen"].exists)
    }
} 