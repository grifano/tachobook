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
}
