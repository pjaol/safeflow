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
        app.launch()
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
                XCTAssertFalse(
                    element.label.isEmpty,
                    "[\(screen)] Unlabelled element: type=\(element.elementType.rawValue) id='\(element.identifier)'"
                )
            }
        }
    }

    // MARK: - Home screen

    func testHomeScreenHasNoUnlabelledButtons() {
        XCTAssertTrue(app.otherElements["home.cyclePhaseCard"].waitForExistence(timeout: 5))
        assertNoUnlabelledInteractiveElements(screen: "Home")
    }

    func testSettingsButtonHasLabel() {
        XCTAssertTrue(app.buttons["home.settingsButton"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["home.settingsButton"].label, "Settings")
    }

    func testToolbarButtonsHaveCorrectLabels() {
        XCTAssertTrue(app.buttons["home.settingsButton"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["home.editLogsButton"].label, "Edit logs")
        XCTAssertEqual(app.buttons["home.forecastButton"].label, "View forecast")
        XCTAssertEqual(app.buttons["home.getSupportButton"].label, "Get Support — resources and helplines")
    }

    func testHomeScreenDecorativeImagesAreHidden() {
        XCTAssertTrue(app.otherElements["home.cyclePhaseCard"].waitForExistence(timeout: 5))
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

    // MARK: - Log day form

    func testLogFormHasNoUnlabelledButtons() {
        app.buttons["home.newLogButton"].tap()
        XCTAssertTrue(app.buttons["logDay.saveButton"].waitForExistence(timeout: 5))
        assertNoUnlabelledInteractiveElements(screen: "LogDay")
        app.buttons["logDay.cancelButton"].tap()
    }

    func testLogFormSaveAndCancelButtonsHaveLabels() {
        app.buttons["home.newLogButton"].tap()
        XCTAssertTrue(app.buttons["logDay.saveButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["logDay.saveButton"].label.isEmpty)
        XCTAssertFalse(app.buttons["logDay.cancelButton"].label.isEmpty)
        app.buttons["logDay.cancelButton"].tap()
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
        XCTAssertTrue(app.otherElements["home.cyclePhaseCard"].waitForExistence(timeout: 5))
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
        app.buttons["home.settingsButton"].tap()
        XCTAssertTrue(app.switches["settings.requireAuthToggle"].waitForExistence(timeout: 5))
        assertNoUnlabelledInteractiveElements(screen: "Settings")
        app.buttons.matching(NSPredicate(format: "label == 'Done'")).firstMatch.tap()
    }

    // MARK: - Reduce Motion (runs under reduce-motion configuration in test plan)

    func testAnimationsRespectReduceMotionPreference() {
        // When UIAccessibilityIsReduceMotionEnabled=1 (set by test plan),
        // the app must not crash and primary screens must be fully navigable.
        // This test confirms the app launches and core UI is accessible under
        // reduce motion — animation correctness is validated by visual inspection
        // during the manual VoiceOver gate.
        XCTAssertTrue(app.otherElements["home.cyclePhaseCard"].waitForExistence(timeout: 5))
        app.buttons["home.newLogButton"].tap()
        XCTAssertTrue(app.buttons["logDay.saveButton"].waitForExistence(timeout: 5))
        app.buttons["logDay.cancelButton"].tap()
    }
}
