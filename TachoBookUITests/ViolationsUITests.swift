import XCTest

/// Deviation counter: Violations tab (Flow 4), violation sheet and printout (decisions 9, 15–19), Home alerts and red
/// overtime (Flow 3; decisions 2, 3, 12, 13), the red line in time sheets (decision 14) and History (decision 20).
/// Seed `-seedViolations`: 3 days ago a 16 h shift (15 h limit passed by 1:00) and an 8 h rest (daily rest under 9 h);
/// 70 days ago an 8 h rest (older than 56 days, no printout).
final class ViolationsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.appearance = .light
    }

    @MainActor
    func testListSheetAndPrintoutJustNowSurviveRelaunch() throws {
        var app = launch(["-resetHomeFlowTest", "-seedViolations"], tab: "Violations")
        let rows = app.buttons.matching(identifier: "violationRow")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows.element(boundBy: 0).label, "Daily rest under 9h, No printout marked yet")
        XCTAssertEqual(rows.element(boundBy: 1).label, "Shift limit passed, No printout marked yet")
        XCTAssertEqual(rows.element(boundBy: 2).label, "Daily rest under 9h, No printout marked")
        XCTAssertEqual(rows.element(boundBy: 0).value as? String, "Printout missing")
        XCTAssertTrue(app.staticTexts["olderGroupLabel"].exists)
        attach("Flow 4 · 01/07 list, printouts missing, older group")
        try audit(app, "Violations list")

        // Flow 4 · 05: the short rest sheet.
        rows.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["sheetTitle"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["sheetTitle"].label, "Daily rest under 9h")
        XCTAssertTrue(app.staticTexts["sheetSubtitle"].label.hasSuffix("· rest 8:00 in 24 h"), app.staticTexts["sheetSubtitle"].label)
        XCTAssertEqual(app.staticTexts["violationRedLine"].label, "Your daily rest was shorter than 9 hours.")
        XCTAssertTrue(app.staticTexts["Print a tachograph log and write the reason on it by hand when you stop."].exists)
        XCTAssertTrue(app.descendants(matching: .any)["printoutNote"].label.contains("Art. 12 EC 561/2006"))
        attach("Flow 4 · 05 sheet, printout missing")
        try audit(app, "Short rest sheet")

        // Flow 4 · 08 → Just now → Flow 4 · 03.
        app.buttons["printoutDoneButton"].tap()
        let alert = app.alerts["When did you print it?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts["Printed it before and forgot to mark it? Tap Earlier."].exists)
        attach("Flow 4 · 08 alert")
        alert.buttons["Just now"].tap()
        let line = app.staticTexts["printoutLine"]
        XCTAssertTrue(line.waitForExistence(timeout: 5))
        XCTAssertTrue(line.label.hasPrefix("Printout done on "), line.label)
        XCTAssertTrue(line.label.hasSuffix(" · 56 days left."), line.label)
        XCTAssertTrue(app.descendants(matching: .any)["printoutDoneState"].exists)
        XCTAssertTrue(app.buttons["markNotDoneButton"].exists)
        attach("Flow 4 · 03 printout done")
        try audit(app, "Printout done sheet")
        app.buttons["closeSheetButton"].tap()
        XCTAssertTrue(line.waitForNonExistence(timeout: 5))
        XCTAssertTrue(rows.element(boundBy: 0).label.hasSuffix(" · 56 days left"), rows.element(boundBy: 0).label)
        XCTAssertEqual(rows.element(boundBy: 0).value as? String, "Printout done")
        attach("Flow 4 · 04 list, one printout done")

        // Saved: the counter is back after a relaunch; Mark as not done shows "?" again.
        app.terminate()
        app = launch([], tab: "Violations")
        let relaunchedRows = app.buttons.matching(identifier: "violationRow")
        XCTAssertTrue(relaunchedRows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(relaunchedRows.element(boundBy: 0).label.hasSuffix(" · 56 days left"), relaunchedRows.element(boundBy: 0).label)
        relaunchedRows.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["markNotDoneButton"].waitForExistence(timeout: 5))
        app.buttons["markNotDoneButton"].tap()
        XCTAssertTrue(app.buttons["printoutDoneButton"].waitForExistence(timeout: 5))
        app.buttons["skipForNowButton"].tap()
        XCTAssertTrue(app.buttons["skipForNowButton"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(relaunchedRows.element(boundBy: 0).label, "Daily rest under 9h, No printout marked yet")
    }

    @MainActor
    func testEarlierOpensThePrintoutTimeSheet() throws {
        let app = launch(["-resetHomeFlowTest", "-seedViolations"], tab: "Violations")
        let rows = app.buttons.matching(identifier: "violationRow")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        rows.element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts["sheetTitle"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["sheetTitle"].label, "Shift limit passed")
        XCTAssertTrue(app.staticTexts["sheetSubtitle"].label.hasSuffix("· over by 1:00 since 20:00"),
                      app.staticTexts["sheetSubtitle"].label)
        XCTAssertEqual(app.staticTexts["violationRedLine"].label, "You\u{2019}ve passed your 15-hour shift limit.")
        attach("Flow 4 · 02 sheet, printout missing")

        app.buttons["printoutDoneButton"].tap()
        let alert = app.alerts["When did you print it?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Earlier"].tap()
        XCTAssertTrue(app.staticTexts["Printout time"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["When did you print it?"].exists)
        let confirm = app.buttons["confirmSheetButton"]
        XCTAssertTrue(confirm.isEnabled, "now is a valid printout time")
        attach("Flow 4 · 09 printout time sheet")
        // Not audited: this is the existing time sheet, whose system date picker no test audits (see the PR).
        confirm.tap()
        XCTAssertTrue(app.staticTexts["printoutLine"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testOlderRowReturnsToTheMainListWithAPrintout() {
        let app = launch(["-resetHomeFlowTest", "-seedViolations"], tab: "Violations")
        let rows = app.buttons.matching(identifier: "violationRow")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        rows.element(boundBy: 2).tap()
        app.buttons["printoutDoneButton"].tap()
        app.alerts["When did you print it?"].buttons["Just now"].tap()
        XCTAssertTrue(app.staticTexts["printoutLine"].waitForExistence(timeout: 5))
        app.buttons["closeSheetButton"].tap()
        XCTAssertTrue(app.staticTexts["olderGroupLabel"].waitForNonExistence(timeout: 5), "no older row is left")
        XCTAssertTrue(rows.element(boundBy: 2).label.hasSuffix(" · 56 days left"), rows.element(boundBy: 2).label)
    }

    @MainActor
    func testEmptyList() throws {
        let app = launch(["-resetHomeFlowTest", "-seedReadyWeeklyRest"], tab: "Violations")
        let empty = app.descendants(matching: .any)["violationsEmpty"]
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        XCTAssertEqual(empty.label, "No violations, Your records show no limit passed.")
        attach("Flow 4 · 06 empty")
        try audit(app, "Violations empty")
    }

    // MARK: - Home (Flow 3)

    @MainActor
    func testLimitPassedAlertOnceRedOvertimeAndSheet() throws {
        // 3 of 3 used, shift open for 13:30: the 13 h limit passed 30 min ago.
        var app = launch(["-resetHomeFlowTest", "-seedReducedRests", "3", "-seedOpenShiftMinutes", "810"])
        let alert = app.alerts["\u{2757} 13h limit passed"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts["You\u{2019}re 0:30 over your shift limit. Print a tachograph log when you stop."].exists
                      || alert.staticTexts["You\u{2019}re 0:31 over your shift limit. Print a tachograph log when you stop."].exists,
                      alert.debugDescription)
        attach("Flow 3 · 00b limit passed alert")
        alert.buttons["Show details"].tap()
        XCTAssertTrue(app.staticTexts["sheetTitle"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["sheetTitle"].label, "13h limit passed")
        XCTAssertTrue(app.staticTexts["sheetSubtitle"].label.hasPrefix("Over by 0:3"), app.staticTexts["sheetSubtitle"].label)
        XCTAssertEqual(app.staticTexts["violationRedLine"].label, "You\u{2019}ve passed your 13-hour shift limit.")
        XCTAssertFalse(app.buttons["printoutDoneButton"].exists, "Flow 3 · 02 has the close button only")
        attach("Flow 3 · 02 sheet over Home")
        try audit(app, "Home violation sheet")
        app.buttons["closeSheetButton"].tap()

        // The red overtime stays and opens the same sheet.
        let overtime = app.buttons["dutyOvertime"]
        XCTAssertTrue(overtime.waitForExistence(timeout: 5))
        XCTAssertTrue(overtime.label.hasPrefix("Over the limit by "), overtime.label)
        attach("Flow 3 · 01 Home, 13h limit passed")
        try audit(app, "Home with red overtime")
        overtime.tap()
        XCTAssertTrue(app.staticTexts["sheetTitle"].waitForExistence(timeout: 5))
        app.buttons["closeSheetButton"].tap()

        // Once: not again after a relaunch.
        app.terminate()
        app = launch([])
        XCTAssertTrue(app.buttons["dutyOvertime"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 3))
    }

    @MainActor
    func testPreLimitAlertEndOfDayOpensTheCloseSheet() {
        // 3 of 3 used, shift open for 12:50: 10 min left to the 13 h limit.
        let app = launch(["-resetHomeFlowTest", "-seedReducedRests", "3", "-seedOpenShiftMinutes", "770"])
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.label == "10 min left to your 13h limit" || alert.label == "9 min left to your 13h limit",
                      alert.label)
        let message = alert.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH %@ AND label ENDSWITH %@",
            "Start your rest by ", " to stay within the limit. Keep working?")).firstMatch
        XCTAssertTrue(message.exists, alert.debugDescription)
        attach("Flow 3 · 00 pre-limit alert")
        alert.buttons["End of day"].tap()
        XCTAssertTrue(app.staticTexts["Rest start"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["sheetOverLimit"].exists, "closing now stays within 13 h")
    }

    @MainActor
    func testClosingLateShowsTheRedLineAndRecordsTheViolation() {
        let app = launch(["-resetHomeFlowTest", "-seedReducedRests", "3", "-seedOpenShiftMinutes", "810"])
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Later"].tap()
        app.buttons["endOfDayButton"].tap()
        let line = app.staticTexts["sheetOverLimit"]
        XCTAssertTrue(line.waitForExistence(timeout: 5))
        XCTAssertTrue(line.label.hasPrefix("This shift passes your 13-hour limit by 0:3"), line.label)
        let confirm = app.buttons["confirmSheetButton"]
        XCTAssertTrue(confirm.isEnabled, "never blocked (decision 14)")
        attach("Decision 14 red line in the Rest start sheet")
        confirm.tap()
        let driving = app.alerts["Shift closed"]
        XCTAssertTrue(driving.waitForExistence(timeout: 5))
        driving.buttons["Later"].tap()
        app.tabBars.buttons["Violations"].tap()
        let row = app.buttons.matching(identifier: "violationRow").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertEqual(row.label, "Shift limit passed, No printout marked yet")
    }

    // MARK: - History (decision 20)

    @MainActor
    func testHistoryMarksTheDayAndGoToRuleOpensTheList() throws {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        try XCTSkipUnless(Calendar.current.isDate(threeDaysAgo, equalTo: Date(), toGranularity: .month),
                          "the violation day must be in the month the calendar opens on")
        let app = launch(["-resetHomeFlowTest", "-seedViolations"], tab: "History")
        let monthDay = threeDaysAgo.formatted(.dateTime.month(.wide).day())
        let cell = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", monthDay)).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        // The late close also used a reduction (bed), as the Home row counts it.
        XCTAssertTrue((cell.value as? String)?.hasSuffix("rule broken") == true, String(describing: cell.value))
        XCTAssertTrue(app.staticTexts["Rule broken this day"].exists)
        attach("History · 01 calendar with the rule broken marker")
        cell.tap()
        let subtitle = app.staticTexts["daySummaryDate"]
        XCTAssertTrue(subtitle.waitForExistence(timeout: 5))
        XCTAssertTrue(subtitle.label.hasSuffix(" · 2 violations"), subtitle.label)
        let redLines = app.staticTexts.matching(identifier: "daySummaryRedLine")
        XCTAssertEqual(redLines.count, 2)
        XCTAssertTrue(app.buttons["goToRuleButton"].exists)
        attach("History · 03 Day summary with violations")
        try audit(app, "Day summary with violations")
        app.buttons["goToRuleButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["violationsList"].waitForExistence(timeout: 5),
                      "two violations: the list opens")
    }

    // MARK: - Helpers

    @MainActor
    private func launch(_ arguments: [String], tab: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-homeFlowUITest", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
            + arguments
        app.launch()
        if let tab {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            button.tap()
            // Let the tab cross-fade finish before reading or auditing.
            Thread.sleep(forTimeInterval: 1)
        }
        return app
    }

    @MainActor
    private func audit(_ app: XCUIApplication, _ state: String) throws {
        var issues: [String] = []
        try app.performAccessibilityAudit { issue in
            // Temporary, see AccessibilityAuditSupport: the dimmed Restrictions tab lacks the "not enabled" trait.
            if issue.isNotEnabledTraitOnADisabledTab { return true }
            // The native calendar's own day numbers, see AccessibilityAuditSupport.
            if issue.isNativeCalendarDayNumber { return true }
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
