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
        XCTAssertTrue(app.otherElements["home.settingsButton"].waitForExistence(timeout: 5))

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
        XCTAssertTrue(app.otherElements["home.settingsButton"].waitForExistence(timeout: 5))

        // Toolbar buttons must have translated labels
        XCTAssertFalse(app.buttons["home.settingsButton"].label.isEmpty,
            "Settings button label empty in locale '\(currentLocale())'")
        XCTAssertFalse(app.buttons["home.editLogsButton"].label.isEmpty,
            "Edit logs button label empty in locale '\(currentLocale())'")
        XCTAssertFalse(app.buttons["home.getSupportButton"].label.isEmpty,
            "Get support button label empty in locale '\(currentLocale())'")
    }

    // MARK: - Layout under long translations (German stress test)

    /// German strings average ~30% longer than English. This test verifies that
    /// primary action buttons remain hittable (not truncated off-screen) when
    /// running under de-DE. It also passes for other locales as a baseline check.
    func testPrimaryButtonsHittableUnderCurrentLocale() {
        XCTAssertTrue(app.otherElements["home.settingsButton"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.buttons["home.settingsButton"].isHittable,
            "Settings button not hittable in locale '\(currentLocale())'")
        XCTAssertTrue(app.buttons["home.editLogsButton"].isHittable,
            "Edit logs button not hittable in locale '\(currentLocale())'")
        XCTAssertTrue(app.buttons["home.getSupportButton"].isHittable,
            "Get support button not hittable in locale '\(currentLocale())'")
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
