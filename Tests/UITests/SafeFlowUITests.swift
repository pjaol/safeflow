import XCTest

final class SafeFlowUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Resets all data and skips onboarding for a clean test environment
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }

    // MARK: - Quick Log

    func testQuickLogPeriodStartedFlow() throws {
        let periodButton = app.buttons["home.quickLog.periodStarted"]
        XCTAssertTrue(periodButton.waitForExistence(timeout: 3))
        periodButton.tap()

        // Flow sheet appears
        let mediumButton = app.buttons["quickLog.flow.medium"]
        XCTAssertTrue(mediumButton.waitForExistence(timeout: 2))
        mediumButton.tap()

        // Sheet dismisses, daily log card updates
        XCTAssertTrue(app.otherElements["home.dailyLogCard"].waitForExistence(timeout: 2))
    }

    func testQuickLogNoPeriod() throws {
        let noPeriodButton = app.buttons["home.quickLog.noPeriod"]
        XCTAssertTrue(noPeriodButton.waitForExistence(timeout: 3))
        noPeriodButton.tap()

        XCTAssertTrue(app.otherElements["home.dailyLogCard"].waitForExistence(timeout: 2))
    }

    // MARK: - Full Log Entry

    func testAddNewLogViaDetailForm() throws {
        app.buttons["home.newLogButton"].tap()

        // Select flow
        app.buttons["logDay.flow.medium"].tap()

        // Select a symptom (Pain category is default)
        app.buttons["logDay.symptom.cramps"].tap()

        // Select mood
        app.buttons["logDay.mood.happy"].tap()

        // Save
        app.buttons["logDay.saveButton"].tap()

        // Verify home screen shows the log
        XCTAssertTrue(app.staticTexts["Medium"].waitForExistence(timeout: 2))
    }

    func testCancelLogReturnsToHome() throws {
        app.buttons["home.newLogButton"].tap()
        app.buttons["logDay.flow.light"].tap()
        app.buttons["logDay.cancelButton"].tap()

        XCTAssertTrue(app.navigationBars["SafeFlow"].waitForExistence(timeout: 2))
    }

    func testDeleteLogFromRecentLogs() throws {
        // Add a log first
        app.buttons["home.quickLog.periodStarted"].tap()
        let heavyButton = app.buttons["quickLog.flow.heavy"]
        XCTAssertTrue(heavyButton.waitForExistence(timeout: 2))
        heavyButton.tap()

        // Delete it — delete button includes the day's UUID so we use firstMatch
        let deleteButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'home.recentLog.delete.'")).firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
        deleteButton.tap()

        XCTAssertTrue(app.staticTexts["No recent logs"].waitForExistence(timeout: 2))
    }

    // MARK: - Symptom Category Tabs

    func testSymptomCategoryTabsSwitchContent() throws {
        app.buttons["home.newLogButton"].tap()

        XCTAssertTrue(app.buttons["logDay.symptomCategory.pain"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["logDay.symptom.cramps"].exists)

        app.buttons["logDay.symptomCategory.energy"].tap()
        XCTAssertTrue(app.buttons["logDay.symptom.fatigue"].waitForExistence(timeout: 1))
        XCTAssertFalse(app.buttons["logDay.symptom.cramps"].exists)

        app.buttons["logDay.cancelButton"].tap()
    }

    // MARK: - Settings

    func testSettingsButtonOpensSettings() throws {
        let settingsButton = app.buttons["home.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3))
        settingsButton.tap()

        XCTAssertTrue(app.switches["Require Authentication"].waitForExistence(timeout: 2))
    }

    // MARK: - Onboarding

    func testOnboardingCycleSetupPageExists() throws {
        // UI-Testing launch arg resets onboarding, so we should be on onboarding
        // Swipe through to the cycle setup page (page index 3)
        for _ in 0..<3 {
            app.swipeLeft()
        }

        XCTAssertTrue(
            app.datePickers["onboarding.lastPeriodDatePicker"].waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.buttons["onboarding.getStartedButton"].exists)
    }

    func testOnboardingGetStartedCompletesOnboarding() throws {
        for _ in 0..<3 { app.swipeLeft() }

        let getStarted = app.buttons["onboarding.getStartedButton"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 3))
        getStarted.tap()

        // After completing onboarding, should reach home or lock screen
        let homeOrLock = app.navigationBars["SafeFlow"].waitForExistence(timeout: 3) ||
                         app.staticTexts["SafeFlow is Locked"].waitForExistence(timeout: 3)
        XCTAssertTrue(homeOrLock)
    }

    // MARK: - Phase Card

    func testPhaseCardExists() throws {
        XCTAssertTrue(
            app.otherElements["home.cyclePhaseCard"].waitForExistence(timeout: 3)
        )
    }
}
