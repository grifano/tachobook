//
//  DayLogModelTests.swift
//  TachoBookTests
//

import Foundation
import Testing
@testable import TachoBook

struct DayLogModelTests {

    @Test func testInitialEmptyDay() {
        let model = DayLogModel()
        #expect(model.dayStart == nil)
        #expect(model.drivingMinutes == nil)
        #expect(model.dayEnd == nil)
        #expect(model.workingMinutes == nil)
        #expect(model.workingTimeString == "0:00")
        #expect(model.restTimeString == "0:00")
        #expect(model.canCloseDay == false)
        #expect(model.isDayClosed == false)
    }

    @Test func testSettingDayStart() {
        let model = DayLogModel()
        let calendar = Calendar.current
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 4
        comps.day = 20
        comps.hour = 6
        comps.minute = 30
        let startDate = calendar.date(from: comps)!

        model.setDayStart(startDate)

        #expect(model.dayStart != nil)
        #expect(model.dayStartDisplayString == startDate.formatted(date: .omitted, time: .shortened))
        #expect(model.canCloseDay == false)
        // With start logged, preliminary working time can show initial progress or 0:10
        #expect(model.workingTimeString == "0:10")
    }

    @Test func testSettingDrivingDuration() {
        let model = DayLogModel()
        model.setDrivingMinutes(9 * 60 + 30) // 9h30 = 570 mins

        #expect(model.drivingMinutes == 570)
        #expect(model.drivingDisplayString == "9H30M")
        #expect(model.drivingInputString == "9h30")
        #expect(model.canCloseDay == false)
    }

    @Test func testSettingDayEndAndDerivingWorkingTime() {
        let model = DayLogModel()
        let calendar = Calendar.current

        var startComps = DateComponents()
        startComps.year = 2026
        startComps.month = 4
        startComps.day = 20
        startComps.hour = 6
        startComps.minute = 30
        let startDate = calendar.date(from: startComps)!

        var endComps = DateComponents()
        endComps.year = 2026
        endComps.month = 4
        endComps.day = 20
        endComps.hour = 20
        endComps.minute = 30
        let endDate = calendar.date(from: endComps)!

        model.setDayStart(startDate)
        model.setDrivingMinutes(570)
        model.setDayEnd(endDate)

        #expect(model.dayEnd != nil)
        #expect(model.dayEndDisplayString == endDate.formatted(date: .omitted, time: .shortened))
        #expect(model.workingMinutes == 14 * 60) // 14 hours = 840 mins
        #expect(model.workingTimeString == "14:00")
        #expect(model.restTimeString == "0:20")
        #expect(model.canCloseDay == true)
    }

    @Test func testClosingAndReopeningDay() {
        let model = DayLogModel()
        let calendar = Calendar.current

        var startComps = DateComponents()
        startComps.year = 2026
        startComps.month = 4
        startComps.day = 20
        startComps.hour = 6
        startComps.minute = 30
        model.setDayStart(calendar.date(from: startComps)!)
        model.setDrivingMinutes(570)

        var endComps = DateComponents()
        endComps.year = 2026
        endComps.month = 4
        endComps.day = 20
        endComps.hour = 20
        endComps.minute = 30
        model.setDayEnd(calendar.date(from: endComps)!)

        #expect(model.canCloseDay == true)
        #expect(model.isDayClosed == false)

        model.closeDay()
        #expect(model.isDayClosed == true)

        model.reopenDay()
        #expect(model.isDayClosed == true) // still completed state
    }

    @Test func testDeletingEntry() {
        let model = DayLogModel()
        let calendar = Calendar.current

        var startComps = DateComponents()
        startComps.year = 2026
        startComps.month = 4
        startComps.day = 20
        startComps.hour = 6
        startComps.minute = 30
        model.setDayStart(calendar.date(from: startComps)!)
        model.setDrivingMinutes(570)

        var endComps = DateComponents()
        endComps.year = 2026
        endComps.month = 4
        endComps.day = 20
        endComps.hour = 20
        endComps.minute = 30
        model.setDayEnd(calendar.date(from: endComps)!)

        #expect(model.canCloseDay == true)

        model.deleteEntry(.dayEnd)
        #expect(model.dayEnd == nil)
        #expect(model.canCloseDay == false)
        #expect(model.workingMinutes == nil)
    }

    // MARK: - Live shift duration

    private func date(_ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 4; c.day = day
        c.hour = hour; c.minute = minute; c.second = second
        return Calendar.current.date(from: c)!
    }

    @Test func testNoShiftHasNoElapsedDuration() {
        let model = DayLogModel()
        #expect(model.isShiftOpen == false)
        #expect(model.shiftElapsedSeconds(at: date(20, 12, 0)) == nil)
        #expect(model.shiftDurationString(at: date(20, 12, 0)) == "0:00")
    }

    @Test func testOpenShiftShowsElapsedHoursMinutesSeconds() {
        let model = DayLogModel()
        model.setDayStart(date(20, 6, 30))
        let now = date(20, 13, 35, 9)

        #expect(model.isShiftOpen)
        #expect(model.shiftElapsedSeconds(at: now) == 7 * 3600 + 5 * 60 + 9)
        #expect(model.shiftDurationString(at: now) == "7:05")
        #expect(model.shiftSecondsString(at: now) == "09s")
    }

    @Test func testElapsedDurationAdvancesFromTimestampsAfterLongBackground() {
        let model = DayLogModel()
        model.setDayStart(date(20, 6, 30))
        // Same model, queried much later: no accumulated counter involved.
        #expect(model.shiftDurationString(at: date(20, 6, 31, 5)) == "0:01")
        #expect(model.shiftDurationString(at: date(20, 18, 0)) == "11:30")
    }

    @Test func testDurationAcrossMidnightAndBeyond24Hours() {
        let model = DayLogModel()
        model.setDayStart(date(20, 22, 0))

        #expect(model.shiftDurationString(at: date(21, 2, 15)) == "4:15")
        #expect(model.shiftDurationString(at: date(21, 23, 0)) == "25:00")
    }

    @Test func testDurationFreezesWhenShiftEnds() {
        let model = DayLogModel()
        model.setDayStart(date(20, 6, 30))
        model.setDayEnd(date(20, 14, 0))

        #expect(model.isShiftOpen == false)
        #expect(model.shiftDurationString(at: date(20, 14, 0)) == "7:30")
        #expect(model.shiftDurationString(at: date(22, 9, 0)) == "7:30")
        #expect(model.shiftSecondsString(at: date(22, 9, 0)) == "00s")
    }

    @Test func testStartInFutureClampsToZero() {
        let model = DayLogModel()
        model.setDayStart(date(20, 10, 0))
        #expect(model.shiftElapsedSeconds(at: date(20, 9, 0)) == 0)
    }
}
