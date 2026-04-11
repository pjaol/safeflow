import XCTest

/// Localisation regression tests for v1.1.
///
/// These tests run via the SafeFlowLocalisation test plan which sets
/// AppleLanguages and AppleLocale for each configuration:
///   en-US, es-MX, fr-FR, de-DE
///
/// Tests verify:
/// - No raw string keys appear in the UI (missing translation fallback)
/// - Critical labels are non-empty in every locale
/// - Dates are not displayed in hardcoded ISO format
/// - Key buttons remain hittable under longer translations (German stress test)
///
/// Run via: make test-i18n
final class LocalisationUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing", "SKIP_ONBOARDING"]
        // AppleLanguages and AppleLocale are injected by the test plan.
        app.launch()
    }

    // MARK: - Raw string key detection

    /// If a string is missing from the catalog for the current locale, SwiftUI
    /// falls back to the key itself (e.g. "home.phaseCard.dayCounter").
    /// This test fails if any visible text matches the dotted-lowercase key pattern.
    func testNoRawStringKeysVisibleInCurrentLocale() {
        XCTAssertTrue(app.otherElements["home.cyclePhaseCard"].waitForExistence(timeout: 5))

        // Heuristic: raw keys are all-lowercase with dots and no spaces
        // e.g. "settings.security.requireAuth" — legitimate dot text like "v1.1" is excluded
        // by requiring at least 2 dot-separated segments each with 3+ chars
        let rawKeyPattern = #"^[a-z][a-z0-9]+(\.[a-z][a-z0-9]+){2,}$"#
        let regex = try! NSRegularExpression(pattern: rawKeyPattern)

        let allLabels: [String] = (
            app.staticTexts.allElementsBoundByIndex +
            app.buttons.allElementsBoundByIndex
        ).map { $0.label }

        for label in allLabels where !label.isEmpty {
            let range = NSRange(label.startIndex..., in: label)
            let match = regex.firstMatch(in: label, range: range)
            XCTAssertNil(match,
                "Raw string key visible in UI for locale '\(currentLocale())': '\(label)'")
        }
    }

    // MARK: - Critical labels non-empty

    func testCriticalHomeLabelsNonEmptyInCurrentLocale() {
        XCTAssertTrue(app.otherElements["home.cyclePhaseCard"].waitForExistence(timeout: 5))

        // Toolbar buttons must have translated labels
        XCTAssertFalse(app.buttons["home.settingsButton"].label.isEmpty,
            "Settings button label empty in locale '\(currentLocale())'")
        XCTAssertFalse(app.buttons["home.editLogsButton"].label.isEmpty,
            "Edit logs button label empty in locale '\(currentLocale())'")
        XCTAssertFalse(app.buttons["home.getSupportButton"].label.isEmpty,
            "Get support button label empty in locale '\(currentLocale())'")
    }

    func testCriticalLogFormLabelsNonEmptyInCurrentLocale() {
        app.buttons["home.newLogButton"].tap()
        XCTAssertTrue(app.buttons["logDay.saveButton"].waitForExistence(timeout: 5))

        XCTAssertFalse(app.buttons["logDay.saveButton"].label.isEmpty,
            "Save button label empty in locale '\(currentLocale())'")
        XCTAssertFalse(app.buttons["logDay.cancelButton"].label.isEmpty,
            "Cancel button label empty in locale '\(currentLocale())'")

        app.buttons["logDay.cancelButton"].tap()
    }

    // MARK: - Date formatting

    /// Hardcoded DateFormatter with `dateFormat = "yyyy-MM-dd"` produces ISO dates
    /// regardless of locale. After replacing with `.formatted()`, dates must
    /// respect the user's locale and never appear as ISO 8601 in the UI.
    func testDatesAreNotISO8601InCurrentLocale() {
        // Log a day so a date appears in the UI
        let noPeriodButton = app.buttons["home.quickLog.noPeriod"]
        XCTAssertTrue(noPeriodButton.waitForExistence(timeout: 5))
        noPeriodButton.tap()
        XCTAssertTrue(app.otherElements["home.dailyLogCard"].waitForExistence(timeout: 3))

        // ISO 8601 pattern: four digits, dash, two digits, dash, two digits
        let isoPattern = #"\d{4}-\d{2}-\d{2}"#
        let regex = try! NSRegularExpression(pattern: isoPattern)

        let allLabels = app.staticTexts.allElementsBoundByIndex.map { $0.label }
        for label in allLabels where !label.isEmpty {
            let range = NSRange(label.startIndex..., in: label)
            XCTAssertNil(
                regex.firstMatch(in: label, range: range),
                "ISO 8601 date format found in locale '\(currentLocale())': '\(label)' — replace DateFormatter with .formatted()"
            )
        }
    }

    // MARK: - Layout under long translations (German stress test)

    /// German strings average ~30% longer than English. This test verifies that
    /// primary action buttons remain hittable (not truncated off-screen) when
    /// running under de-DE. It also passes for other locales as a baseline check.
    func testPrimaryButtonsHittableUnderCurrentLocale() {
        XCTAssertTrue(app.otherElements["home.cyclePhaseCard"].waitForExistence(timeout: 5))

        // Settings button
        XCTAssertTrue(app.buttons["home.settingsButton"].isHittable,
            "Settings button not hittable in locale '\(currentLocale())'")

        // Log form buttons
        app.buttons["home.newLogButton"].tap()
        XCTAssertTrue(app.buttons["logDay.saveButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["logDay.saveButton"].isHittable,
            "Save button not hittable in locale '\(currentLocale())' — label may be truncating layout")
        XCTAssertTrue(app.buttons["logDay.cancelButton"].isHittable,
            "Cancel button not hittable in locale '\(currentLocale())'")
        app.buttons["logDay.cancelButton"].tap()
    }

    // MARK: - Onboarding in current locale

    func testOnboardingLabelsNonEmptyInCurrentLocale() {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()

        for _ in 0..<3 { app.swipeLeft() }

        let getStarted = app.buttons["onboarding.getStartedButton"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 5))
        XCTAssertFalse(getStarted.label.isEmpty,
            "Get Started button label empty in locale '\(currentLocale())'")
        XCTAssertTrue(getStarted.isHittable,
            "Get Started button not hittable in locale '\(currentLocale())'")
    }

    // MARK: - Helpers

    private func currentLocale() -> String {
        app.launchEnvironment["AppleLocale"] ?? "unknown"
    }
}
