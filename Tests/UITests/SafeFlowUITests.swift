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
        XCTAssertTrue(app.switches["settings.requireAuthToggle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.doneButton"].waitForExistence(timeout: 5))
        app.buttons["settings.doneButton"].tap()
    }

    // MARK: - Edit Logs

    func testEditLogsSheetOpensAndCloses() throws {
        openEditLogsSheet()
        app.buttons["editLogs.doneButton"].tap()
        XCTAssertTrue(app.buttons["home.settingsButton"].waitForExistence(timeout: 3))
    }

    func testEditLogsSheetContainsFlowSection() throws {
        openEditLogsSheet()
        // Flow section contains a None chip — scroll down until found
        var attempts = 0
        while !app.buttons["editLogs.flow.none"].exists && attempts < 5 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(app.buttons["editLogs.flow.none"].exists, "Flow section not found in edit logs sheet")
        app.buttons["editLogs.doneButton"].tap()
    }

    func testEditLogsSymptomCategoryTabsSwitchContent() throws {
        openEditLogsSheet()
        // Scroll down to reach symptom chips
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'editLogs.symptom.'")).firstMatch
                .waitForExistence(timeout: 5),
            "No symptom chips found in edit logs sheet"
        )
        app.buttons["editLogs.doneButton"].tap()
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

    // MARK: - Helpers

    private func openEditLogsSheet() {
        // Tap the first hittable edit-logs button (nav bar or card)
        let buttons = app.buttons.matching(identifier: "home.editLogsButton")
        XCTAssertTrue(buttons.firstMatch.waitForExistence(timeout: 5))
        var tapped = false
        for i in 0..<buttons.count {
            let btn = buttons.element(boundBy: i)
            if btn.isHittable { btn.tap(); tapped = true; break }
        }
        if !tapped { buttons.firstMatch.tap() }
        XCTAssertTrue(app.buttons["editLogs.doneButton"]
            .waitForExistence(timeout: 10))
        sleep(1)
    }
}
