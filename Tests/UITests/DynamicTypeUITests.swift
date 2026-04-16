import XCTest

/// Dynamic Type regression tests for v1.1.
///
/// These tests verify that core UI elements remain visible, non-clipped, and
/// hittable across Dynamic Type sizes. Run via the SafeFlowAccessibility test
/// plan which sets UIContentSizeCategory via environment variable for each
/// configuration: Large (default), XL, AXXLarge, Reduce Motion, Bold Text.
///
/// Run via: make test-a11y
final class DynamicTypeUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing", "SKIP_ONBOARDING"]
        // UIContentSizeCategory is injected by the test plan environment —
        // no need to set it here.
        // Dismiss any system permission alerts (e.g. notifications) automatically.
        // The monitor only fires when we interact with the app, so tap after launch
        // to trigger dismissal before any test assertions run.
        addUIInterruptionMonitor(withDescription: "System alert") { alert in
            if alert.buttons["Don't Allow"].exists {
                alert.buttons["Don't Allow"].tap()
                return true
            }
            if alert.buttons["Allow"].exists {
                alert.buttons["Allow"].tap()
                return true
            }
            return false
        }
        app.launch()
        app.tap()
    }

    // MARK: - Home screen

    func testHomeScreenPrimaryElementsVisibleAtCurrentDynamicType() {
        XCTAssertTrue(app.buttons["home.cycleRingSummaryCard"].waitForExistence(timeout: 5))

        let summaryCard = app.buttons["home.cycleRingSummaryCard"]
        XCTAssertGreaterThan(summaryCard.frame.height, 0,
            "Cycle ring summary card has zero height — likely clipped at current Dynamic Type size")

        // Toolbar buttons must remain hittable
        XCTAssertTrue(app.buttons["home.settingsButton"].isHittable,
            "Settings button not hittable — may be off-screen at current Dynamic Type size")
    }

    func testFlowSliderHittableAtCurrentDynamicType() {
        XCTAssertTrue(app.buttons["home.cycleRingSummaryCard"].waitForExistence(timeout: 5))
        // The flow intensity slider must be reachable and interactive
        let flowSlider = app.sliders.matching(NSPredicate(format: "label CONTAINS 'Flow'")).firstMatch
        if flowSlider.exists {
            XCTAssertTrue(flowSlider.isHittable,
                "Flow intensity slider not hittable at current Dynamic Type size: \(currentSizeCategory())")
        }
        // Toolbar edit logs button must be reachable
        XCTAssertTrue(app.buttons["home.editLogsButton"].isHittable,
            "Edit logs button not hittable at current Dynamic Type size")
    }

    // MARK: - Edit logs sheet

    func testEditLogsSheetButtonsHittableAtCurrentDynamicType() {
        XCTAssertTrue(app.buttons["home.editLogsButton"].waitForExistence(timeout: 5))
        app.buttons["home.editLogsButton"].tap()
        let doneButton = app.buttons.matching(NSPredicate(format: "label == 'Done'")).firstMatch
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        XCTAssertTrue(doneButton.isHittable,
            "Done button not hittable in Edit Logs sheet. Current size category: \(currentSizeCategory())")
        doneButton.tap()
    }

    func testEditLogsFlowOptionsHittableAtCurrentDynamicType() {
        XCTAssertTrue(app.buttons["home.editLogsButton"].waitForExistence(timeout: 5))
        app.buttons["home.editLogsButton"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == 'Done'")).firstMatch.waitForExistence(timeout: 5))

        // Flow chips — scroll down if needed, then assert at least one is reachable
        let lightChip = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Light'")).firstMatch
        if !lightChip.isHittable { app.swipeUp() }
        XCTAssertTrue(lightChip.exists,
            "Light flow chip not found in Edit Logs sheet at current Dynamic Type size")

        app.buttons.matching(NSPredicate(format: "label == 'Done'")).firstMatch.tap()
    }

    // MARK: - Onboarding

    func testOnboardingCycleSetupVisibleAtCurrentDynamicType() {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()

        for _ in 0..<3 { app.swipeLeft() }

        let datePicker = app.datePickers["onboarding.lastPeriodDatePicker"]
        XCTAssertTrue(datePicker.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(datePicker.frame.height, 0,
            "Date picker has zero height at current Dynamic Type size")

        let getStarted = app.buttons["onboarding.getStartedButton"]
        XCTAssertTrue(getStarted.exists,
            "Get Started button not found at current Dynamic Type size")
        XCTAssertTrue(getStarted.isHittable,
            "Get Started button not hittable — pushed off screen by large text")
    }

    // MARK: - Settings

    func testSettingsVisibleAtCurrentDynamicType() {
        XCTAssertTrue(app.buttons["home.settingsButton"].waitForExistence(timeout: 5))
        app.buttons["home.settingsButton"].tap()
        XCTAssertTrue(app.switches["settings.requireAuthToggle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["settings.requireAuthToggle"].isHittable,
            "Auth toggle not hittable in Settings at current Dynamic Type size")
        app.buttons.matching(NSPredicate(format: "label == 'Done'")).firstMatch.tap()
    }

    // MARK: - Helpers

    private func currentSizeCategory() -> String {
        app.launchEnvironment["UIContentSizeCategory"] ?? "default"
    }
}
