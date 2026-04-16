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
        app.launchArguments = ["UI-Testing", "SKIP_ONBOARDING"]
        app.launch()
        // App must reach a navigable state — either home screen or lock screen
        let launched = app.buttons["home.settingsButton"].waitForExistence(timeout: 10) ||
                       app.staticTexts["SafeFlow is Locked"].waitForExistence(timeout: 10)
        XCTAssertTrue(launched, "App did not reach a navigable state after launch")
    }
}
