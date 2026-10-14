import XCTest

final class LiveShiftTimerUITests: XCTestCase {
    @MainActor
    func testLiveTimerForegroundRestartCloseAndResume() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-timerUITest", "-resetTimerTest"]
        app.launch()
        let value = app.staticTexts["shiftHoursMinutes"]
        let seconds = app.staticTexts["shiftSeconds"]
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        XCTAssertTrue(value.label.hasPrefix("1:"))
        XCTAssertTrue(seconds.exists)
        let initialSeconds = seconds.label
        let changes = NSPredicate { _, _ in seconds.exists && seconds.label != initialSeconds }
        expectation(for: changes, evaluatedWith: nil)
        waitForExpectations(timeout: 4)
        attachScreenshot("Active timer")

        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(value.label.hasPrefix("1:"))
        app.terminate()
        app.launchArguments = ["-timerUITest"]
        app.launch()
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        XCTAssertTrue(value.label.hasPrefix("1:"))

        let close = app.buttons["closeDayButton"]
        if !close.isHittable { app.swipeUp() }
        close.tap()
        app.buttons["Close shift"].tap()
        XCTAssertTrue(app.buttons["resumeShiftButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(seconds.exists)
        let frozen = value.label
        attachScreenshot("Rest timer")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["resumeShiftButton"].waitForExistence(timeout: 5))
        XCTAssertEqual(value.label, frozen)
        let resume = app.buttons["resumeShiftButton"]
        if !resume.isHittable { app.swipeUp() }
        resume.tap()
        XCTAssertTrue(seconds.waitForExistence(timeout: 5))
        XCTAssertTrue(value.label.hasPrefix("1:"))
        XCTAssertTrue(app.staticTexts["2H00M"].exists)
        attachScreenshot("Resumed timer")
    }

    @MainActor
    func testTimerFitsNarrowScreenWithLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["-timerUITest", "-resetTimerTest", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"]
        app.launch()
        let value = app.staticTexts["shiftHoursMinutes"]
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(value.frame.minX, 16)
        XCTAssertLessThanOrEqual(value.frame.maxX, app.windows.firstMatch.frame.width - 16)
        XCTAssertTrue(app.staticTexts["shiftSeconds"].exists)
        attachScreenshot("Large text timer")
    }

    @MainActor
    func testNewShiftRequiresConfirmationAndStartsAtActualStart() {
        let app = XCUIApplication()
        app.launchArguments = ["-timerUITest", "-resetTimerTest", "-longRestUITest"]
        app.launch()
        let newShift = app.buttons["newShiftButton"]
        XCTAssertTrue(newShift.waitForExistence(timeout: 5))
        if !newShift.isHittable { app.swipeUp() }
        newShift.tap()
        XCTAssertFalse(app.staticTexts["shiftSeconds"].exists)
        app.buttons["Daily rest confirmed — start new shift"].tap()
        let value = app.staticTexts["shiftHoursMinutes"]
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        XCTAssertEqual(value.label, "0:00")
        XCTAssertFalse(app.staticTexts["2H00M"].exists)
        attachScreenshot("New shift after confirmed rest")
    }

    @MainActor
    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
