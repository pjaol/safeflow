import XCTest

@MainActor
final class SnapshotTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Clear data, load rich test data, skip onboarding, bypass lock
        app.launchArguments = ["RESET_DATA", "SKIP_ONBOARDING", "LOAD_SYMPTOM_RICH"]
        app.launchEnvironment["FASTLANE_SNAPSHOT"] = "1"
        app.launch()
        // Security service init + data load is slow — wait generously
        _ = app.otherElements["home.cycleRingSummaryCard"].waitForExistence(timeout: 40)
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
        // Wait for home to settle with data loaded
        // Security service initialises async so we need a generous timeout
        let ring = app.otherElements["home.cycleRingSummaryCard"]
        XCTAssertTrue(ring.waitForExistence(timeout: 15))
        sleep(2) // let data and animations settle
        snapshot("01_Home")
    }

    func testSnapshot02_PulseView() throws {
        // PulseView is the top of the home scroll — scroll back up to it
        let ring = app.otherElements["home.cycleRingSummaryCard"]
        XCTAssertTrue(ring.waitForExistence(timeout: 5))
        app.swipeDown() // scroll to top
        sleep(1)
        snapshot("02_Pulse")
    }

    func testSnapshot03_CycleRingDetail() throws {
        // Tap the ring card to open the detail sheet
        let ring = app.otherElements["home.cycleRingSummaryCard"]
        XCTAssertTrue(ring.waitForExistence(timeout: 5))
        ring.tap()
        sleep(1)
        snapshot("03_CycleDetail")
        // Dismiss
        app.swipeDown()
    }

    func testSnapshot04_ForecastView() throws {
        let forecast = app.otherElements["home.forecastView"]
        XCTAssertTrue(forecast.waitForExistence(timeout: 5))
        forecast.scrollToElement(in: app)
        sleep(1)
        snapshot("04_Forecast")
    }

    func testSnapshot05_LogDay() throws {
        // Open the log day view
        let editButton = app.buttons["home.editLogsButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()
        sleep(1)
        snapshot("05_LogDay")
        // Dismiss
        let cancel = app.buttons["logDay.cancelButton"]
        if cancel.exists { cancel.tap() }
    }

    func testSnapshot06_History() throws {
        // Scroll down past forecast to the calendar heat map
        for _ in 0..<3 { app.swipeUp() }
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
