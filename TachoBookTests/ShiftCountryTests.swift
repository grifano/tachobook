import Foundation
import SwiftData
import Testing
@testable import TachoBook

/// Country (and Spanish region) at shift start and close — task «P-003 — Країна при відкритті й закритті зміни».
@MainActor
struct TachoCountryCatalogTests {
    @Test func listHasTheFiftyFiveCurrentCountriesOnce() {
        #expect(TachoCountry.all.count == 55)
        #expect(Set(TachoCountry.all.map(\.code)).count == 55)
        #expect(Set(TachoCountry.all.map(\.iso)).count == 55)
    }

    @Test(arguments: [("D", "DE"), ("E", "ES"), ("EST", "EE"), ("UK", "GB"), ("FL", "LI"), ("RSM", "SM"),
                      ("V", "VA"), ("MNE", "ME"), ("SLO", "SI"), ("A", "AT"), ("PL", "PL"), ("UA", "UA")])
    func tachographCodeIsNotAlwaysISO(code: String, iso: String) throws {
        let country = try #require(TachoCountry(code: code))
        #expect(country.iso == iso)
        #expect(TachoCountry(iso: iso)?.code == code)
    }

    @Test(arguments: ["FR", "YU", "RFU", "EC", "EUR", "WLD", "DE", "ES"])
    func obsoleteGroupAndISOOnlyCodesAreNotCountries(code: String) {
        #expect(TachoCountry(code: code) == nil)
    }

    @Test func locationOutsideTheListGivesNoCountry() {
        #expect(TachoCountry(iso: "US") == nil)
        #expect(TachoCountry(iso: "fr")?.code == "F")
    }

    @Test func flagNameAndLabelsFollowFigma() throws {
        let english = Locale(identifier: "en")
        let poland = try #require(TachoCountry(code: "PL"))
        #expect(poland.flag == "🇵🇱")
        #expect(poland.listTitle(locale: english) == "🇵🇱 Poland · PL")
        #expect(poland.menuTitle(locale: english) == "🇵🇱 Poland (PL)")
        #expect(ShiftPlace(country: "F").codeLabel == "F")
        #expect(ShiftPlace(country: "E", region: "PV").codeLabel == "E\u{00B7}PV")
        #expect(ShiftPlaceLine(place: ShiftPlace(country: "E", region: "PV"), recordedAt: .now)?.text == "E\u{00B7}PV")
        #expect(ShiftPlaceLine(place: nil, recordedAt: .now)?.text == "?")
        #expect(ShiftPlaceLine(place: ShiftPlace(country: "F"), recordedAt: nil) == nil)
    }

    @Test func searchFindsByNameAndBothCodes() throws {
        let english = Locale(identifier: "en")
        let germany = try #require(TachoCountry(code: "D"))
        #expect(germany.matches("germ", locale: english))
        #expect(germany.matches("D", locale: english))
        #expect(germany.matches("de", locale: english))
        #expect(!germany.matches("Spain", locale: english))
        #expect(TachoCountry.all.filter { $0.matches("", locale: english) }.count == 55)
    }

    @Test func spainHasNineteenRegions() {
        #expect(SpainRegion.all.map(\.code) == ["AN", "AR", "AST", "C", "CAT", "CL", "CM", "CV", "EXT", "G", "IB", "IC",
                                                "LR", "M", "MU", "NA", "PV", "CE", "ME"])
    }

    @Test(arguments: [("Barcelona, Cataluña, España", "CAT"), ("Bilbao, País Vasco, España", "PV"),
                      ("Pamplona, Navarre, Spain", "NA"), ("Palma, Illes Balears, Espanya", "IB"),
                      ("Toledo, Castilla-La Mancha", "CM"), ("Valladolid\nCastilla y León", "CL"),
                      ("ALICANTE, COMUNITAT VALENCIANA", "CV")])
    func regionIsReadFromTheAddress(address: String, code: String) {
        #expect(SpainRegion.matching(address: address)?.code == code)
    }

    @Test func unknownAddressGivesNoRegion() {
        #expect(SpainRegion.matching(address: "León, España") == nil)
        #expect(SpainRegion.matching(address: "") == nil)
    }

    @Test func spainNeedsAValidRegionAndOtherCountriesNone() {
        #expect(!ShiftPlace(country: "E").isComplete)
        #expect(!ShiftPlace(country: "E", region: "XX").isComplete)
        #expect(ShiftPlace(country: "E", region: "CAT").isComplete)
        #expect(ShiftPlace(country: "F").isComplete)
        #expect(!ShiftPlace(country: "F", region: "CAT").isComplete)
        #expect(!ShiftPlace(country: "FR").isComplete)
    }
}

