import XCTest

/// MVP-07 History tab: month calendar with markers, legend, and the read-only Day summary sheet.
/// Seed `-seedHistoryWeek`: shifts 5, 3, 2 and 1 days ago; reduced rests after the shifts 3 and 2 days ago (beds on
/// those shift days), extended driving 2 days ago and yesterday (wheels), nothing 4 days ago.
final class HistoryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.appearance = .light
    }

    @MainActor
    func testCalendarMarkersLegendAndMonthNavigation() throws {
        let app = launchOnHistory()
        XCTAssertTrue(app.staticTexts["Tap a date to see that day."].exists)
        XCTAssertTrue(app.staticTexts["Reduced rest (9–11 h)"].exists)
        XCTAssertTrue(app.staticTexts["Extended driving (10 h)"].exists)
        XCTAssertTrue(app.staticTexts["Rule broken this day"].exists)

        // Each decorated date names its markers for VoiceOver.
        let bedDay = dayCell(app, daysBack: 3)
        XCTAssertTrue(bedDay.waitForExistence(timeout: 5))
        XCTAssertEqual(spoken(bedDay), "reduced rest")
        XCTAssertEqual(spoken(dayCell(app, daysBack: 2)), "reduced rest, extended driving")
        XCTAssertEqual(spoken(dayCell(app, daysBack: 1)), "extended driving")
        XCTAssertEqual(spoken(dayCell(app, daysBack: 4)), "")
        XCTAssertEqual(spoken(dayCell(app, daysBack: 5)), "", "a normal day has no markers")
        attach("History calendar")
        try audit(app, "History calendar")

        // Previous month and back.
        let month = monthTitle(Date())
        XCTAssertTrue(app.staticTexts[month].exists || app.buttons[month].exists)
        app.buttons["Previous Month"].tap()
        let previous = monthTitle(Calendar.current.date(byAdding: .month, value: -1, to: Date())!)
        XCTAssertTrue(app.staticTexts[previous].waitForExistence(timeout: 5) || app.buttons[previous].exists)
        app.buttons["Next Month"].tap()
        XCTAssertTrue(app.staticTexts[month].waitForExistence(timeout: 5) || app.buttons[month].exists)
        XCTAssertFalse(app.buttons["Next Month"].isEnabled, "no months after the current one")
    }

    @MainActor
    func testTappingADayOpensItsSummaryAndAnEmptyDaySaysSo() throws {
        let app = launchOnHistory()
        dayCell(app, daysBack: 2).tap()
        let close = app.buttons["closeSheetButton"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Day summary"].exists)
        XCTAssertEqual(app.staticTexts["daySummaryDate"].label, "\(sheetDate(daysBack: 2)) · No violations")
        // The 14 h shift 06:00–20:00 with 10 h driving, as Home shows it (DayHistory past-day summary).
        XCTAssertTrue(app.descendants(matching: .any)["daySummaryStarted"].label.contains("06:00"))
        XCTAssertTrue(app.descendants(matching: .any)["daySummaryDriving"].label.contains("10h00m"))
        XCTAssertTrue(app.descendants(matching: .any)["daySummaryClosed"].label.contains("20:00"))
        // Its own reduced rest counts on this day, after the one of the day before.
        XCTAssertTrue(element(app, containing: "2 of 3 reduced rests used").exists)
        XCTAssertFalse(app.buttons["goToRuleButton"].exists, "no violation on this day")
        attach("Day summary with data")
        // iOS 26 draws the medium-detent sheet slightly scaled down, which the audit reads as too-small hit areas
        // and clipped text; it audits the same content in the expanded sheet.
        let title = app.staticTexts["Day summary"]
        title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)))
        XCTAssertLessThan(title.frame.minY, 150, "sheet expanded")
        try audit(app, "Day summary (expanded)")
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))

        // The same date opens again after the sheet closed.
        dayCell(app, daysBack: 2).tap()
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))

        dayCell(app, daysBack: 4).tap()
        XCTAssertTrue(app.staticTexts["daySummaryEmpty"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["daySummaryEmpty"].label, "No records for this day.")
        attach("Day summary empty")
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testFutureDatesAreNotSelectable() {
        let app = launchOnHistory()
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()),
              Calendar.current.isDate(tomorrow, equalTo: Date(), toGranularity: .month) else { return }
        let cell = dayCell(app, daysBack: -1)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        XCTAssertFalse(cell.isEnabled)
        cell.tap()
        XCTAssertFalse(app.buttons["closeSheetButton"].waitForExistence(timeout: 2))
    }

    // MARK: - Add past shift (owner decision 5, 16.11.2026)

    /// The Add button is on History only, reads "Add past shift" to VoiceOver and starts the normal Shift start sheet.
    @MainActor
    func testAddPastShiftButtonIsOnHistoryOnlyAndStartsTheShiftStartSheet() throws {
        let app = launchOnHistory()
        let add = app.buttons["addPastShiftButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        XCTAssertEqual(add.label, "Add past shift")
        try audit(app, "History with Add")

        add.tap()
        XCTAssertTrue(app.staticTexts["Shift start"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["When did your shift begin?"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["sheetDatePicker"].exists)
        attach("Add past shift - start sheet")
        app.buttons["closeSheetButton"].tap()
        XCTAssertTrue(app.staticTexts["Shift start"].waitForNonExistence(timeout: 5))

        for tab in ["Home", "Violations"] {
            app.tabBars.buttons[tab].tap()
            XCTAssertFalse(app.buttons["addPastShiftButton"].waitForExistence(timeout: 2), "no Add on \(tab)")
        }
    }

    /// Start → close → driving saves one shift; a second entry on the same day asks to replace it, and Cancel keeps
    /// the sheet open.
    @MainActor
    func testAddPastShiftRunsTheNormalFlowAndAsksBeforeReplacing() throws {
        let app = launchOnHistory()
        let add = app.buttons["addPastShiftButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let confirm = app.buttons["confirmSheetButton"]
        XCTAssertTrue(app.staticTexts["Shift start"].waitForExistence(timeout: 5))
        // The seeded shifts have no country and a past date is never filled from the location: the driver picks it.
        XCTAssertFalse(confirm.isEnabled)
        app.buttons["countryPicker"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Pol")
        let poland = app.buttons["countryRow-PL"]
        XCTAssertTrue(poland.waitForExistence(timeout: 5))
        poland.tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertTrue(confirm.isEnabled)
        confirm.tap()
        XCTAssertTrue(app.staticTexts["Rest start"].waitForExistence(timeout: 5))
        attach("Add past shift - close sheet")
        confirm.tap()
        XCTAssertTrue(app.staticTexts["Driving time"].waitForExistence(timeout: 5))
        for digit in ["1", "3", "0"] { app.buttons[digit].tap() }
        XCTAssertEqual(app.staticTexts["drivingValue"].label, "Driving time 1h30")
        confirm.tap()
        XCTAssertTrue(app.staticTexts["Driving time"].waitForNonExistence(timeout: 5))

        // Today now has the new shift.
        dayCell(app, daysBack: 0).tap()
        XCTAssertTrue(app.staticTexts["Day summary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["daySummaryDriving"].label.contains("1h30m"))
        app.buttons["closeSheetButton"].tap()
        XCTAssertTrue(app.staticTexts["Day summary"].waitForNonExistence(timeout: 5))

        // The same day again: one shift per day, so it asks first.
        add.tap()
        XCTAssertTrue(app.staticTexts["Shift start"].waitForExistence(timeout: 5))
        confirm.tap()
        let alert = app.alerts["Replace your shift?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        attach("Add past shift - replace alert")
        alert.buttons["Cancel"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Shift start"].exists, "Cancel returns to the sheet")
        app.buttons["closeSheetButton"].tap()
        XCTAssertTrue(app.staticTexts["Shift start"].waitForNonExistence(timeout: 5))
    }

    // MARK: - Helpers

    @MainActor
    private func launchOnHistory() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-homeFlowUITest", "-resetHomeFlowTest", "-seedHistoryWeek",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        let tab = app.tabBars.buttons["History"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()
        XCTAssertTrue(app.otherElements["historyLegend"].waitForExistence(timeout: 5)
                      || app.staticTexts["Tap a date to see that day."].waitForExistence(timeout: 5))
        // Let the tab cross-fade finish: an audit during it measured the card over the dark photo.
        Thread.sleep(forTimeInterval: 1)
        return app
    }

    /// The calendar cell of a day, found by its day number and full date in the label.
    @MainActor
    private func dayCell(_ app: XCUIApplication, daysBack: Int) -> XCUIElement {
        let date = Calendar.current.date(byAdding: .day, value: -daysBack, to: Calendar.current.startOfDay(for: Date()))!
        let monthDay = date.formatted(.dateTime.month(.wide).day())
        return app.buttons.matching(NSPredicate(format: "label CONTAINS %@", monthDay)).firstMatch
    }

    /// VoiceOver reads the date (label) followed by the marker names (the cell's value).
    @MainActor
    private func spoken(_ cell: XCUIElement) -> String {
        (cell.value as? String) ?? ""
    }

    private func monthTitle(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }

    private func sheetDate(daysBack: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: date)) \(Calendar.current.component(.year, from: date))"
    }

    @MainActor
    private func element(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@ AND label != 'Violations'", text)).firstMatch
    }

    @MainActor
    private func audit(_ app: XCUIApplication, _ state: String) throws {
        var issues: [String] = []
        try app.performAccessibilityAudit { issue in
            // Temporary, see AccessibilityAuditSupport: the dimmed tabs lack the "not enabled" trait.
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
