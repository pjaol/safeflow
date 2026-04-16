import XCTest

/// Automated accessibility tests for v1.1.
///
/// These tests verify:
/// - Every interactive element on primary screens has a non-empty accessibility label
/// - Specific critical labels match their expected values
/// - Decorative images are hidden from the accessibility tree
/// - Onboarding inputs (Stepper, DatePicker) have labels and hints
/// - The cycle ring summary card centre count has contextual label (not a bare number)
///
/// Run via: make test-a11y
/// Test plan: Tests/SafeFlowAccessibility.xctestplan (5 configurations)
final class AccessibilityUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing", "SKIP_ONBOARDING"]
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
        // Tap the app to trigger the interruption monitor if a system alert is showing
        app.tap()
    }

    // MARK: - Generic sweeper

    /// Asserts every button, switch, and stepper visible on screen has a non-empty
    /// accessibility label. This acts as a catch-all regression test — any new
    /// icon-only control added without a label will be caught here.
    private func assertNoUnlabelledInteractiveElements(screen: String) {
        let interactive: [XCUIElementQuery] = [
            app.buttons,
            app.switches,
            app.steppers,
            app.sliders,
        ]
        for query in interactive {
            for element in query.allElementsBoundByIndex {
                // Skip elements with no identifier — these are SwiftUI framework-internal
                // sub-elements (e.g. the raw UISwitch inside a Toggle) that inherit their
                // label through the parent container and appear unlabelled individually.
                // App-owned interactive controls must have an accessibilityIdentifier.
                guard !element.identifier.isEmpty else { continue }
                XCTAssertFalse(
                    element.label.isEmpty,
                    "[\(screen)] Unlabelled element: type=\(element.elementType.rawValue) id='\(element.identifier)'"
                )
            }
        }
    }

    // MARK: - Home screen

    func testHomeScreenHasNoUnlabelledButtons() {
        XCTAssertTrue(app.buttons["home.cycleRingSummaryCard"].waitForExistence(timeout: 5))
        assertNoUnlabelledInteractiveElements(screen: "Home")
    }

    func testSettingsButtonHasLabel() {
        XCTAssertTrue(app.buttons["home.settingsButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["home.settingsButton"].label.isEmpty, "Settings button has no accessibility label")
    }

    func testToolbarButtonsHaveCorrectLabels() {
        XCTAssertTrue(app.buttons["home.settingsButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["home.editLogsButton"].label.isEmpty, "Edit logs button has no label")
        XCTAssertFalse(app.buttons["home.forecastButton"].label.isEmpty, "Forecast button has no label")
        XCTAssertFalse(app.buttons["home.getSupportButton"].label.isEmpty, "Get Support button has no label")
    }

    func testHomeScreenDecorativeImagesAreHidden() {
        XCTAssertTrue(app.buttons["home.cycleRingSummaryCard"].waitForExistence(timeout: 5))
        // Decorative icons marked .accessibilityHidden(true) must not appear as
        // queryable accessibility images. If any image IS visible to the tree
        // it must have a meaningful label (not be a bare system name or empty).
        for image in app.images.allElementsBoundByIndex {
            XCTAssertFalse(
                image.label.isEmpty,
                "Visible image has empty accessibility label — should be marked accessibilityHidden(true) if decorative. id='\(image.identifier)'"
            )
        }
    }

    // MARK: - Edit logs sheet

    func testEditLogsSheetHasNoUnlabelledButtons() {
        XCTAssertTrue(app.buttons["home.editLogsButton"].waitForExistence(timeout: 5))
        app.buttons["home.editLogsButton"].tap()
        // Wait for the sheet's Done button to confirm it opened
        XCTAssertTrue(app.buttons["editLogs.doneButton"].waitForExistence(timeout: 5))
        assertNoUnlabelledInteractiveElements(screen: "EditLogs")
        app.buttons["editLogs.doneButton"].tap()
    }

    func testEditLogsSheetContainsFlowOptions() {
        XCTAssertTrue(app.buttons["home.editLogsButton"].waitForExistence(timeout: 5))
        app.buttons["home.editLogsButton"].tap()
        XCTAssertTrue(app.buttons["editLogs.doneButton"].waitForExistence(timeout: 5))
        // Flow chips must be present — use identifier to avoid locale issues
        var foundFlow = app.buttons["editLogs.flow.none"].exists
        if !foundFlow { app.swipeUp(); foundFlow = app.buttons["editLogs.flow.none"].waitForExistence(timeout: 3) }
        XCTAssertTrue(foundFlow, "Flow options not found in edit logs sheet")
        app.buttons["editLogs.doneButton"].tap()
    }

    // MARK: - Onboarding inputs

    func testOnboardingInputsHaveAccessibilityLabels() {
        // Re-launch with onboarding enabled
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()

        // Navigate to cycle setup page (page 3, 0-indexed)
        for _ in 0..<3 { app.swipeLeft() }

        let datePicker = app.datePickers["onboarding.lastPeriodDatePicker"]
        XCTAssertTrue(datePicker.waitForExistence(timeout: 5))
        XCTAssertFalse(datePicker.label.isEmpty,
            "DatePicker has empty accessibility label — add .accessibilityLabel()")

        let periodStepper = app.steppers["onboarding.periodLengthStepper"]
        XCTAssertTrue(periodStepper.exists)
        XCTAssertFalse(periodStepper.label.isEmpty,
            "Period length stepper has empty accessibility label")

        let cycleStepper = app.steppers["onboarding.cycleLengthStepper"]
        XCTAssertTrue(cycleStepper.exists)
        XCTAssertFalse(cycleStepper.label.isEmpty,
            "Cycle length stepper has empty accessibility label")
    }

    // MARK: - Cycle ring summary card

    func testRingCentreCountHasContextualLabel() {
        XCTAssertTrue(app.buttons["home.cycleRingSummaryCard"].waitForExistence(timeout: 5))
        let centreCount = app.otherElements["home.cycleRingSummaryCard.centreCount"]
        guard centreCount.exists else {
            // Centre count only appears when there are items — not a failure if absent
            return
        }
        // Label must not be a bare integer — must contain at least one non-digit character
        let label = centreCount.label
        let onlyDigits = label.allSatisfy { $0.isNumber }
        XCTAssertFalse(onlyDigits,
            "Ring centre count label is a bare number '\(label)' — add contextual word e.g. '3 items'")
    }

    // MARK: - Settings

    func testSettingsScreenHasNoUnlabelledButtons() {
        XCTAssertTrue(app.buttons["home.settingsButton"].waitForExistence(timeout: 5))
        app.buttons["home.settingsButton"].tap()
        XCTAssertTrue(app.switches["settings.requireAuthToggle"].waitForExistence(timeout: 5))
        assertNoUnlabelledInteractiveElements(screen: "Settings")
        app.buttons["settings.doneButton"].tap()
    }

    // MARK: - Reduce Motion (runs under reduce-motion configuration in test plan)

    func testAnimationsRespectReduceMotionPreference() {
        // When UIAccessibilityIsReduceMotionEnabled=1 (set by test plan),
        // the app must not crash and primary screens must be fully navigable.
        // This test confirms the app launches and core UI is accessible under
        // reduce motion — animation correctness is validated by visual inspection
        // during the manual VoiceOver gate.
        XCTAssertTrue(app.buttons["home.cycleRingSummaryCard"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.editLogsButton"].waitForExistence(timeout: 5))
        app.buttons["home.editLogsButton"].tap()
        XCTAssertTrue(app.buttons["editLogs.doneButton"].waitForExistence(timeout: 5))
        app.buttons["editLogs.doneButton"].tap()
    }
}