@MainActor
struct CountrySelectionTests {
    @Test func switchingFromSpainToFranceClearsTheRegion() {
        var selection = CountrySelection.editing(ShiftPlace(country: "E", region: "CAT"))
        selection.select(country: "F")
        #expect(selection.place == ShiftPlace(country: "F"))
        selection.select(country: "E")
        #expect(selection.place == ShiftPlace(country: "E"))
        #expect(!selection.canConfirm(required: true))
        selection.select(region: "M")
        #expect(selection.place == ShiftPlace(country: "E", region: "M"))
        #expect(selection.canConfirm(required: true))
    }

    @Test func pickingSpainAgainKeepsItsRegion() {
        var selection = CountrySelection.editing(ShiftPlace(country: "E", region: "CAT"))
        selection.select(country: "E")
        #expect(selection.place?.region == "CAT")
    }

    @Test func regionIsOnlyForSpain() {
        var selection = CountrySelection.editing(ShiftPlace(country: "PL"))
        selection.select(region: "CAT")
        #expect(selection.place == ShiftPlace(country: "PL"))
    }

    @Test func locationReplacesTheLastCountryButNotTheDriversChoice() {
        var guess = CountrySelection.newEvent(lastPlace: ShiftPlace(country: "PL"))
        #expect(guess.hint == "Same as your last shift. Tap to change.")
        guess.apply(detected: ShiftPlace(country: "D"))
        #expect(guess.place == ShiftPlace(country: "D"))
        #expect(guess.hint == "Found by your location. Tap to change.")

        var chosen = CountrySelection.newEvent(lastPlace: ShiftPlace(country: "PL"))
        chosen.select(country: "S")
        chosen.apply(detected: ShiftPlace(country: "D"))
        #expect(chosen.place == ShiftPlace(country: "S"))
    }

    @Test func noLocationAndNoHistoryMeansTheDriverMustChoose() {
        var selection = CountrySelection.newEvent(lastPlace: nil)
        selection.apply(detected: nil)
        #expect(selection.place == nil)
        #expect(selection.hint == "Choose the country you\u{2019}re in.")
        #expect(!selection.canConfirm(required: true))
        // An older record edited without a country can still be saved.
        #expect(CountrySelection.editing(nil).canConfirm(required: false))
    }

    @Test func detectedSpainKeepsItsRegionOrAsksForIt() {
        var withRegion = CountrySelection.newEvent(lastPlace: nil)
        withRegion.apply(detected: ShiftPlace(country: "E", region: "CAT"))
        #expect(withRegion.canConfirm(required: true))
        #expect(withRegion.hint == "In Spain, choose the region too.")

        var withoutRegion = CountrySelection.newEvent(lastPlace: nil)
        withoutRegion.apply(detected: ShiftPlace(country: "E"))
        #expect(!withoutRegion.canConfirm(required: true))
    }

    @Test func detectedCountryOutsideTheListIsIgnored() {
        var selection = CountrySelection.newEvent(lastPlace: ShiftPlace(country: "PL"))
        selection.apply(detected: ShiftPlace(country: "USA"))
        #expect(selection.place == ShiftPlace(country: "PL"))
    }
}

@MainActor
struct ShiftCountryModelTests {
    private let start = Date(timeIntervalSince1970: 1_791_957_600) // 2026-10-14 06:00 UTC
    private var now: Date { start.addingTimeInterval(30 * 3600) }

