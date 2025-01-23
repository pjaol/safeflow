//
//  safeflowUITests.swift
//  safeflowUITests
//
//  Created by patrick o'leary on 1/21/25.
//

import XCTest

final class SafeFlowUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }
    
    func testAddNewLog() throws {
        // Tap the add button
        app.buttons["plus.circle.fill"].tap()
        
        // Select flow intensity
        app.buttons["Medium"].tap()
        
        // Toggle symptoms
        app.switches["Cramps"].tap()
        app.switches["Headache"].tap()
        
        // Select mood
        app.buttons["Happy"].tap()
        
        // Add notes
        let notesTextView = app.textViews.firstMatch
        notesTextView.tap()
        notesTextView.typeText("Test note for the day")
        
        // Save the log
        app.buttons["Save"].tap()
        
        // Verify the log appears in recent logs
        XCTAssertTrue(app.staticTexts["Flow: Medium"].exists)
        XCTAssertTrue(app.staticTexts["Symptoms: Cramps, Headache"].exists)
        XCTAssertTrue(app.staticTexts["Mood: Happy"].exists)
    }
    
    func testCancelAddLog() throws {
        // Tap the add button
        app.buttons["plus.circle.fill"].tap()
        
        // Select some data
        app.buttons["Light"].tap()
        app.switches["Fatigue"].tap()
        
        // Cancel the log
        app.buttons["Cancel"].tap()
        
        // Verify we're back on the main screen
        XCTAssertTrue(app.navigationBars["SafeFlow"].exists)
        
        // Verify no log was added
        XCTAssertFalse(app.staticTexts["Flow: Light"].exists)
    }
    
    func testDeleteLog() throws {
        // First add a log
        app.buttons["plus.circle.fill"].tap()
        app.buttons["Heavy"].tap()
        app.buttons["Save"].tap()
        
        // Verify the log exists
        XCTAssertTrue(app.staticTexts["Flow: Heavy"].exists)
        
        // Delete the log
        app.buttons["trash"].firstMatch.tap()
        
        // Verify the log is gone
        XCTAssertFalse(app.staticTexts["Flow: Heavy"].exists)
    }
    
    func testUpdateTodaysLog() throws {
        // Add initial log
        app.buttons["plus.circle.fill"].tap()
        app.buttons["Light"].tap()
        app.buttons["Save"].tap()
        
        // Tap today's log to update
        app.staticTexts["Today's Log"].tap()
        
        // Change flow to heavy
        app.buttons["Heavy"].tap()
        
        // Save the update
        app.buttons["Save"].tap()
        
        // Verify the update
        XCTAssertTrue(app.staticTexts["Flow: Heavy"].exists)
        XCTAssertFalse(app.staticTexts["Flow: Light"].exists)
    }
    
    func testPredictionCardUpdates() throws {
        // Add three logs 30 days apart to trigger prediction
        app.buttons["plus.circle.fill"].tap()
        app.buttons["Medium"].tap()
        app.buttons["Save"].tap()
        
        // Initially should show "Not enough data"
        XCTAssertTrue(app.staticTexts["Not enough data"].exists)
        
        // Add more logs (in real app, we'd need to mock dates)
        // This is a placeholder to show the test structure
        // In real implementation, we'd need to inject mock dates
        XCTAssertTrue(app.staticTexts["Next Period Prediction"].exists)
    }
    
    func testAuthenticationFlow() throws {
        // Test that the app starts with the lock screen
        XCTAssertTrue(app.staticTexts["Unlock to Access"].exists)
        
        // Test biometric authentication button exists
        XCTAssertTrue(app.buttons["Authenticate"].exists)
    }
    
    func testSettingsNavigation() throws {
        // Navigate to settings (assuming app is unlocked)
        app.tabBars.buttons["Settings"].tap()
        
        // Verify authentication toggle exists
        XCTAssertTrue(app.switches["Require Authentication"].exists)
    }
}
