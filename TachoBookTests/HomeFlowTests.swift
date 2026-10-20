import Foundation
import Testing
@testable import TachoBook

/// Task acceptance scenarios for Home (Figma "Flow 1 - Log Day Shift"), in Europe/Berlin.
@MainActor
struct HomeFlowTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func label(_ date: Date, now: Date) -> String {
        HomeTimeline.clockLabel(date, relativeTo: now, calendar: calendar)
    }

    private func seeded() -> DayLogModel {
        let model = DayLogModel()
        model.seedFigmaSampleIfEmpty(calendar: calendar)
        return model
    }

    // MARK: - Seeded weekly rest (frame 01)

    @Test func seededWeeklyRestShowsMilestonesElapsedAndCountdown() throws {
        let model = seeded()
        let restStart = try #require(model.currentRestStart)
        #expect(model.restKind == .weekly)
        #expect(model.dayStart == date(17, 5, 40))
        #expect(restStart == date(17, 8, 34))
        #expect(HomeTimeline.drivingLabel(minutes: model.drivingMinutes) == "02h08m")

        let milestones = HomeTimeline.restMilestones(restStart: restStart, kind: model.restKind)
        #expect(milestones.first == date(18, 8, 34))
        #expect(milestones.second == date(19, 5, 34))
        let saturday = date(17, 8, 34)
        #expect(label(milestones.first, now: saturday) == "08:34 Su")
        #expect(label(milestones.second, now: saturday) == "05:34 Mo")

        let sundayNoon = date(18, 11, 53)
        #expect(HomeTimeline.clockDuration(seconds: HomeTimeline.elapsedSeconds(from: restStart, to: sundayNoon)) == "27:19")
        #expect(HomeTimeline.availabilityCountdown(restStart: restStart, kind: .weekly, now: sundayNoon) == "17:41")
        #expect(HomeTimeline.availabilityCountdown(restStart: restStart, kind: .weekly, now: date(19, 5, 34)) == nil)
    }

    @Test func startOfDayStaysUnavailableUntilTheRequiredMilestone() {
        let model = seeded()
        #expect(!model.canStartShift(at: date(19, 5, 33), now: date(19, 5, 33)))
        #expect(model.canStartShift(at: date(19, 5, 34), now: date(19, 5, 34)))
        #expect(!model.canStartShift(at: date(19, 6, 0), now: date(19, 5, 40)), "a future start cannot be confirmed")
        model.startShift(at: date(19, 5, 33), now: date(19, 5, 40))
        #expect(model.isResting)
    }

    @Test func seedIsOptInAndNeverReplacesStoredData() {
        let model = DayLogModel()
        model.setDayStart(date(18, 6, 0))
        model.seedFigmaSampleIfEmpty(calendar: calendar)
        #expect(model.dayStart == date(18, 6, 0))
        #expect(!model.isResting)
    }

    // MARK: - Shift and daily rest (frames 02–08)

    @Test func startedShiftShowsDutyMarkersFromTheEnteredStart() throws {
        let model = seeded()
        model.startShift(at: date(19, 5, 40), now: date(19, 5, 45))
        let start = try #require(model.dayStart)
        #expect(start == date(19, 5, 40))
        #expect(model.isShiftOpen)
        #expect(model.archivedPeriods.count == 1)
        #expect(model.archivedPeriods[0].rests[0].end == start)

        let now = date(19, 5, 50)
        #expect(model.shiftElapsedSeconds(at: now) == 600)
        let markers = HomeTimeline.dutyMarkers(shiftStart: start)
        #expect(label(markers.first, now: now) == "18:40")
        #expect(label(markers.second, now: now) == "20:40")
    }

    @Test func closingAtTwentyTwoTwentyFiveStartsADailyRestWithNextDayMilestones() throws {
        let model = seeded()
        model.startShift(at: date(19, 5, 40), now: date(19, 5, 40))
        #expect(!model.canCloseShift(at: date(19, 5, 39), now: date(19, 22, 30)), "end before start")
        model.closeShift(at: date(19, 22, 25), now: date(19, 22, 30))

        let restStart = try #require(model.currentRestStart)
        #expect(model.restKind == .daily)
        #expect(model.dayEnd == date(19, 22, 25))
        #expect(model.drivingMinutes == nil)
        #expect(HomeTimeline.drivingLabel(minutes: model.drivingMinutes) == "?")
        let milestones = HomeTimeline.restMilestones(restStart: restStart, kind: .daily)
        #expect(label(milestones.first, now: date(19, 22, 26)) == "07:25 Tu")
        #expect(label(milestones.second, now: date(19, 22, 26)) == "09:25 Tu")
        #expect(HomeTimeline.availabilityCountdown(restStart: restStart, kind: .daily, now: date(19, 22, 26)) == "08:59")

        model.setDrivingMinutes(9 * 60 + 52)
        #expect(HomeTimeline.drivingLabel(minutes: model.drivingMinutes) == "09h52m")
        #expect(model.canStartShift(at: date(20, 7, 25), now: date(20, 7, 25)))
    }

    @Test(arguments: [(14 * 60 + 45, true, "00:15"), (14 * 60, true, "01:00"), (13 * 60 + 59, false, "01:01"), (16 * 60, true, "00:00")])
    func dutyWarningAppearsInTheLastHourBeforeFifteenHours(elapsedMinutes: Int, warns: Bool, remaining: String) {
        let start = date(19, 5, 40)
        let now = start.addingTimeInterval(TimeInterval(elapsedMinutes * 60))
        #expect(HomeTimeline.isDutyWarning(shiftStart: start, at: now) == warns)
        #expect(HomeTimeline.remainingDuration(seconds: HomeTimeline.dutyRemainingSeconds(shiftStart: start, at: now)) == remaining)
        #expect(HomeTimeline.dutyWarningThreshold == 3600)
    }

    @Test func remainingTimeRoundsUpSoItComplementsElapsedTime() {
        let start = date(19, 5, 40)
        let now = start.addingTimeInterval(14 * 3600 + 45 * 60 + 30)
        #expect(HomeTimeline.clockDuration(seconds: HomeTimeline.elapsedSeconds(from: start, to: now)) == "14:45")
        #expect(HomeTimeline.remainingDuration(seconds: HomeTimeline.dutyRemainingSeconds(shiftStart: start, at: now)) == "00:15")
        #expect(HomeTimeline.availabilityCountdown(restStart: start, kind: .daily, now: start.addingTimeInterval(90)) == "08:59")
        #expect(HomeTimeline.remainingDuration(seconds: 0) == "00:00")
    }

    @Test func restMilestonesUseElapsedSecondsAcrossTheDSTChange() {
        // V28: 24.10.2026 22:00 CEST + 9 h = 25.10 06:00 CET.
        let restStart = date(24, 22, 0)
        let milestones = HomeTimeline.restMilestones(restStart: restStart, kind: .daily)
        #expect(label(milestones.first, now: restStart) == "06:00 Su")
        #expect(label(milestones.second, now: restStart) == "08:00 Su")
        #expect(HomeTimeline.clockDuration(seconds: 98_340) == "27:19")
    }

    // MARK: - Header (review round 2)

    @Test func headerShowsTheDateWithoutTime() {
        var british = calendar
        british.locale = Locale(identifier: "en_GB")
        #expect(HomeTimeline.headerDate(date(18, 14, 52), calendar: british) == "18 October 2026")
    }

    @Test func todayInTheWeekStripMovesAtLocalMidnight() throws {
        let beforeMidnight = date(18, 23, 59).addingTimeInterval(59)
        let afterMidnight = date(19, 0, 0)
        let before = HomeTimeline.dateStrip(today: beforeMidnight, calendar: calendar)
        let after = HomeTimeline.dateStrip(today: afterMidnight, calendar: calendar)
        // maxDaysBack (3) days before today, today and tomorrow: the strip never re-centres.
        #expect(before.map(\.offset) == [-3, -2, -1, 0, 1])
        #expect(before.filter(\.isToday).map(\.date) == [date(18, 0, 0)])
        #expect(after.filter(\.isToday).map(\.date) == [date(19, 0, 0)])
        #expect(before.first?.date == date(15, 0, 0))
        #expect(after.first?.date == date(16, 0, 0))
        #expect(after.last?.date == date(20, 0, 0))
    }

    @Test func theStripLayoutFollowsTheHistoryDepth() {
        let now = date(18, 12, 0)
        #expect(DayHistory.maxDaysBack == 3)
        #expect(HomeTimeline.dateStrip(today: now, calendar: calendar).map(\.offset) == [-3, -2, -1, 0, 1])
        #expect(HomeTimeline.dateStrip(today: now, daysBack: 2, calendar: calendar).map(\.offset) == [-2, -1, 0, 1, 2])
        #expect(HomeTimeline.dateStrip(today: now, daysBack: 4, calendar: calendar).map(\.offset) == [-4, -3, -2, -1, 0])
        #expect(HomeTimeline.dateStrip(today: now, daysBack: 9, calendar: calendar).count == 5, "never wider than the strip")
    }

    // MARK: - Daily rest shown as weekly from 11 h (review round 3)

    @Test func dailyRestIsShownAsWeeklyFromElevenHours() {
        let restStart = date(19, 22, 25)
        let justBefore = restStart.addingTimeInterval(11 * 3600 - 1)
        let atEleven = restStart.addingTimeInterval(11 * 3600)
        #expect(HomeTimeline.displayedRestKind(stored: .daily, restStart: restStart, now: justBefore) == .daily)
        #expect(HomeTimeline.displayedRestKind(stored: .daily, restStart: restStart, now: atEleven) == .weekly)
        #expect(HomeTimeline.displayedRestKind(stored: .weekly, restStart: restStart, now: restStart) == .weekly)
    }

    @Test func closedAtTwentyTwoTwentyFiveSwitchesCardsAtNineTwentyFive() throws {
        let model = seeded()
        model.startShift(at: date(19, 5, 40), now: date(19, 5, 40))
        model.closeShift(at: date(19, 22, 25), now: date(19, 22, 30))
        let restStart = try #require(model.currentRestStart)

        let at0924 = date(20, 9, 24)
        let daily = HomeTimeline.displayedRestKind(stored: model.restKind, restStart: restStart, now: at0924)
        #expect(daily == .daily)
        let dailyMilestones = HomeTimeline.restMilestones(restStart: restStart, kind: daily)
        #expect(label(dailyMilestones.first, now: at0924) == "07:25")
        #expect(label(dailyMilestones.second, now: at0924) == "09:25")

        let at0925 = date(20, 9, 25)
        let weekly = HomeTimeline.displayedRestKind(stored: model.restKind, restStart: restStart, now: at0925)
        #expect(weekly == .weekly)
        #expect(weekly.requiredHours == 45)
        let weeklyMilestones = HomeTimeline.restMilestones(restStart: restStart, kind: weekly)
        #expect(label(weeklyMilestones.first, now: at0925) == "22:25")
        #expect(label(weeklyMilestones.second, now: at0925) == "19:25 We")

        // The stored kind stays daily: Start of day is available from 9 h and after the switch.
        #expect(model.restKind == .daily)
        #expect(HomeTimeline.availabilityCountdown(restStart: restStart, kind: model.restKind, now: date(20, 7, 24)) != nil)
        for now in [date(20, 7, 25), at0925, date(21, 12, 0)] {
            #expect(HomeTimeline.availabilityCountdown(restStart: restStart, kind: model.restKind, now: now) == nil)
            #expect(model.canStartShift(at: now, now: now))
        }
    }

    @Test func displayedKindIsDerivedAfterRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "home-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "shifts.store")
        autoreleasepool {
            let model = DayLogModel(storageURL: url)
            model.setDayStart(date(19, 5, 40))
            model.closeShift(at: date(19, 22, 25), now: date(19, 22, 30))
        }
        let reloaded = DayLogModel(storageURL: url)
        let restStart = try #require(reloaded.currentRestStart)
        #expect(reloaded.restKind == .daily)
        #expect(HomeTimeline.displayedRestKind(stored: reloaded.restKind, restStart: restStart, now: date(20, 9, 24)) == .daily)
        #expect(HomeTimeline.displayedRestKind(stored: reloaded.restKind, restStart: restStart, now: date(20, 9, 25)) == .weekly)
    }

    // MARK: - Editing the summary (R-E01)

    @Test func editingDayStartedMovesMarkersAndKeepsThePreviousRestLinked() throws {
        let model = seeded()
        model.startShift(at: date(19, 5, 40), now: date(19, 5, 40))
        model.closeShift(at: date(19, 22, 25), now: date(19, 22, 30))

        #expect(model.canEditDayStart(date(19, 5, 0), now: date(19, 22, 30)))
        model.editDayStart(date(19, 5, 0), now: date(19, 22, 30))
        let start = try #require(model.dayStart)
        let markers = HomeTimeline.dutyMarkers(shiftStart: start)
        #expect(label(markers.first, now: start) == "18:00")
        #expect(label(markers.second, now: start) == "20:00")
        #expect(model.archivedPeriods[0].rests[0].end == date(19, 5, 0))
        #expect(model.shiftElapsedSeconds(at: date(20, 1, 0)) == 17 * 3600 + 25 * 60)

        #expect(!model.canEditDayStart(date(19, 22, 26), now: date(19, 22, 30)), "start after the close")
        #expect(!model.canEditDayStart(date(17, 8, 0), now: date(19, 22, 30)), "overlaps the previous shift")
        #expect(!model.canEditDayStart(date(19, 23, 0), now: date(19, 22, 30)), "future")
    }

    @Test func editingDayClosedMovesTheRunningRestAndItsMilestones() throws {
        let model = seeded()
        model.startShift(at: date(19, 5, 40), now: date(19, 5, 40))
        model.closeShift(at: date(19, 22, 25), now: date(19, 22, 30))

        #expect(!model.canEditDayEnd(date(19, 5, 30), now: date(19, 23, 0)), "end before start")
        #expect(!model.canEditDayEnd(date(19, 23, 30), now: date(19, 23, 0)), "future")
        model.editDayEnd(date(19, 21, 0), now: date(19, 23, 0))
        let restStart = try #require(model.currentRestStart)
        #expect(model.dayEnd == date(19, 21, 0))
        #expect(restStart == date(19, 21, 0))
        let milestones = HomeTimeline.restMilestones(restStart: restStart, kind: .daily)
        #expect(label(milestones.first, now: restStart) == "06:00 Tu")
        #expect(model.shiftElapsedSeconds(at: date(19, 23, 0)) == 15 * 3600 + 20 * 60)
    }

    @Test func editingTheSeededLastShiftAppliesToTheClosedShift() {
        let model = seeded()
        model.editDayStart(date(17, 5, 0), now: date(18, 12, 0))
        model.editDayEnd(date(17, 9, 0), now: date(18, 12, 0))
        model.setDrivingMinutes(150)
        #expect(model.dayStart == date(17, 5, 0))
        #expect(model.currentRestStart == date(17, 9, 0))
        #expect(model.restKind == .weekly)
        #expect(model.drivingMinutes == 150)
    }

    // MARK: - Persistence

    @Test func flowAndEditsSurviveRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "home-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "shifts.store")
        autoreleasepool {
            let model = DayLogModel(storageURL: url)
            model.seedFigmaSampleIfEmpty(calendar: calendar)
            model.startShift(at: date(19, 5, 40), now: date(19, 5, 40))
            model.closeShift(at: date(19, 22, 25), now: date(19, 22, 30))
            model.editDayStart(date(19, 5, 0), now: date(19, 22, 30))
            model.setDrivingMinutes(592)
        }
        let reloaded = DayLogModel(storageURL: url)
        try #require(reloaded.storageError == nil)
        #expect(reloaded.dayStart == date(19, 5, 0))
        #expect(reloaded.dayEnd == date(19, 22, 25))
        #expect(reloaded.drivingMinutes == 592)
        #expect(reloaded.restKind == .daily)
        #expect(reloaded.archivedPeriods.first?.rests.first?.kind == .weekly)
        #expect(reloaded.archivedPeriods.first?.rests.first?.end == date(19, 5, 0))
    }

    @Test func legacyRestSegmentsWithoutKindDecodeAsDaily() throws {
        let json = Data(#"[{"id":"7B1F4C2E-8C1A-4D7E-9E43-1D7D2B3C4A5F","start":800000000}]"#.utf8)
        let rests = try JSONDecoder().decode([RestSegment].self, from: json)
        #expect(rests.first?.kind == nil)
        let model = DayLogModel()
        model.setDayStart(Date(timeIntervalSinceReferenceDate: 790_000_000))
        model.closeShift(at: Date(timeIntervalSinceReferenceDate: 800_000_000))
        #expect(model.restKind == .daily)
    }
}

@MainActor
struct DrivingEntryTests {
    @Test func prefilledValueIsReplacedByTheFirstKey() {
        var entry = DrivingEntry(minutes: 128)
        #expect(entry.display == "2h08")
        #expect(entry.minutes == 128)
        for digit in ["9", "5", "2"] { entry.append(digit) }
        #expect(entry.display == "9h52")
        #expect(entry.minutes == 592)
    }

    @Test func missingValueStartsEmptyAndCannotBeConfirmed() {
        var entry = DrivingEntry(minutes: nil)
        #expect(entry.minutes == nil)
        #expect(entry.display == "0h00")
        entry.append("0")
        entry.append("5")
        #expect(entry.minutes == 5)
    }

    @Test func minutesAboveFiftyNineCannotBeConfirmed() {
        var entry = DrivingEntry(minutes: nil)
        for digit in ["9", "5", "2", "5", "2"] { entry.append(digit) }
        #expect(entry.display == "95h25")
        entry.deleteLast()
        entry.deleteLast()
        #expect(entry.display == "0h95")
        #expect(entry.minutes == nil)
    }
}
