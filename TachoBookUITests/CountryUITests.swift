import XCTest

/// Figma «Flow - Country selection»: the country at shift start and close, with a stubbed location
/// (`-stubCountry`), so the system location prompt never appears in UI tests.
final class CountryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.appearance = .light
    }

    /// Poland found at the start, Germany picked from the full list at the close; both shown in the summary.
    @MainActor
    func testStartInPolandCloseInGermany() {
        let app = launch(["-stubCountry", "PL"])
        XCTAssertTrue(app.buttons["startOfDayButton"].waitForExistence(timeout: 5))

        app.buttons["startOfDayButton"].tap()
        let country = app.buttons["countryPicker"]
        XCTAssertTrue(country.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForValue(country, "Poland, PL"))
        XCTAssertEqual(app.staticTexts["countryHint"].label, "Found by your location. Tap to change.")
        attach("Country 1 start sheet, Poland found")
        confirm(app)

        app.buttons["endOfDayButton"].tap()
        XCTAssertTrue(country.waitForExistence(timeout: 5))
        country.tap()
        let allCountries = app.buttons["All countries\u{2026}"]
        XCTAssertTrue(allCountries.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["🇵🇱 Poland (PL)"].exists, "recent country in the menu")
        attach("Country 2 menu")
        allCountries.tap()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        attach("Country 4 all countries")
        search.tap()
        search.typeText("Germ")
        let germany = app.buttons["countryRow-D"]
        XCTAssertTrue(germany.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["countryRow-PL"].exists, "search filters the list")
        germany.tap()
        XCTAssertTrue(waitForValue(country, "Germany, D"))
        XCTAssertEqual(app.staticTexts["countryHint"].label, "Picked the wrong country? Tap to fix it.")
        attach("Country 5 close sheet, Germany picked")
        confirm(app)

        let alert = app.alerts["Shift closed"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Later"].tap()
        XCTAssertTrue(app.buttons["summaryDayStarted"].waitForExistence(timeout: 5))
        XCTAssertTrue(summaryLabel(app, "summaryDayStarted").hasSuffix("Poland, PL"), app.buttons["summaryDayStarted"].label)
        XCTAssertTrue(summaryLabel(app, "summaryDayClosed").hasSuffix("Germany, D"), app.buttons["summaryDayClosed"].label)
        attach("Country 6 summary")

        // Countries survive a restart.
        app.terminate()
        let relaunched = launch(["-stubCountry", "PL"], reset: false)
        XCTAssertTrue(relaunched.buttons["summaryDayClosed"].waitForExistence(timeout: 5))
        XCTAssertTrue(summaryLabel(relaunched, "summaryDayClosed").hasSuffix("Germany, D"))

        // History's day summary shows the same countries (Serhii, 13.11.2026).
        relaunched.tabBars.buttons["History"].tap()
        let today = Date().formatted(.dateTime.month(.wide).day())
        let cell = relaunched.buttons.matching(NSPredicate(format: "label CONTAINS %@", today)).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.tap()
        let started = relaunched.descendants(matching: .any)["daySummaryStarted"]
        XCTAssertTrue(started.waitForExistence(timeout: 5))
        XCTAssertTrue(started.label.hasSuffix("Poland, PL"), started.label)
        let closed = relaunched.descendants(matching: .any)["daySummaryClosed"]
        XCTAssertTrue(closed.label.hasSuffix("Germany, D"), closed.label)
        attach("Country 10 history day summary")
    }

    /// In Spain the region is required; switching to France clears it.
    @MainActor
    func testSpainNeedsARegion() {
        let app = launch(["-stubCountry", "E"])
        XCTAssertTrue(app.buttons["startOfDayButton"].waitForExistence(timeout: 5))
        app.buttons["startOfDayButton"].tap()

        let region = app.buttons["regionPicker"]
        XCTAssertTrue(region.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["countryHint"].label, "In Spain, choose the region too.")
        XCTAssertFalse(app.buttons["confirmSheetButton"].isEnabled, "no region yet")

        region.tap()
        let catalonia = app.buttons["Cataluña (CAT)"]
        XCTAssertTrue(catalonia.waitForExistence(timeout: 5))
        catalonia.tap()
        XCTAssertTrue(waitForValue(region, "Cataluña, CAT"))
        XCTAssertTrue(app.buttons["confirmSheetButton"].isEnabled)
        attach("Country 3 Spain with region")

        // Another country hides and clears the region.
        app.buttons["countryPicker"].tap()
        app.buttons["All countries\u{2026}"].tap()
        pick("France", code: "F", in: app)
        XCTAssertTrue(region.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["confirmSheetButton"].isEnabled)

        // Back to Spain: the region is asked again.
        app.buttons["countryPicker"].tap()
        app.buttons["All countries\u{2026}"].tap()
        pick("Spain", code: "E", in: app)
        XCTAssertTrue(region.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForValue(region, "Not chosen"))
        XCTAssertFalse(app.buttons["confirmSheetButton"].isEnabled)
    }

    /// No location and no earlier country: the driver must choose; an older shift without a country
    /// shows "?" and its country can be added from the summary.
    @MainActor
    func testWithoutLocationTheDriverChoosesAndOldShiftsCanBeFixed() {
        let app = launch(["-stubCountry", "none"])
        XCTAssertTrue(app.buttons["summaryDayStarted"].waitForExistence(timeout: 5))
        XCTAssertTrue(summaryLabel(app, "summaryDayStarted").hasSuffix("?"),
                      app.buttons["summaryDayStarted"].label)

        // Edit the old start: no country yet, saving the time alone is still allowed.
        app.buttons["summaryDayStarted"].tap()
        let country = app.buttons["countryPicker"]
        XCTAssertTrue(country.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["confirmSheetButton"].isEnabled)
        country.tap()
        // With nothing recent the full list opens at once.
        pick("Poland", code: "PL", in: app)
        XCTAssertTrue(waitForValue(country, "Poland, PL"))
        attach("Country 7 edit start, Poland")
        confirm(app)
        XCTAssertTrue(summaryLabel(app, "summaryDayStarted").hasSuffix("Poland, PL"))

        // A new start with no location offers the last country.
        app.buttons["startOfDayButton"].tap()
        XCTAssertTrue(country.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForValue(country, "Poland, PL"))
        XCTAssertEqual(app.staticTexts["countryHint"].label, "Same as your last shift. Tap to change.")
        attach("Start sheet without location")
        app.buttons["closeSheetButton"].tap()
    }

    /// A first start with no location and no history cannot be confirmed until a country is chosen.
    @MainActor
    func testFirstStartWithoutLocationNeedsACountry() {
        let app = XCUIApplication()
        app.launchArguments = ["-homeFlowUITest", "-resetHomeFlowTest", "-stubCountry", "none"]
        app.launch()
        XCTAssertTrue(app.buttons["startOfDayButton"].waitForExistence(timeout: 5))
        app.buttons["startOfDayButton"].tap()
        let country = app.buttons["countryPicker"]
        XCTAssertTrue(country.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["countryHint"].label, "Choose the country you\u{2019}re in.")
        XCTAssertFalse(app.buttons["confirmSheetButton"].isEnabled)
        attach("Start sheet, nothing known")
        country.tap()
        pick("Ukr", code: "UA", in: app)
        XCTAssertTrue(waitForValue(country, "Ukraine, UA"))
        XCTAssertTrue(app.buttons["confirmSheetButton"].isEnabled)
    }

    // MARK: - Helpers

    /// A weekly rest ready to end; its shift has no country (recorded before this feature).
    @MainActor
    private func launch(_ extra: [String], reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-homeFlowUITest", "-seedReadyWeeklyRest"] + (reset ? ["-resetHomeFlowTest"] : []) + extra
        app.launch()
        return app
    }

    @MainActor
    private func waitForValue(_ element: XCUIElement, _ value: String) -> Bool {
        let predicate = NSPredicate(format: "value == %@", value)
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 5) == .completed
    }

    @MainActor
    private func confirm(_ app: XCUIApplication) {
        let confirm = app.buttons["confirmSheetButton"]
        XCTAssertTrue(confirm.isEnabled)
        confirm.tap()
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5))
    }

    /// A summary column reads "Day started, 05:40, France, F"; the country is its last part.
    @MainActor
    private func summaryLabel(_ app: XCUIApplication, _ identifier: String) -> String {
        app.buttons[identifier].label
    }

    /// Searches the full list and taps the country.
    @MainActor
    private func pick(_ query: String, code: String, in app: XCUIApplication) {
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(query)
        let row = app.buttons["countryRow-\(code)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
    }

    @MainActor
    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
