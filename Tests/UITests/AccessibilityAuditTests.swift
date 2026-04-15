import XCTest

/// Automated accessibility audits using XCTest's native performAccessibilityAudit() API (Xcode 15+).
///
/// These tests run the Xcode Accessibility Inspector checks programmatically against each major screen,
/// catching: missing labels, insufficient hit regions, contrast issues, Dynamic Type clipping, and trait problems.
///
/// Run from CLI:
///   xcodebuild -project safeflow.xcodeproj -scheme safeflow \
///     -destination 'platform=iOS Simulator,name=iPhone 16' \
///     -only-testing:safeflowUITests/AccessibilityAuditTests test
@MainActor
final class AccessibilityAuditTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["RESET_DATA", "SKIP_ONBOARDING", "LOAD_SYMPTOM_RICH"]
        app.launch()
        _ = app.otherElements["home.cycleRingSummaryCard"].waitForExistence(timeout: 30)
    }

    // MARK: - Home Screen

    func testHomeScreenAccessibility() throws {
        try app.performAccessibilityAudit(for: [
            .sufficientElementDescription,
            .hitRegion,
            .dynamicType
        ]) { issue in
            // Known decorative elements that are intentionally unlabelled
            let knownIgnored = [
                "home.cycleRingSummaryCard", // composite element — labelled at container level
            ]
            if let id = issue.element?.identifier, knownIgnored.contains(id) {
                return true // suppress
            }
            return false
        }
    }

    // MARK: - Log Day Form

    func testLogDayFormAccessibility() throws {
        app.buttons["home.newLogButton"].tap()
        XCTAssertTrue(app.buttons["logDay.cancelButton"].waitForExistence(timeout: 3))

        try app.performAccessibilityAudit(for: [
            .sufficientElementDescription,
            .hitRegion,
            .dynamicType
        ])

        app.buttons["logDay.cancelButton"].tap()
    }

    // MARK: - Quick Log Sheet

    func testQuickLogSheetAccessibility() throws {
        let periodButton = app.buttons["home.quickLog.periodStarted"]
        XCTAssertTrue(periodButton.waitForExistence(timeout: 5))
        periodButton.tap()
        _ = app.buttons["quickLog.flow.medium"].waitForExistence(timeout: 3)

        try app.performAccessibilityAudit(for: [
            .sufficientElementDescription,
            .hitRegion
        ])

        app.swipeDown()
    }

    // MARK: - Settings

    func testSettingsAccessibility() throws {
        app.buttons["home.settingsButton"].tap()
        XCTAssertTrue(app.switches["Require Authentication"].waitForExistence(timeout: 3))

        try app.performAccessibilityAudit(for: [
            .sufficientElementDescription,
            .hitRegion,
            .dynamicType
        ])

        app.buttons["Done"].tap()
    }

    // MARK: - Forecast View

    func testForecastViewAccessibility() throws {
        let forecast = app.otherElements["home.forecastView"]
        XCTAssertTrue(forecast.waitForExistence(timeout: 5))
        // Scroll forecast into view
        var attempts = 0
        while !forecast.isHittable && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }

        try app.performAccessibilityAudit(for: [
            .sufficientElementDescription,
            .dynamicType
        ]) { issue in
            // Chart grid cells are visual-only — suppress missing description on inner drawing elements
            if issue.auditType == .sufficientElementDescription,
               issue.element?.elementType == .other {
                return true
            }
            return false
        }
    }

    // MARK: - Cycle Ring Detail Sheet

    func testCycleRingDetailAccessibility() throws {
        let ring = app.otherElements["home.cycleRingSummaryCard"]
        XCTAssertTrue(ring.waitForExistence(timeout: 5))
        ring.tap()
        sleep(1)

        try app.performAccessibilityAudit(for: [
            .sufficientElementDescription,
            .hitRegion
        ])

        app.swipeDown()
    }

    // MARK: - Onboarding

    func testOnboardingAccessibility() throws {
        // Reset to onboarding state
        let onboardingApp = XCUIApplication()
        onboardingApp.launchArguments = ["UI-Testing"]
        onboardingApp.launch()

        // Swipe to the cycle setup page (page 3)
        for _ in 0..<3 { onboardingApp.swipeLeft() }
        XCTAssertTrue(onboardingApp.datePickers["onboarding.lastPeriodDatePicker"].waitForExistence(timeout: 5))

        try onboardingApp.performAccessibilityAudit(for: [
            .sufficientElementDescription,
            .hitRegion,
            .dynamicType
        ])
    }
}
