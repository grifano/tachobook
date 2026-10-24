import XCTest

/// The always-visible row under the Home gauge: beds on the Rest view (Figma 490:26367, 490:26319),
/// hammers on the Work view (564:39337), today and on past days.
final class RestCountUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.appearance = .light
    }

    @MainActor
    func testWeeklyCardShowsUsedBedsAndKeepsThemAfterRelaunch() {
        let app = launch(["-resetHomeFlowTest", "-seedReducedRests", "1", "-seedWeeklyCard"])
        XCTAssertTrue(app.staticTexts["Weekly Rest"].waitForExistence(timeout: 5))
        let beds = app.descendants(matching: .any)["reducedRestCount"]
        XCTAssertTrue(beds.waitForExistence(timeout: 5))
        XCTAssertEqual(beds.label, "1 of 3 reduced rests used")
        // Not interactive: no button. Three 18 pt beds 8 pt apart, centred under the gauge, inside the card.
        XCTAssertFalse(app.buttons["reducedRestCount"].exists)
        XCTAssertEqual(beds.frame.width, 70, accuracy: 0.5)
        let gauge = app.descendants(matching: .any)["homeGauge"].frame
        XCTAssertEqual(beds.frame.midX, gauge.midX, accuracy: 2)
        XCTAssertTrue(app.descendants(matching: .any)["mainWidget"].frame.contains(beds.frame))
        attach("490-26367 weekly rest, 1 used")

        app.terminate()
        let relaunched = launch([])
        XCTAssertTrue(relaunched.staticTexts["Weekly Rest"].waitForExistence(timeout: 5))
        XCTAssertEqual(relaunched.descendants(matching: .any)["reducedRestCount"].label, "1 of 3 reduced rests used")
    }

    @MainActor
    func testDailyCardShowsThreeAvailableBeds() {
        let app = launch(["-resetHomeFlowTest", "-seedReducedRests", "0"])
        XCTAssertTrue(app.staticTexts["Rest Time"].waitForExistence(timeout: 5))
        let beds = app.descendants(matching: .any)["reducedRestCount"]
        XCTAssertTrue(beds.waitForExistence(timeout: 5))
        XCTAssertEqual(beds.label, "0 of 3 reduced rests used")
        attach("490-26319 daily rest, 0 used")
    }

    @MainActor
    func testRestCardShowsThePendingBedAfterAShiftPastThirteenHours() {
        // 14 h shift closed a minute ago: the reduction already shows during the rest.
        let long = launch(["-resetHomeFlowTest", "-seedReducedRests", "1", "-seedDutyMinutes", "840"])
        XCTAssertTrue(long.staticTexts["Rest Time"].waitForExistence(timeout: 5))
        XCTAssertEqual(long.descendants(matching: .any)["reducedRestCount"].label, "2 of 3 reduced rests used")
        attach("rest after 14h shift, pending bed")
        long.terminate()

        // 12 h shift: the bed turns blue (used) only when the rest ends.
        let short = launch(["-resetHomeFlowTest", "-seedReducedRests", "1", "-seedDutyMinutes", "720"])
        XCTAssertTrue(short.staticTexts["Rest Time"].waitForExistence(timeout: 5))
        XCTAssertEqual(short.descendants(matching: .any)["reducedRestCount"].label, "1 of 3 reduced rests used")
        attach("rest after 12h shift, no pending bed")
    }

    @MainActor
    func testUnknownCountShowsThreeGrayBeds() {
        // The only record is a running rest: the count is unknown, never shown as 0 used, but the row stays.
        let app = launch(["-resetHomeFlowTest", "-seedReadyWeeklyRest"])
        XCTAssertTrue(app.staticTexts["Weekly Rest"].waitForExistence(timeout: 5))
        let beds = app.descendants(matching: .any)["reducedRestCount"]
        XCTAssertTrue(beds.waitForExistence(timeout: 5))
        XCTAssertEqual(beds.label, "Reduced rests used: unknown")
        attach("count unknown, three gray beds")
        select("Work", showing: "Work Time", in: app)
        XCTAssertEqual(app.descendants(matching: .any)["reducedRestCount"].label, "Extended shifts used: unknown")
        attach("count unknown, three gray hammers")
    }

    @MainActor
    func testWorkCardShowsHammersBeforeAndAfterThirteenHours() {
        // Regression (owner report 23.10.2026): 12:59 of duty, the row used to be hidden on the Work card.
        let before = launch(["-resetHomeFlowTest", "-seedReducedRests", "1", "-seedOpenShiftMinutes", "779"])
        XCTAssertTrue(before.staticTexts["Work Time"].waitForExistence(timeout: 5))
        let hammers = before.descendants(matching: .any)["reducedRestCount"]
        XCTAssertTrue(hammers.waitForExistence(timeout: 5))
        XCTAssertEqual(hammers.label, "1 of 3 extended shifts used")
        XCTAssertFalse(before.buttons["reducedRestCount"].exists)
        XCTAssertEqual(hammers.frame.width, 70, accuracy: 0.5)
        XCTAssertEqual(hammers.frame.midX, before.descendants(matching: .any)["homeGauge"].frame.midX, accuracy: 2)
        attach("work 12h59, 1 used")
        before.terminate()

        // 13:30: the reduction is certain, one more hammer is used (blue) than the completed count.
        let after = launch(["-resetHomeFlowTest", "-seedReducedRests", "1", "-seedOpenShiftMinutes", "810"])
        XCTAssertTrue(after.staticTexts["Work Time"].waitForExistence(timeout: 5))
        let pending = after.descendants(matching: .any)["reducedRestCount"]
        XCTAssertTrue(pending.waitForExistence(timeout: 5))
        XCTAssertEqual(pending.label, "2 of 3 extended shifts used")
        attach("work 13h30, pending hammer")
        after.terminate()

        // 14:30: together with the last-hour warning (00:30 left), checked on the screenshots
        // (the warning is part of the combined gauge element, so it has no frame of its own).
        for size in ["UICTContentSizeCategoryL", "UICTContentSizeCategoryXXXL", "UICTContentSizeCategoryAccessibilityL"] {
            let warning = launch(["-resetHomeFlowTest", "-seedReducedRests", "1", "-seedOpenShiftMinutes", "870"], size: size)
            XCTAssertTrue(warning.staticTexts["Work Time"].waitForExistence(timeout: 5))
            XCTAssertTrue(warning.descendants(matching: .any)["reducedRestCount"].waitForExistence(timeout: 5))
            let gauge = warning.descendants(matching: .any)["homeGauge"]
            XCTAssertTrue(gauge.label.contains("00:30"), gauge.label)
            attach("work 14h30, pending hammer and warning, \(size)")
            warning.terminate()
        }
    }

    @MainActor
    func testPastDaysShowTheCountAtTheEndOfThatDay() {
        // Two days ago: a 14 h shift after the first reduction — 2 at the end of the day; three days ago: 0.
        for (daysBack, used) in [(2, 2), (3, 0)] {
            let app = launch(["-resetHomeFlowTest", "-seedCountHistory", "-startDaysBack", "\(daysBack)"])
            XCTAssertTrue(app.staticTexts["Work Time"].waitForExistence(timeout: 5))
            let row = app.descendants(matching: .any)["reducedRestCount"]
            XCTAssertTrue(row.waitForExistence(timeout: 5))
            XCTAssertEqual(row.label, "\(used) of 3 extended shifts used")
            attach("past day -\(daysBack), work, \(used) used")
            select("Rest", showing: "Rest Taken", in: app)
            XCTAssertEqual(app.descendants(matching: .any)["reducedRestCount"].label, "\(used) of 3 reduced rests used")
            attach("past day -\(daysBack), rest, \(used) used")
            app.terminate()
        }
        // Today, resting after yesterday's shift: the two completed reductions.
        let today = launch(["-resetHomeFlowTest", "-seedCountHistory"])
        XCTAssertTrue(today.descendants(matching: .any)["reducedRestCount"].waitForExistence(timeout: 5))
        XCTAssertEqual(today.descendants(matching: .any)["reducedRestCount"].label, "2 of 3 reduced rests used")
        select("Work", showing: "Work Time", in: today)
        XCTAssertEqual(today.descendants(matching: .any)["reducedRestCount"].label, "2 of 3 extended shifts used")
    }

    @MainActor
    func testAccessibilityAuditWithBeds() throws {
        for (args, title) in [(["-seedReducedRests", "2", "-seedWeeklyCard"], "Weekly Rest"),
                              (["-seedReducedRests", "3"], "Rest Time"),
                              (["-seedReducedRests", "1", "-seedOpenShiftMinutes", "870"], "Work Time"),
                              (["-seedReducedRests", "1", "-seedOpenShiftMinutes", "60"], "Work Time"),
                              (["-seedReadyWeeklyRest"], "Weekly Rest"),
                              (["-seedCountHistory", "-startDaysBack", "2"], "Work Time")] {
            let app = launch(["-resetHomeFlowTest"] + args)
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
            XCTAssertTrue(app.descendants(matching: .any)["reducedRestCount"].waitForExistence(timeout: 5))
            var issues: [String] = []
            try app.performAccessibilityAudit { issue in
                // Temporary, see AccessibilityAuditSupport: the dimmed tabs lack the "not enabled" trait.
                if issue.isNotEnabledTraitOnADisabledTab { return true }
                issues.append("\(issue.compactDescription): \(issue.element?.label ?? "unnamed node")")
                return true
            }
            print("AUDIT \(title) \(args): \(issues.isEmpty ? "clean" : issues.joined(separator: "; "))")
            XCTAssertTrue(issues.isEmpty, "\(title): \(issues.joined(separator: "; "))")
            app.terminate()
        }
    }

    @MainActor
    private func launch(_ extra: [String], size: String = "UICTContentSizeCategoryL") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-homeFlowUITest", "-UIPreferredContentSizeCategoryName", size] + extra
        app.launch()
        return app
    }

    /// Switches the Home view. Under parallel UI-test load a tap right after launch can land before the
    /// picker settles, so it waits for the segment and taps once more if the card title does not change.
    @MainActor
    private func select(_ segment: String, showing title: String, in app: XCUIApplication) {
        let button = app.segmentedControls["homeTabPicker"].buttons[segment]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        if !app.staticTexts[title].waitForExistence(timeout: 5) { button.tap() }
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