    @Test func startAndCloseKeepTheirOwnCountries() {
        let model = DayLogModel(date: start)
        model.startShift(at: start, now: now, place: ShiftPlace(country: "PL"))
        model.closeShift(at: start.addingTimeInterval(9 * 3600), now: now, place: ShiftPlace(country: "D"))
        #expect(model.dayStartPlace == ShiftPlace(country: "PL"))
        #expect(model.dayEndPlace == ShiftPlace(country: "D"))
        #expect(model.lastPlace == ShiftPlace(country: "D"))
        #expect(model.recentCountries().map(\.code) == ["D", "PL"])
    }

    @Test func incompleteSpainIsNotSaved() {
        let model = DayLogModel(date: start)
        model.startShift(at: start, now: now, place: ShiftPlace(country: "E"))
        #expect(model.dayStart == nil)
        model.startShift(at: start, now: now, place: ShiftPlace(country: "E", region: "AN"))
        #expect(model.dayStartPlace == ShiftPlace(country: "E", region: "AN"))
    }

    @Test func countryDoesNotChangeShiftTimes() {
        let plain = DayLogModel(date: start)
        plain.startShift(at: start, now: now)
        plain.closeShift(at: start.addingTimeInterval(9 * 3600), now: now)
        let withCountry = DayLogModel(date: start)
        withCountry.startShift(at: start, now: now, place: ShiftPlace(country: "PL"))
        withCountry.closeShift(at: start.addingTimeInterval(9 * 3600), now: now, place: ShiftPlace(country: "D"))
        #expect(plain.shiftElapsedSeconds(at: now) == withCountry.shiftElapsedSeconds(at: now))
        #expect(plain.restElapsedSeconds(at: now) == withCountry.restElapsedSeconds(at: now))
    }

    @Test func editingChangesOnlyTheCountryOfThatEvent() {
        let model = DayLogModel(date: start)
        model.startShift(at: start, now: now, place: ShiftPlace(country: "PL"))
        model.closeShift(at: start.addingTimeInterval(9 * 3600), now: now, place: ShiftPlace(country: "D"))
        model.editDayStart(start, now: now, place: ShiftPlace(country: "CZ"))
        #expect(model.dayStartPlace == ShiftPlace(country: "CZ"))
        #expect(model.dayEndPlace == ShiftPlace(country: "D"))
        model.editDayEnd(start.addingTimeInterval(9 * 3600), now: now, place: ShiftPlace(country: "E", region: "CAT"))
        #expect(model.dayEndPlace == ShiftPlace(country: "E", region: "CAT"))
        // Without a new place the stored one stays.
        model.editDayStart(start.addingTimeInterval(-600), now: now)
        #expect(model.dayStartPlace == ShiftPlace(country: "CZ"))
    }

    @Test func newShiftAfterRestStartsWithItsOwnCountry() {
        let model = DayLogModel(date: start)
        model.startShift(at: start, now: now, place: ShiftPlace(country: "PL"))
        model.closeShift(at: start.addingTimeInterval(9 * 3600), now: now, place: ShiftPlace(country: "D"))
        let next = start.addingTimeInterval(20 * 3600)
        model.startShift(at: next, now: now, place: ShiftPlace(country: "S"))
        #expect(model.dayStart == next)
        #expect(model.dayStartPlace == ShiftPlace(country: "S"))
        #expect(model.dayEndPlace == nil)
        #expect(model.archivedPeriods.last?.startPlace == ShiftPlace(country: "PL"))
        #expect(model.archivedPeriods.last?.endPlace == ShiftPlace(country: "D"))
        #expect(model.recentCountries().map(\.code) == ["S", "D", "PL"])
    }

    @Test func recentCountriesAreFourDifferentNewestFirst() {
        let model = DayLogModel(date: start)
        let codes = ["PL", "D", "PL", "S", "E", "F"]
        var time = start
        model.startShift(at: time, now: now.addingTimeInterval(400 * 3600), place: ShiftPlace(country: codes[0]))
        for (index, code) in codes.dropFirst().enumerated() {
            time = time.addingTimeInterval(8 * 3600)
            let place = code == "E" ? ShiftPlace(country: code, region: "M") : ShiftPlace(country: code)
            if index.isMultiple(of: 2) {
                model.closeShift(at: time, now: now.addingTimeInterval(400 * 3600), place: place)
            } else {
                time = time.addingTimeInterval(11 * 3600)
                model.startShift(at: time, now: now.addingTimeInterval(400 * 3600), place: place)
            }
        }
        #expect(model.recentCountries().map(\.code) == ["F", "E", "S", "PL"])
        #expect(model.recentCountries(limit: 2).map(\.code) == ["F", "E"])
    }

