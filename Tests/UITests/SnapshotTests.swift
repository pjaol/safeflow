import XCTest

@MainActor
final class SnapshotTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Clear data, load rich test data, skip onboarding, bypass lock
        // Read language from the same cache file SnapshotHelper uses, and pass it to
        // the app so SafeFlowApp can set the SwiftUI locale before first render.
        let simulatorHostHome = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] ?? NSHomeDirectory()
        let cacheDir = simulatorHostHome + "/Library/Caches/tools.fastlane"
        let snapshotLang = (try? String(contentsOfFile: cacheDir + "/language.txt", encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "en-US"
        app.launchArguments = ["UI-Testing", "RESET_DATA", "SKIP_ONBOARDING", "LOAD_SYMPTOM_RICH"]
        app.launchEnvironment["FASTLANE_SNAPSHOT"] = "1"
        app.launchEnvironment["SNAPSHOT_LANGUAGE"] = snapshotLang
        setupSnapshot(app)
        addUIInterruptionMonitor(withDescription: "System alert") { alert in
            if alert.buttons["Don't Allow"].exists { alert.buttons["Don't Allow"].tap(); return true }
            if alert.buttons["Allow"].exists { alert.buttons["Allow"].tap(); return true }
            return false
        }
        app.launch()
        app.tap()
        // Security service init + data load is slow — wait generously
        XCTAssertTrue(app.buttons["home.cycleRingSummaryCard"].waitForExistence(timeout: 30))
    }

    // MARK: - Diagnostic

    func testDiagnostic_WhatIsOnScreen() throws {
        sleep(5)
        print("=== APP HIERARCHY ===")
        print(app.debugDescription)
        print("=== END HIERARCHY ===")
    }

    // MARK: - Snapshots

    func testSnapshot01_Home() throws {
        // setUp already confirmed home.cycleRingSummaryCard — just let data settle
        sleep(2)
        snapshot("01_Home")
    }

    func testSnapshot02_PulseView() throws {
        app.swipeDown() // scroll to top so PulseView is visible
        sleep(1)
        snapshot("02_Pulse")
    }

    func testSnapshot03_CycleRingDetail() throws {
        let ring = app.buttons["home.cycleRingSummaryCard"]
        XCTAssertTrue(ring.waitForExistence(timeout: 5))
        ring.tap()
        XCTAssertTrue(app.buttons["cycleDetail.doneButton"].waitForExistence(timeout: 5))
        sleep(1)
        snapshot("03_CycleDetail")
        app.swipeDown()
    }

    func testSnapshot04_ForecastView() throws {
        // Tap the forecast toolbar button — it scrolls the ScrollView to ForecastView
        let forecastButton = app.buttons["home.forecastButton"]
        XCTAssertTrue(forecastButton.waitForExistence(timeout: 5))
        forecastButton.tap()
        sleep(2)
        // forecast.header may already be in the a11y tree but off-screen;
        // keep swiping until it's hittable
        var attempts = 0
        while !app.staticTexts["forecast.header"].isHittable && attempts < 10 {
            app.swipeUp()
            sleep(1)
            attempts += 1
        }
        sleep(1)
        snapshot("04_Forecast")
    }

    func testSnapshot05_LogDay() throws {
        let editButtons = app.buttons.matching(identifier: "home.editLogsButton")
        XCTAssertTrue(editButtons.firstMatch.waitForExistence(timeout: 5))
        var tapped = false
        for i in 0..<editButtons.count {
            let btn = editButtons.element(boundBy: i)
            if btn.isHittable { btn.tap(); tapped = true; break }
        }
        if !tapped { editButtons.firstMatch.tap() }
        XCTAssertTrue(app.buttons["editLogs.doneButton"].waitForExistence(timeout: 5))
        sleep(1)
        snapshot("05_LogDay")
        app.buttons["editLogs.doneButton"].tap()
        sleep(1)
    }

    func testSnapshot06_History() throws {
        // Scroll past ForecastView to the CycleCalendarView (History)
        // Start from forecast position and keep scrolling until history.header is visible
        var attempts = 0
        while !app.staticTexts["history.header"].exists && attempts < 15 {
            app.swipeUp()
            sleep(1)
            attempts += 1
        }
        XCTAssertTrue(app.staticTexts["history.header"].waitForExistence(timeout: 5))
        sleep(1)
        snapshot("06_History")
    }
}

// MARK: - Helpers

private extension XCUIElement {
    func scrollToElement(in app: XCUIApplication) {
        var attempts = 0
        while !isHittable && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
    }
}
