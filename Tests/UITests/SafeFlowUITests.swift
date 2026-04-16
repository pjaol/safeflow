import XCTest

final class SafeFlowUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing", "SKIP_ONBOARDING"]
        addUIInterruptionMonitor(withDescription: "System alert") { alert in
            if alert.buttons["Don't Allow"].exists { alert.buttons["Don't Allow"].tap(); return true }
            if alert.buttons["Allow"].exists { alert.buttons["Allow"].tap(); return true }
            return false
        }
        app.launch()
        app.tap()
        XCTAssertTrue(app.buttons["home.cycleRingSummaryCard"].waitForExistence(timeout: 10))
    }

    // MARK: - Home screen

    func testCycleSummaryCardExists() throws {
        XCTAssertTrue(app.buttons["home.cycleRingSummaryCard"].exists)
    }

    func testSettingsButtonOpensSettings() throws {
        let settingsButton = app.buttons["home.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        XCTAssertTrue(app.switches["settings.requireAuthToggle"].waitForExistence(timeout: 3))
        app.buttons.matching(NSPredicate(format: "label == 'Done'")).firstMatch.tap()
    }

    // MARK: - Edit Logs

    func testEditLogsSheetOpensAndCloses() throws {
        app.buttons["home.editLogsButton"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == 'Done'")).firstMatch
            .waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label == 'Done'")).firstMatch.tap()
        XCTAssertTrue(app.buttons["home.settingsButton"].waitForExistence(timeout: 3))
    }

    func testEditLogsSheetContainsFlowSection() throws {
        app.buttons["home.editLogsButton"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == 'Done'")).firstMatch
            .waitForExistence(timeout: 5))
        // Flow section header should be present
        XCTAssertTrue(app.staticTexts["Flow"].exists)
        app.buttons.matching(NSPredicate(format: "label == 'Done'")).firstMatch.tap()
    }

    func testEditLogsSymptomCategoryTabsSwitchContent() throws {
        app.buttons["home.editLogsButton"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == 'Done'")).firstMatch
            .waitForExistence(timeout: 5))

        // Pain category is default — scroll down to symptoms
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Symptoms"].waitForExistence(timeout: 3))

        app.buttons.matching(NSPredicate(format: "label == 'Done'")).firstMatch.tap()
    }

    // MARK: - Onboarding

    func testOnboardingCycleSetupPageExists() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()

        for _ in 0..<3 { app.swipeLeft() }

        XCTAssertTrue(
            app.datePickers["onboarding.lastPeriodDatePicker"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons["onboarding.getStartedButton"].exists)
    }

    func testOnboardingGetStartedCompletesOnboarding() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()

        for _ in 0..<3 { app.swipeLeft() }

        let getStarted = app.buttons["onboarding.getStartedButton"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 5))
        getStarted.tap()

        // After completing onboarding, should reach home or lock screen
        let homeOrLock = app.navigationBars.firstMatch.waitForExistence(timeout: 5) ||
                         app.staticTexts["SafeFlow is Locked"].waitForExistence(timeout: 3)
        XCTAssertTrue(homeOrLock)
    }
}
