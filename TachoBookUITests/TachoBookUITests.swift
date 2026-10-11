//
//  TachoBookUITests.swift
//  TachoBookUITests
//
//  Created by sorlenko on 07/10/2026.
//

import XCTest

final class TachoBookUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDashboardRowsRespectHorizontalMargins() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-sampleData")
        app.launch()

        let screenWidth = app.windows.firstMatch.frame.width
        XCTAssertGreaterThan(screenWidth, 0)

        let title = app.staticTexts["Day end"]
        let editButton = app.buttons["editDayEndButton"]
        XCTAssertTrue(title.exists)
        XCTAssertTrue(editButton.exists)
        XCTAssertGreaterThanOrEqual(title.frame.minX, 32)
        XCTAssertLessThanOrEqual(editButton.frame.maxX, screenWidth - 32)
    }

    @MainActor
    func testDashboardLargeTextScalesAndKeepsMargins() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-sampleData", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"]
        app.launch()

        let screenWidth = app.windows.firstMatch.frame.width
        let cardHeading = app.staticTexts["Today’s Limits"]
        let editButton = app.buttons["editDayEndButton"]
        XCTAssertTrue(cardHeading.exists)
        XCTAssertTrue(editButton.exists)
        XCTAssertGreaterThan(cardHeading.frame.height, 18)
        XCTAssertGreaterThanOrEqual(cardHeading.frame.minX, 32)
        XCTAssertLessThanOrEqual(editButton.frame.maxX, screenWidth - 32)
    }

    @MainActor
    func testDashboardAccessibilityTextKeepsActionsVisible() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-sampleData", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM"]
        app.launch()

        let window = app.windows.firstMatch.frame
        let cardHeading = app.staticTexts["Today’s Limits"]
        let editButton = app.buttons["editDayEndButton"]
        XCTAssertTrue(cardHeading.exists)
        XCTAssertTrue(editButton.exists)
        XCTAssertGreaterThan(cardHeading.frame.height, 18)
        XCTAssertGreaterThanOrEqual(cardHeading.frame.minX, 32)
        if !editButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(editButton.isHittable)
        XCTAssertLessThanOrEqual(editButton.frame.maxX, window.width - 32)
        XCTAssertLessThanOrEqual(editButton.frame.maxY, window.height)
    }

    @MainActor
    func testLogFullDayFlow() throws {
        let scratchPath = "/Users/sorlenko/.gemini/antigravity/brain/499fae3c-eb9b-47b3-af4b-0c00a7678a82/scratch"
        func saveShot(name: String) {
            let data = XCUIScreen.main.screenshot().pngRepresentation
            let url = URL(fileURLWithPath: "\(scratchPath)/\(name).png")
            try? data.write(to: url)
        }

        let app = XCUIApplication()
        app.launchArguments.append("-sampleData")
        app.launch()

        // 1. Initial State: Close day is disabled
        let closeDayButton = app.buttons["closeDayButton"]
        XCTAssertTrue(closeDayButton.exists)
        XCTAssertFalse(closeDayButton.isEnabled)
        saveShot(name: "step_1_initial")

        // 2. Log Day Start
        let editStartButton = app.buttons["editDayStartButton"]
        XCTAssertTrue(editStartButton.exists)
        editStartButton.tap()

        // In Day Start Sheet
        let startConfirmButton = app.buttons["confirmDayStartButton"]
        XCTAssertTrue(startConfirmButton.waitForExistence(timeout: 2.0))
        saveShot(name: "step_2_start_sheet")

        // Toggle time picker
        let timePill = app.buttons["timePillButton"]
        XCTAssertTrue(timePill.waitForExistence(timeout: 2.0))
        timePill.tap()

        let timePicker = app.datePickers["timePicker"]
        XCTAssertTrue(timePicker.waitForExistence(timeout: 2.0))
        let windowWidth = app.windows.firstMatch.frame.width
        XCTAssertGreaterThanOrEqual(timePicker.frame.minX, 0)
        XCTAssertLessThanOrEqual(timePicker.frame.maxX, windowWidth)
        saveShot(name: "step_2_start_sheet_expanded_picker")

        startConfirmButton.tap()

        // Verify Day Start logged
        var startComps = DateComponents()
        startComps.year = 2026; startComps.month = 4; startComps.day = 20; startComps.hour = 6; startComps.minute = 30
        let startDate = Calendar.current.date(from: startComps)!
        let expectedStart = startDate.formatted(date: .omitted, time: .shortened)
        XCTAssertTrue(app.staticTexts[expectedStart].waitForExistence(timeout: 2.0))
        XCTAssertFalse(closeDayButton.isEnabled)
        saveShot(name: "step_3_started_state")

        // 3. Log Daily Driving
        let editDrivingButton = app.buttons["editDrivingButton"]
        XCTAssertTrue(editDrivingButton.exists)
        editDrivingButton.tap()

        // In Daily Driving Sheet
        let drivingConfirmButton = app.buttons["confirmDrivingButton"]
        XCTAssertTrue(drivingConfirmButton.waitForExistence(timeout: 2.0))
        saveShot(name: "step_4_driving_sheet")
        drivingConfirmButton.tap()

        // Verify Driving Logged
        XCTAssertTrue(app.staticTexts["9H30M"].waitForExistence(timeout: 2.0))
        XCTAssertFalse(closeDayButton.isEnabled)
        saveShot(name: "step_5_driving_logged")

        // 4. Log Day End
        let editDayEndButton = app.buttons["editDayEndButton"]
        XCTAssertTrue(editDayEndButton.exists)
        editDayEndButton.tap()

        // In Day End Sheet
        let endConfirmButton = app.buttons["confirmDayEndButton"]
        XCTAssertTrue(endConfirmButton.waitForExistence(timeout: 2.0))
        saveShot(name: "step_6_day_end_sheet")
        endConfirmButton.tap()

        // Verify Day End logged
        var endComps = DateComponents()
        endComps.year = 2026; endComps.month = 4; endComps.day = 20; endComps.hour = 20; endComps.minute = 30
        let endDate = Calendar.current.date(from: endComps)!
        let expectedEnd = endDate.formatted(date: .omitted, time: .shortened)
        XCTAssertTrue(app.staticTexts[expectedEnd].waitForExistence(timeout: 2.0))
        XCTAssertGreaterThanOrEqual(app.staticTexts["Day end"].frame.minX, 32)
        XCTAssertLessThanOrEqual(editDayEndButton.frame.maxX, app.windows.firstMatch.frame.width - 32)

        // 5. Verify Close Day is now enabled & Working Time is 14:00
        XCTAssertTrue(closeDayButton.isEnabled)
        XCTAssertTrue(app.staticTexts["14:00"].exists)
        saveShot(name: "step_7_ready_to_close")

        // 6. Tap Close Day to view Day Summary
        closeDayButton.tap()

        // Verify Day Summary
        let daySummaryTitle = app.staticTexts["Day summary"]
        XCTAssertTrue(daySummaryTitle.waitForExistence(timeout: 2.0))
        XCTAssertTrue(app.staticTexts["No violation"].exists)
        saveShot(name: "step_8_day_summary")

        // Tap Close in Day Summary
        let closeSummaryButton = app.buttons["closeSummaryButton"]
        XCTAssertTrue(closeSummaryButton.exists)
        closeSummaryButton.tap()

        // 7. Verify Completed State: button is now "Day summary"
        let daySummaryReopenButton = app.buttons["daySummaryButton"]
        XCTAssertTrue(daySummaryReopenButton.waitForExistence(timeout: 2.0))
        XCTAssertTrue(daySummaryReopenButton.isEnabled)
        saveShot(name: "step_10_completed_state")

        // 8. Reopen Day Summary
        daySummaryReopenButton.tap()
        XCTAssertTrue(app.staticTexts["No violation"].waitForExistence(timeout: 2.0))
    }
}
