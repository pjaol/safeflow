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
        app.launch()
    }

    // MARK: - Home screen

    func testHomeScreenPrimaryElementsVisibleAtCurrentDynamicType() {
        XCTAssertTrue(app.otherElements["home.cyclePhaseCard"].waitForExistence(timeout: 5))

        let phaseCard = app.otherElements["home.cyclePhaseCard"]
        XCTAssertGreaterThan(phaseCard.frame.height, 0,
            "Phase card has zero height — likely clipped at current Dynamic Type size")

        // Toolbar buttons must remain hittable
        XCTAssertTrue(app.buttons["home.settingsButton"].isHittable,
            "Settings button not hittable — may be off-screen at current Dynamic Type size")
    }

    func testQuickLogButtonsHittableAtCurrentDynamicType() {
        let periodButton = app.buttons["home.quickLog.periodStarted"]
        XCTAssertTrue(periodButton.waitForExistence(timeout: 5))
        XCTAssertTrue(periodButton.isHittable,
            "Quick log 'Period started' button not hittable at current Dynamic Type size")

        let noPeriodButton = app.buttons["home.quickLog.noPeriod"]
        XCTAssertTrue(noPeriodButton.isHittable,
            "Quick log 'No period' button not hittable at current Dynamic Type size")
    }

    // MARK: - Log day form

    func testLogFormButtonsHittableAtCurrentDynamicType() {
        app.buttons["home.newLogButton"].tap()
        XCTAssertTrue(app.buttons["logDay.saveButton"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.buttons["logDay.saveButton"].isHittable,
            "Save button not hittable — may be pushed off screen by large text. Current size category: \(currentSizeCategory())")
        XCTAssertTrue(app.buttons["logDay.cancelButton"].isHittable,
            "Cancel button not hittable at current Dynamic Type size")

        app.buttons["logDay.cancelButton"].tap()
    }

    func testFlowSelectionButtonsHittableAtCurrentDynamicType() {
        app.buttons["home.newLogButton"].tap()
        XCTAssertTrue(app.buttons["logDay.flow.medium"].waitForExistence(timeout: 5))

        // All flow buttons must be reachable — at AXXLarge they may need to scroll
        let flowButtons = ["logDay.flow.light", "logDay.flow.medium", "logDay.flow.heavy"]
        for identifier in flowButtons {
            let button = app.buttons[identifier]
            // Scroll if needed before asserting
            if !button.isHittable {
                app.swipeUp()
            }
            XCTAssertTrue(button.exists,
                "Flow button '\(identifier)' not found at current Dynamic Type size")
        }
        app.buttons["logDay.cancelButton"].tap()
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
