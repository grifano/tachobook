import XCTest

/// MVP-07 History and correction: swipe back, enter and edit an earlier day.
/// The seeded weekly rest ended 46 h ago, so yesterday (day −1) is always empty.
final class DayHistoryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.appearance = .light
    }

    @MainActor
    func testSwipeBackDepthLimitAndTodayButton() {
        let app = launch(reset: true)
        XCTAssertTrue(app.buttons["summaryDayClosed"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["todayButton"].exists, "no Today button on today")
        XCTAssertEqual(header(app), headerDate(daysBack: 0))

        app.swipeLeft()
        XCTAssertTrue(app.buttons["todayButton"].waitForExistence(timeout: 5))
        XCTAssertEqual(header(app), headerDate(daysBack: 1))

        // The limit is 3 days: further swipes do nothing.
        for _ in 0..<5 { app.swipeLeft() }
        XCTAssertEqual(header(app), headerDate(daysBack: 3))
        attach("Day −3 (limit)")

        // Swiping right moves toward today.
        app.swipeRight()
        XCTAssertEqual(header(app), headerDate(daysBack: 2))
        app.buttons["todayButton"].tap()
        XCTAssertEqual(header(app), headerDate(daysBack: 0))
        XCTAssertTrue(app.buttons["todayButton"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Weekly Rest"].exists, "today shows the live Home again")

        app.swipeLeft()
        app.swipeRight()
        XCTAssertEqual(header(app), headerDate(daysBack: 0))
        XCTAssertFalse(app.buttons["todayButton"].exists)
        app.swipeRight()
        XCTAssertEqual(header(app), headerDate(daysBack: 0), "today is the newest day")
    }

    @MainActor
    func testEnterThenEditAnEmptyDayAndRelaunch() {
        let app = launch(reset: true)
        XCTAssertTrue(app.buttons["summaryDayClosed"].waitForExistence(timeout: 5))
        app.swipeLeft()
        XCTAssertTrue(app.buttons["todayButton"].waitForExistence(timeout: 5))

        // Empty day: three placeholders, no zeros or sample values.
        XCTAssertEqual(app.staticTexts["Day summary"].exists, true)
        for id in ["summaryDayStarted", "summaryDriving", "summaryDayClosed"] {
            XCTAssertTrue(app.buttons[id].label.contains("?"), "\(id): \(app.buttons[id].label)")
        }
        XCTAssertTrue(app.descendants(matching: .any)["homeGauge"].label.contains("--:--"), app.descendants(matching: .any)["homeGauge"].label)
        attach("Empty day, Work tab")

        enterTime(app, from: "summaryDayStarted", screenshot: nil)
        XCTAssertFalse(app.buttons["summaryDayStarted"].label.contains("?"))
        enterTime(app, from: "summaryDayClosed", screenshot: nil)
        XCTAssertFalse(app.buttons["summaryDayClosed"].label.contains("?"))
        enterDriving(app, digits: ["9", "5", "2"], expect: "Driving time 9h52")
        XCTAssertTrue(app.buttons["summaryDriving"].label.contains("09h52m"))
        XCTAssertFalse(app.descendants(matching: .any)["homeGauge"].label.contains("--:--"))
        attach("Filled day, Work tab")

        // The Rest tab shows the rest taken after that shift (still running: Day closed was this time yesterday).
        app.segmentedControls["homeTabPicker"].buttons["Rest"].tap()
        XCTAssertTrue(app.staticTexts["Rest Taken"].waitForExistence(timeout: 5))
        let restGauge = app.descendants(matching: .any)["homeGauge"]
        XCTAssertNotNil(restGauge.label.range(of: #"\b\d{2}:\d{2}\b"#, options: .regularExpression), restGauge.label)
        XCTAssertFalse(restGauge.label.contains("--:--"), restGauge.label)
        for marker in ["After 9h", "After 11h", "After 24h", "After 45h"] {
            XCTAssertFalse(element(app, startingWith: marker).exists, "\(marker) must not appear on past days")
        }
        attach("Rest tab")
        app.segmentedControls["homeTabPicker"].buttons["Work"].tap()

        // Edit: the sheet opens prefilled; a new value replaces it.
        app.buttons["summaryDriving"].tap()
        XCTAssertTrue(app.staticTexts["drivingValue"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["drivingValue"].label, "Driving time 9h52")
        attach("Driving edit sheet")

        // Swipes do not fire while a sheet is open.
        let shown = header(app)
        app.swipeLeft()
        app.swipeRight()
        XCTAssertTrue(app.staticTexts["drivingValue"].exists)
        for digit in ["1", "2", "3"] { app.buttons[digit].tap() }
        app.buttons["confirmSheetButton"].tap()
        XCTAssertTrue(app.buttons["confirmSheetButton"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(header(app), shown)
        XCTAssertTrue(app.buttons["summaryDriving"].label.contains("01h23m"))

        // Relaunch keeps the entries; today (the weekly rest) is untouched.
        app.terminate()
        let relaunched = launch(reset: false)
        XCTAssertTrue(relaunched.staticTexts["Weekly Rest"].waitForExistence(timeout: 5))
        XCTAssertTrue(relaunched.buttons["startOfDayButton"].isEnabled)
        relaunched.swipeLeft()
        XCTAssertTrue(relaunched.buttons["todayButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(relaunched.buttons["summaryDriving"].label.contains("01h23m"))
        XCTAssertFalse(relaunched.buttons["summaryDayStarted"].label.contains("?"))
        XCTAssertFalse(relaunched.buttons["summaryDayClosed"].label.contains("?"))
    }

    @MainActor
    func testAccessibilityAuditOfPastDays() throws {
        continueAfterFailure = true
        // `-startDaysBack 1` opens yesterday directly (Debug builds); swiping is covered above.
        let app = launch(reset: true, daysBack: 1)
        XCTAssertTrue(app.buttons["todayButton"].waitForExistence(timeout: 5))
        try audit(app, "empty day")
        enterTime(app, from: "summaryDayStarted", screenshot: nil)
        enterTime(app, from: "summaryDayClosed", screenshot: nil)
        enterDriving(app, digits: ["9", "5", "2"], expect: "Driving time 9h52")
        // Audit a fresh launch so nodes left over from the dismissed sheets are not measured.
        app.terminate()
        let relaunched = launch(reset: false, daysBack: 1)
        XCTAssertTrue(relaunched.buttons["todayButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(relaunched.buttons["summaryDriving"].label.contains("?"))
        try audit(relaunched, "filled day")
        relaunched.segmentedControls["homeTabPicker"].buttons["Rest"].tap()
        XCTAssertTrue(relaunched.staticTexts["Rest Taken"].waitForExistence(timeout: 5))
        try audit(relaunched, "rest taken")
    }

    // MARK: - Helpers

    @MainActor
    private func launch(reset: Bool, daysBack: Int = 0) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-homeFlowUITest", "-seedReadyWeeklyRest"] + (reset ? ["-resetHomeFlowTest"] : [])
            + ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
            + (daysBack > 0 ? ["-startDaysBack", "\(daysBack)"] : [])
        app.launch()
        return app
    }

    @MainActor
    private func header(_ app: XCUIApplication) -> String {
        let date = app.staticTexts["headerDate"]
        XCTAssertTrue(date.waitForExistence(timeout: 5))
        // Let the push animation settle.
        _ = app.staticTexts["headerDate"].waitForExistence(timeout: 1)
        Thread.sleep(forTimeInterval: 0.5)
        return date.label
    }

    private func headerDate(daysBack: Int) -> String {
        let day = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date())!
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("dMMMMyyyy")
        return formatter.string(from: day)
    }

    /// Opens the Shift start / Rest start sheet and confirms its default (the current time of day).
    @MainActor
    private func enterTime(_ app: XCUIApplication, from summary: String, screenshot: String?) {
        app.buttons[summary].tap()
        let confirm = app.buttons["confirmSheetButton"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertTrue(app.datePickers["sheetDatePicker"].exists)
        if let screenshot { attach(screenshot) }
        XCTAssertTrue(confirm.isEnabled, "default time of day is valid")
        confirm.tap()
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5))
    }

    @MainActor
    private func enterDriving(_ app: XCUIApplication, digits: [String], expect: String) {
        app.buttons["summaryDriving"].tap()
        let confirm = app.buttons["confirmSheetButton"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        for digit in digits { app.buttons[digit].tap() }
        XCTAssertEqual(app.staticTexts["drivingValue"].label, expect)
        confirm.tap()
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5))
    }

    @MainActor
    private func element(_ app: XCUIApplication, startingWith prefix: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    @MainActor
    private func audit(_ app: XCUIApplication, _ state: String) throws {
        var issues: [String] = []
        try app.performAccessibilityAudit { issue in
            issues.append("\(issue.compactDescription): \(issue.element?.label ?? "unnamed node")")
            return true
        }
        print("AUDIT \(state): \(issues.isEmpty ? "clean" : issues.joined(separator: "; "))")
        XCTAssertTrue(issues.isEmpty, "\(state): \(issues.joined(separator: "; "))")
    }

    @MainActor
    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
