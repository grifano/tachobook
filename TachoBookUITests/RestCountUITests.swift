import XCTest

/// Reduced daily rest beds under the rest gauge (Figma 490:26367, 490:26319).
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

        // 12 h shift: the bed turns red only when the rest ends.
        let short = launch(["-resetHomeFlowTest", "-seedReducedRests", "1", "-seedDutyMinutes", "720"])
        XCTAssertTrue(short.staticTexts["Rest Time"].waitForExistence(timeout: 5))
        XCTAssertEqual(short.descendants(matching: .any)["reducedRestCount"].label, "1 of 3 reduced rests used")
        attach("rest after 12h shift, no pending bed")
    }

    @MainActor
    func testBedsAreHiddenWithoutACompletedWeeklyRest() {
        // The only record is a running rest: the count is unknown, never shown as 0 used.
        let app = launch(["-resetHomeFlowTest", "-seedReadyWeeklyRest"])
        XCTAssertTrue(app.staticTexts["Weekly Rest"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["homeGauge"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["reducedRestCount"].exists)
        attach("count unknown, beds hidden")
    }

    @MainActor
    func testWorkCardShowsThePendingBedOnlyAfterThirteenHours() {
        // 12:59 of duty: no bed row on the Work card.
        let before = launch(["-resetHomeFlowTest", "-seedReducedRests", "1", "-seedOpenShiftMinutes", "779"])
        XCTAssertTrue(before.staticTexts["Work Time"].waitForExistence(timeout: 5))
        XCTAssertFalse(before.descendants(matching: .any)["reducedRestCount"].exists)
        attach("work 12h59, no beds")
        before.terminate()

        // 13:30: the reduction is certain, one more bed is red than the completed count.
        let after = launch(["-resetHomeFlowTest", "-seedReducedRests", "1", "-seedOpenShiftMinutes", "810"])
        XCTAssertTrue(after.staticTexts["Work Time"].waitForExistence(timeout: 5))
        let beds = after.descendants(matching: .any)["reducedRestCount"]
        XCTAssertTrue(beds.waitForExistence(timeout: 5))
        XCTAssertEqual(beds.label, "2 of 3 reduced rests used")
        attach("work 13h30, pending bed")
        after.terminate()

        // 14:30: together with the last-hour warning (00:30 left), checked on the screenshots
        // (the warning is part of the combined gauge element, so it has no frame of its own).
        for size in ["UICTContentSizeCategoryL", "UICTContentSizeCategoryXXXL", "UICTContentSizeCategoryAccessibilityL"] {
            let warning = launch(["-resetHomeFlowTest", "-seedReducedRests", "1", "-seedOpenShiftMinutes", "870"], size: size)
            XCTAssertTrue(warning.staticTexts["Work Time"].waitForExistence(timeout: 5))
            XCTAssertTrue(warning.descendants(matching: .any)["reducedRestCount"].waitForExistence(timeout: 5))
            let gauge = warning.descendants(matching: .any)["homeGauge"]
            XCTAssertTrue(gauge.label.contains("00:30"), gauge.label)
            attach("work 14h30, pending bed and warning, \(size)")
            warning.terminate()
        }
    }

    @MainActor
    func testAccessibilityAuditWithBeds() throws {
        for (args, title) in [(["-seedReducedRests", "2", "-seedWeeklyCard"], "Weekly Rest"),
                              (["-seedReducedRests", "3"], "Rest Time"),
                              (["-seedReducedRests", "1", "-seedOpenShiftMinutes", "870"], "Work Time")] {
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

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
