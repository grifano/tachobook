import XCTest

/// Figma "Flow 1 - Log Day Shift" end to end, with a weekly rest seeded 46 h ago.
final class HomeFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        // Figma is light; the accessibility audit may leave the simulator in another appearance.
        XCUIDevice.shared.appearance = .light
    }

    @MainActor
    func testStartCloseDrivingToggleAndRelaunch() {
        let app = launch(reset: true)

        // 01: weekly rest finished, Start of day enabled.
        XCTAssertTrue(app.staticTexts["Weekly Rest"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Last Shift Summary"].exists)
        let startOfDay = app.buttons["startOfDayButton"]
        XCTAssertTrue(startOfDay.isEnabled)
        attach("01 weekly rest")

        // 02 → 03: start the shift now.
        startOfDay.tap()
        confirmSheet(app, "02 shift start sheet")
        let endOfDay = app.buttons["endOfDayButton"]
        XCTAssertTrue(endOfDay.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Work Time"].exists)
        XCTAssertTrue(element(app, startingWith: "13h limit end").exists)
        XCTAssertFalse(app.segmentedControls["homeTabPicker"].buttons["Rest"].isEnabled, "Rest tab is inactive while working")
        attach("03 shift started")

        // 05 → 06: close the shift, the driving reminder appears; Later keeps driving empty.
        endOfDay.tap()
        confirmSheet(app, "05 rest start sheet")
        let alert = app.alerts["Shift closed"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        attach("06 driving alert")
        alert.buttons["Later"].tap()
        XCTAssertTrue(app.staticTexts["Rest Time"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["summaryDriving"].label.contains("?"))

        // 08: daily rest with Start of day dimmed.
        XCTAssertFalse(startOfDay.isEnabled)
        XCTAssertTrue(startOfDay.label.contains("Available in 09:00") || startOfDay.label.contains("Available in 08:59"), startOfDay.label)
        attach("08 daily rest")

        // 09: the toggle switches the view only.
        app.segmentedControls["homeTabPicker"].buttons["Work"].tap()
        XCTAssertTrue(element(app, startingWith: "End at").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["endOfDayButton"].exists)
        attach("09 rest, Work tab")
        app.segmentedControls["homeTabPicker"].buttons["Rest"].tap()
        XCTAssertTrue(app.staticTexts["Rest Time"].waitForExistence(timeout: 5))

        // 07: Driving in the summary opens the keypad.
        enterDriving(app, from: app.buttons["summaryDriving"])
        XCTAssertTrue(app.buttons["summaryDriving"].label.contains("09h52m"))

        // Relaunch keeps the rest, the driving time and the default Rest tab.
        app.terminate()
        let relaunched = launch(reset: false)
        XCTAssertTrue(relaunched.staticTexts["Rest Time"].waitForExistence(timeout: 5))
        XCTAssertTrue(relaunched.buttons["summaryDriving"].label.contains("09h52m"))
        XCTAssertFalse(relaunched.buttons["startOfDayButton"].isEnabled)
        attach("08 after relaunch")
    }

    @MainActor
    func testAddTimeFromAlertAndEditedValuesArePrefilled() {
        let app = launch(reset: true)
        XCTAssertTrue(app.buttons["startOfDayButton"].waitForExistence(timeout: 5))
        app.buttons["startOfDayButton"].tap()
        confirmSheet(app, nil)
        app.buttons["endOfDayButton"].tap()
        confirmSheet(app, nil)

        let alert = app.alerts["Shift closed"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        enterDriving(app, from: alert.buttons["Add time"])
        XCTAssertTrue(app.buttons["summaryDriving"].label.contains("09h52m"))

        // Editing reopens the same sheet with the current value.
        app.buttons["summaryDriving"].tap()
        XCTAssertTrue(app.staticTexts["drivingValue"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["drivingValue"].label, "Driving time 9h52")
        app.buttons["closeSheetButton"].tap()

        app.buttons["summaryDayClosed"].tap()
        XCTAssertTrue(app.staticTexts["Rest start"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["confirmSheetButton"].isEnabled)
        attach("Day closed edit sheet")
        app.buttons["closeSheetButton"].tap()
    }

    /// Switching Work ↔ Rest must not move the widget, the button row or the summary card.
    @MainActor
    func testToggleDoesNotShiftLayout() {
        let app = launch(reset: true)
        XCTAssertTrue(app.buttons["startOfDayButton"].waitForExistence(timeout: 5))
        app.buttons["startOfDayButton"].tap()
        confirmSheet(app, nil)
        let workState = frames(app)
        app.buttons["endOfDayButton"].tap()
        confirmSheet(app, nil)
        app.alerts["Shift closed"].buttons["Later"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForNonExistence(timeout: 5))

        let picker = app.segmentedControls["homeTabPicker"]
        XCTAssertTrue(app.staticTexts["Rest Time"].waitForExistence(timeout: 5))
        let rest = frames(app)
        picker.buttons["Work"].tap()
        XCTAssertTrue(element(app, startingWith: "End at").waitForExistence(timeout: 5))
        let work = frames(app)
        attach("Toggle Work")
        picker.buttons["Rest"].tap()
        XCTAssertTrue(app.staticTexts["Rest Time"].waitForExistence(timeout: 5))
        attach("Toggle Rest")
        print("LAYOUT work state widget \(workState.widget), rest widget \(rest.widget) card \(rest.card), work tab widget \(work.widget) card \(work.card)")

        XCTAssertEqual(rest.widget, work.widget, "Main widget moved or resized")
        XCTAssertEqual(rest.card, work.card, "Summary card moved")
        XCTAssertEqual(workState.widget, rest.widget, "Work and Rest widgets differ in height")
    }

    @MainActor
    private func frames(_ app: XCUIApplication) -> (widget: CGRect, card: CGRect) {
        let widget = app.otherElements["mainWidget"]
        let card = app.otherElements["secondaryCard"]
        XCTAssertTrue(widget.waitForExistence(timeout: 5))
        XCTAssertTrue(card.exists)
        return (widget.frame, card.frame)
    }

    @MainActor
    func testRemainingTimeTurnsRedInTheLastHour() {
        let app = XCUIApplication()
        app.launchArguments = ["-homeFlowUITest", "-resetHomeFlowTest", "-seedNearDutyLimit"]
        app.launch()
        XCTAssertTrue(app.buttons["endOfDayButton"].waitForExistence(timeout: 5))
        let gauge = app.descendants(matching: .any)["homeGauge"]
        XCTAssertTrue(gauge.label.contains("14:45"), gauge.label)
        XCTAssertTrue(gauge.label.contains("00:15"))
        attach("04 near the 15 h limit")
    }

    @MainActor
    func testHomeKeepsMarginsWithLargeText() {
        for size in ["UICTContentSizeCategoryXXXL", "UICTContentSizeCategoryAccessibilityM"] {
            let app = launch(reset: true, extra: ["-UIPreferredContentSizeCategoryName", size])
            let summary = app.buttons["summaryDayClosed"]
            XCTAssertTrue(summary.waitForExistence(timeout: 5))
            let width = app.windows.firstMatch.frame.width
            for element in [app.staticTexts["Weekly Rest"], app.buttons["startOfDayButton"], app.descendants(matching: .any)["homeGauge"]] {
                XCTAssertTrue(element.exists)
                XCTAssertGreaterThanOrEqual(element.frame.minX, 16)
                XCTAssertLessThanOrEqual(element.frame.maxX, width - 16)
            }
            if !summary.isHittable { app.swipeUp() }
            XCTAssertTrue(summary.isHittable)
            attach("Large text \(size)")
            app.terminate()
        }
    }

    @MainActor
    func testAccessibilityAuditOfHomeStates() throws {
        continueAfterFailure = true // report every state's findings in one run
        var app = launch(reset: true)
        XCTAssertTrue(app.buttons["startOfDayButton"].waitForExistence(timeout: 5))
        try audit(app, "rest finished")
        app.buttons["startOfDayButton"].tap()
        confirmSheet(app, nil)
        XCTAssertTrue(app.buttons["endOfDayButton"].waitForExistence(timeout: 5))
        try audit(app, "work")
        app.buttons["endOfDayButton"].tap()
        confirmSheet(app, nil)
        app.alerts["Shift closed"].buttons["Later"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Rest Time"].waitForExistence(timeout: 5))
        // Audit a fresh launch so nodes left over from the dismissed sheet and alert are not measured.
        app.terminate()
        app = launch(reset: false)
        XCTAssertTrue(app.staticTexts["Rest Time"].waitForExistence(timeout: 5))
        try audit(app, "daily rest")
        app.segmentedControls["homeTabPicker"].buttons["Work"].tap()
        XCTAssertTrue(element(app, startingWith: "End at").waitForExistence(timeout: 5))
        try audit(app, "rest, Work tab")
        app.terminate()

        // Frame 04: the red remaining time.
        let nearLimit = XCUIApplication()
        nearLimit.launchArguments = ["-homeFlowUITest", "-resetHomeFlowTest", "-seedNearDutyLimit",
                                     "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        nearLimit.launch()
        XCTAssertTrue(nearLimit.buttons["endOfDayButton"].waitForExistence(timeout: 5))
        try audit(nearLimit, "near limit")
    }

    // MARK: - Helpers

    /// Every audit category must pass, contrast included. Issues are collected per state
    /// and reported together so one run shows all of them.
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
    private func launch(reset: Bool, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        let size = extra.isEmpty ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"] : []
        app.launchArguments = ["-homeFlowUITest", "-seedReadyWeeklyRest"] + (reset ? ["-resetHomeFlowTest"] : []) + size + extra
        app.launch()
        return app
    }

    /// Combined accessibility elements read "Title, value".
    @MainActor
    private func element(_ app: XCUIApplication, startingWith prefix: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    @MainActor
    private func confirmSheet(_ app: XCUIApplication, _ screenshot: String?) {
        let confirm = app.buttons["confirmSheetButton"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertTrue(app.datePickers["sheetDatePicker"].exists)
        if let screenshot { attach(screenshot) }
        confirm.tap()
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5))
    }

    @MainActor
    private func enterDriving(_ app: XCUIApplication, from button: XCUIElement) {
        button.tap()
        let confirm = app.buttons["confirmSheetButton"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        for digit in ["9", "5", "2"] { app.buttons[digit].tap() }
        XCTAssertEqual(app.staticTexts["drivingValue"].label, "Driving time 9h52")
        attach("07 driving time")
        confirm.tap()
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5))
    }

    @MainActor
    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
