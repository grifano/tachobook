import XCTest

final class ShiftPersistenceUITests: XCTestCase {
    @MainActor
    func testEmptyActiveClosedAndResumedStateAcrossFullProcessRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-persistenceUITest", "-resetPersistenceTest"]
        app.launch()
        let close = app.buttons["closeDayButton"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertFalse(close.isEnabled)
        XCTAssertFalse(app.buttons["resumeShiftButton"].exists)

        app.buttons["editDayStartButton"].tap()
        app.buttons["confirmDayStartButton"].tap()
        app.buttons["editDrivingButton"].tap()
        app.buttons["confirmDrivingButton"].tap()
        XCTAssertTrue(app.staticTexts["9H30M"].waitForExistence(timeout: 5))
        let startLabel = loggedTimeLabels(app)
        XCTAssertFalse(startLabel.isEmpty)
        screenshot("Active before termination")

        app.terminate()
        app.launchArguments = ["-persistenceUITest"] // No seed/reset on any reload.
        app.launch()
        XCTAssertTrue(app.staticTexts["9H30M"].waitForExistence(timeout: 5))
        XCTAssertEqual(loggedTimeLabels(app), startLabel)
        XCTAssertTrue(close.isEnabled)
        screenshot("Active after relaunch")

        if !close.isHittable { app.swipeUp() }
        close.tap()
        app.buttons["Close shift"].tap()
        XCTAssertTrue(app.buttons["resumeShiftButton"].waitForExistence(timeout: 5))
        let frozen = app.staticTexts["shiftHoursMinutes"].label
        screenshot("Closed before termination")

        app.terminate()
        app.launch()
        let resume = app.buttons["resumeShiftButton"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["shiftHoursMinutes"].label, frozen)
        XCTAssertTrue(app.staticTexts["9H30M"].exists)
        screenshot("Closed after relaunch")
        if !resume.isHittable { app.swipeUp() }
        resume.tap()
        XCTAssertTrue(app.staticTexts["shiftSeconds"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["shiftSeconds"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["9H30M"].exists)
        XCTAssertEqual(loggedTimeLabels(app), startLabel)
        XCTAssertFalse(app.buttons["resumeShiftButton"].exists)
        screenshot("Resumed after relaunch")
    }

    @MainActor
    private func loggedTimeLabels(_ app: XCUIApplication) -> [String] {
        app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]{1,2}:[0-9]{2}(\\s?[AP]M)?$"))
            .allElementsBoundByIndex.filter { $0.identifier != "shiftHoursMinutes" }.map(\.label)
    }

    @MainActor
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
