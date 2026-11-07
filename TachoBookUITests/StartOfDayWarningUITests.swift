import XCTest

/// Start of day at 3 of 3 without a split (owner decisions 01.11 and 02.11.2026): dimmed with a countdown to 11 h,
/// a warning from 9 h that never blocks, orange at 11 h. No Figma frame: existing styles and a system alert.
final class StartOfDayWarningUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.appearance = .light
    }

    @MainActor
    func testEarlyStartWarnsAndStillStartsTheShift() {
        let app = launch(["-resetHomeFlowTest", "-seedReducedRests", "3", "-seedRestMinutes", "570"])
        XCTAssertTrue(app.staticTexts["Rest Time"].waitForExistence(timeout: 5))
        let startOfDay = app.buttons["startOfDayButton"]
        XCTAssertTrue(startOfDay.isEnabled)
        XCTAssertTrue(startOfDay.label.contains("Available in 01:30") || startOfDay.label.contains("Available in 01:29"),
                      startOfDay.label)
        attach("3 of 3 rest 9h30, countdown to 11h")

        // Keep resting: nothing changes.
        startOfDay.tap()
        let alert = app.alerts["All 3 reduced rests used"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let message = alert.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH %@ AND label ENDSWITH %@",
            "Starting now breaks the rest rules. Rest until ", " for the full 11 hours.")).firstMatch
        XCTAssertTrue(message.exists, alert.debugDescription)
        XCTAssertTrue(alert.buttons["Keep resting"].exists)
        XCTAssertTrue(alert.buttons["Start anyway"].exists)
        attach("3 of 3 early start warning")
        alert.buttons["Keep resting"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["confirmSheetButton"].exists)
        XCTAssertTrue(app.staticTexts["Rest Time"].exists)
        XCTAssertTrue(startOfDay.label.contains("Available in"))

        // Start anyway: the usual sheet; Confirm starts and saves the shift.
        startOfDay.tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Start anyway"].tap()
        let confirm = app.buttons["confirmSheetButton"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        attach("start sheet after Start anyway")
        confirm.tap()
        XCTAssertTrue(app.buttons["endOfDayButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Work Time"].exists)

        app.terminate()
        let relaunched = launch([])
        XCTAssertTrue(relaunched.buttons["endOfDayButton"].waitForExistence(timeout: 5), "the started shift is saved")
    }

    @MainActor
    func testBeforeNineHoursStaysDisabled() {
        let app = launch(["-resetHomeFlowTest", "-seedReducedRests", "3", "-seedRestMinutes", "480"])
        XCTAssertTrue(app.staticTexts["Rest Time"].waitForExistence(timeout: 5))
        let startOfDay = app.buttons["startOfDayButton"]
        XCTAssertFalse(startOfDay.isEnabled)
        XCTAssertTrue(startOfDay.label.contains("Available in 03:00") || startOfDay.label.contains("Available in 02:59"),
                      startOfDay.label)
        attach("3 of 3 rest 8h, disabled")
    }

    @MainActor
    func testAtElevenHoursStartsWithoutWarning() {
        let app = launch(["-resetHomeFlowTest", "-seedReducedRests", "3", "-seedRestMinutes", "661"])
        // Past 11 h a daily rest shows as weekly (R-W01).
        XCTAssertTrue(app.staticTexts["Weekly Rest"].waitForExistence(timeout: 5))
        let startOfDay = app.buttons["startOfDayButton"]
        XCTAssertTrue(startOfDay.isEnabled)
        XCTAssertFalse(startOfDay.label.contains("Available in"), startOfDay.label)
        attach("3 of 3 rest 11h, orange")
        startOfDay.tap()
        XCTAssertTrue(app.buttons["confirmSheetButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    @MainActor
    func testTwoOfThreeStartsAtNineHoursWithoutWarning() {
        let app = launch(["-resetHomeFlowTest", "-seedReducedRests", "2", "-seedRestMinutes", "570"])
        XCTAssertTrue(app.staticTexts["Rest Time"].waitForExistence(timeout: 5))
        let startOfDay = app.buttons["startOfDayButton"]
        XCTAssertTrue(startOfDay.isEnabled)
        XCTAssertFalse(startOfDay.label.contains("Available in"), startOfDay.label)
        startOfDay.tap()
        XCTAssertTrue(app.buttons["confirmSheetButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    /// The Home states with the dimmed button. The alert itself is the system `UIAlertController`: the audit reports
    /// the same Dynamic Type and text findings for it as for the existing "Shift closed" alert, so it is not audited.
    @MainActor
    func testAccessibilityAuditOfEarlyStart() throws {
        continueAfterFailure = true // report every state's findings in one run
        for minutes in ["480", "570"] {
            let app = launch(["-resetHomeFlowTest", "-seedReducedRests", "3", "-seedRestMinutes", minutes])
            XCTAssertTrue(app.staticTexts["Rest Time"].waitForExistence(timeout: 5))
            try audit(app, "3 of 3 rest \(minutes) min")
            app.terminate()
        }
    }

    // MARK: - Helpers

    @MainActor
    private func audit(_ app: XCUIApplication, _ state: String) throws {
        var issues: [String] = []
        try app.performAccessibilityAudit { issue in
            // Temporary, see AccessibilityAuditSupport: the dimmed tabs lack the "not enabled" trait.
            if issue.isNotEnabledTraitOnADisabledTab { return true }
            issues.append("\(issue.compactDescription): \(issue.element?.label ?? "unnamed node")")
            return true
        }
        print("AUDIT \(state): \(issues.isEmpty ? "clean" : issues.joined(separator: "; "))")
        XCTAssertTrue(issues.isEmpty, "\(state): \(issues.joined(separator: "; "))")
    }

    @MainActor
    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-homeFlowUITest", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"] + extra
        app.launch()
        return app
    }

    @MainActor
    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