    @Test func resumeClearsTheCloseCountry() {
        let model = DayLogModel(date: start)
        model.startShift(at: start, now: now, place: ShiftPlace(country: "PL"))
        model.closeShift(at: start.addingTimeInterval(4 * 3600), now: now, place: ShiftPlace(country: "D"))
        model.resumeShift(at: start.addingTimeInterval(5 * 3600))
        #expect(model.dayEndPlace == nil)
        #expect(model.dayStartPlace == ShiftPlace(country: "PL"))
    }
}

@MainActor
struct ShiftCountryPersistenceTests {
    private let start = Date(timeIntervalSince1970: 1_791_957_600)

    private func withDisk(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "swiftdata-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory.appending(path: "shifts.store"))
    }

    private func withModel<T>(_ url: URL, _ body: (DayLogModel) throws -> T) rethrows -> T {
        try autoreleasepool { try body(DayLogModel(storageURL: url)) }
    }

    @Test func countriesSurviveARestart() throws {
        try withDisk { url in
            withModel(url) { model in
                model.startShift(at: start, now: start, place: ShiftPlace(country: "E", region: "CAT"))
                model.closeShift(at: start.addingTimeInterval(9 * 3600), now: start.addingTimeInterval(9 * 3600),
                                 place: ShiftPlace(country: "F"))
            }
            try withModel(url) { model in
                try #require(model.storageError == nil)
                #expect(model.dayStartPlace == ShiftPlace(country: "E", region: "CAT"))
                #expect(model.dayEndPlace == ShiftPlace(country: "F"))
                #expect(model.recentCountries().map(\.code) == ["F", "E"])
            }
        }
    }

    /// A store written before countries existed (schema V2) opens with every shift "not recorded".
    @Test func shiftsSavedBeforeCountriesOpenWithoutOne() throws {
        try withDisk { url in
            let period = DutyPeriod(date: start, start: start, drivingMinutes: 90, end: start.addingTimeInterval(9 * 3600),
                                    isClosed: true, rests: [RestSegment(start: start.addingTimeInterval(9 * 3600))])
            try autoreleasepool {
                let schema = Schema(versionedSchema: ShiftSchemaV2.self)
                let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
                let container = try ModelContainer(for: schema, configurations: [configuration])
                let context = ModelContext(container)
                context.insert(ShiftSchemaV1.Period(period: period, isCurrent: true, archiveOrder: 0,
                                                    restData: try JSONEncoder().encode(period.rests)))
                try context.save()
            }
            try withModel(url) { model in
                try #require(model.storageError == nil)
                #expect(model.dutyID == period.id)
                #expect(model.dayStart == start)
                #expect(model.dayStartPlace == nil)
                #expect(model.dayEndPlace == nil)
                #expect(model.lastPlace == nil)
                #expect(model.recentCountries().isEmpty)
                #expect(ShiftPlaceLine(place: model.dayStartPlace, recordedAt: model.dayStart)?.text == "?")
                // A country can be added to the old record.
                model.editDayStart(start, now: start.addingTimeInterval(20 * 3600), place: ShiftPlace(country: "PL"))
            }
            withModel(url) { model in
                #expect(model.dayStartPlace == ShiftPlace(country: "PL"))
                #expect(model.dayEndPlace == nil)
            }
        }
    }

    /// The JSON journal from before SwiftData has no country keys either.
    @Test func legacyJournalWithoutCountriesDecodes() throws {
        let json = #"{"current":{"id":"\#(UUID().uuidString)","calendarZone":"UTC","date":0,"start":0,"isClosed":false,"rests":[]},"history":[]}"#
        let journal = try JSONDecoder().decode(ShiftJournal.self, from: Data(json.utf8))
        #expect(journal.current.startPlace == nil)
        #expect(journal.current.endPlace == nil)
    }
}
