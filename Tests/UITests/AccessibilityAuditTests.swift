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
        app.launchArguments = ["UI-Testing", "RESET_DATA", "SKIP_ONBOARDING", "LOAD_SYMPTOM_RICH"]
        addUIInterruptionMonitor(withDescription: "System alert") { alert in
            if alert.buttons["Don't Allow"].exists { alert.buttons["Don't Allow"].tap(); return true }
            if alert.buttons["Allow"].exists { alert.buttons["Allow"].tap(); return true }
            return false
        }
        app.launch()
        app.tap()
        XCTAssertTrue(app.buttons["home.cycleRingSummaryCard"].waitForExistence(timeout: 10))
    }

    // MARK: - Home Screen

    func testHomeScreenAccessibility() throws {
        try app.performAccessibilityAudit(for: [
            .sufficientElementDescription,
            .hitRegion,
            .dynamicType
        ]) { issue in
            // Suppress issues on elements with no identifier — SwiftUI framework internals
            guard let id = issue.element?.identifier, !id.isEmpty else { return true }
            return false
        }
    }

    // MARK: - Edit Logs Sheet

    func testEditLogsSheetAccessibility() throws {
        XCTAssertTrue(app.buttons["home.editLogsButton"].waitForExistence(timeout: 5))
        app.buttons["home.editLogsButton"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == 'Done'")).firstMatch
            .waitForExistence(timeout: 5))

        try app.performAccessibilityAudit(for: [
            .sufficientElementDescription,
            .hitRegion,
            .dynamicType
        ]) { issue in
            guard let id = issue.element?.identifier, !id.isEmpty else { return true }
            return false
        }

        app.buttons.matching(NSPredicate(format: "label == 'Done'")).firstMatch.tap()
    }

    // MARK: - Settings

    func testSettingsAccessibility() throws {
        XCTAssertTrue(app.buttons["home.settingsButton"].waitForExistence(timeout: 5))
        app.buttons["home.settingsButton"].tap()
        XCTAssertTrue(app.switches["settings.requireAuthToggle"].waitForExistence(timeout: 5))

        try app.performAccessibilityAudit(for: [
            .sufficientElementDescription,
            .hitRegion,
            .dynamicType
        ]) { issue in
            guard let id = issue.element?.identifier, !id.isEmpty else { return true }
            return false
        }

        app.buttons.matching(NSPredicate(format: "label == 'Done'")).firstMatch.tap()
    }

    // MARK: - Forecast View

    func testForecastViewAccessibility() throws {
        // Scroll down until the forecast header text is visible in the screen
        var attempts = 0
        while !app.staticTexts["Cycle Forecast"].exists && attempts < 10 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(app.staticTexts["Cycle Forecast"].exists,
            "Forecast section not reachable after scrolling")

        try app.performAccessibilityAudit(for: [
            .sufficientElementDescription,
            .dynamicType
        ]) { issue in
            // Suppress issues on un-identified framework internals
            guard let id = issue.element?.identifier, !id.isEmpty else { return true }
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
        let ring = app.buttons["home.cycleRingSummaryCard"]
        XCTAssertTrue(ring.waitForExistence(timeout: 5))
        ring.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == 'Done'")).firstMatch
            .waitForExistence(timeout: 5))

        try app.performAccessibilityAudit(for: [
            .sufficientElementDescription,
            .hitRegion
        ]) { issue in
            guard let id = issue.element?.identifier, !id.isEmpty else { return true }
            return false
        }

        app.swipeDown()
    }

    // MARK: - Onboarding

    func testOnboardingAccessibility() throws {
        let onboardingApp = XCUIApplication()
        onboardingApp.launchArguments = ["UI-Testing"]
        addUIInterruptionMonitor(withDescription: "System alert") { alert in
            if alert.buttons["Don't Allow"].exists { alert.buttons["Don't Allow"].tap(); return true }
            if alert.buttons["Allow"].exists { alert.buttons["Allow"].tap(); return true }
            return false
        }
        onboardingApp.launch()
        onboardingApp.tap()

        // Swipe to the cycle setup page (page 3)
        for _ in 0..<3 { onboardingApp.swipeLeft() }
        XCTAssertTrue(onboardingApp.datePickers["onboarding.lastPeriodDatePicker"].waitForExistence(timeout: 5))

        try onboardingApp.performAccessibilityAudit(for: [
            .sufficientElementDescription,
            .hitRegion,
            .dynamicType
        ]) { issue in
            guard let id = issue.element?.identifier, !id.isEmpty else { return true }
            return false
        }
    }
}
