import Foundation
import Testing
@testable import TachoBook

@MainActor
struct LiveShiftTimerTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func elapsedUsesOriginalInstantAcrossMidnightAndLongIntervals() {
        let model = DayLogModel()
        model.setDayStart(start)
        #expect(model.shiftElapsedSeconds(at: start.addingTimeInterval(30 * 3600 + 61)) == 108061)
        #expect(model.shiftDurationString(at: start.addingTimeInterval(108061)) == "30:01")
        #expect(model.shiftSecondsString(at: start.addingTimeInterval(108061)) == "01")
        #expect(model.shiftElapsedSeconds(at: start.addingTimeInterval(-1)) == 0)
    }

    @Test(arguments: ["2026-03-28T22:00:00+01:00", "2026-10-24T22:00:00+02:00"])
    func dstDoesNotChangeElapsed(iso: String) throws {
        let instant = try #require(ISO8601DateFormatter().date(from: iso))
        let model = DayLogModel()
        model.setDayStart(instant)
        #expect(model.shiftElapsedSeconds(at: instant.addingTimeInterval(9 * 3600)) == 32400)
    }

    @Test func closeResumeAndSecondCloseKeepDutyAndAllEntries() {
        let model = DayLogModel()
        model.setDayStart(start)
        model.setDrivingMinutes(120)
        let id = model.dutyID
        model.setDayEnd(start.addingTimeInterval(4 * 3600))
        model.closeDay()
        model.closeDay()
        #expect(model.restSegments.count == 1)
        #expect(model.shiftElapsedSeconds(at: start.addingTimeInterval(7 * 3600)) == 14400)
        #expect(model.restElapsedSeconds(at: start.addingTimeInterval(7 * 3600)) == 10800)
        model.resumeShift(at: start.addingTimeInterval(7 * 3600))
        #expect(model.dutyID == id)
        #expect(model.dayStart == start)
        #expect(model.drivingMinutes == 120)
        #expect(model.restSegments[0].end == start.addingTimeInterval(7 * 3600))
        #expect(model.shiftElapsedSeconds(at: start.addingTimeInterval(8 * 3600)) == 28800)
        model.setDayEnd(start.addingTimeInterval(8 * 3600))
        model.closeDay()
        #expect(model.restSegments.count == 2)
        #expect(model.restElapsedSeconds(at: start.addingTimeInterval(9 * 3600)) == 3600)
    }

    @Test func restartRestoresActiveAndRestingStateAndArchivesNewShift() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "shift-\(UUID()).store")
        defer { try? FileManager.default.removeItem(at: url) }
        let model = DayLogModel(storageURL: url)
        model.setDayStart(start)
        model.setDrivingMinutes(240)
        let active = DayLogModel(storageURL: url)
        #expect(active.shiftElapsedSeconds(at: start.addingTimeInterval(3601)) == 3601)
        active.setDayEnd(start.addingTimeInterval(5 * 3600))
        active.closeDay()
        let restored = DayLogModel(storageURL: url)
        #expect(restored.isResting)
        #expect(restored.restSegments.first?.id == active.restSegments.first?.id)
        #expect(restored.restElapsedSeconds(at: start.addingTimeInterval(6 * 3600)) == 3600)
        restored.startNewShift(at: start.addingTimeInterval(16 * 3600), dailyRestConfirmed: false)
        #expect(restored.dutyID == active.dutyID)
        restored.startNewShift(at: start.addingTimeInterval(16 * 3600), dailyRestConfirmed: true)
        let new = DayLogModel(storageURL: url)
        #expect(new.dutyID != active.dutyID)
        #expect(new.archivedPeriods.count == 1)
        #expect(new.archivedPeriods[0].drivingMinutes == 240)
        #expect(new.archivedPeriods[0].rests[0].dailyRestConfirmed == true)
        #expect(new.archivedPeriods[0].rests[0].end == start.addingTimeInterval(16 * 3600))
    }

    @Test func invalidTransitionsAndUnreadableStorageDoNotDestroyData() throws {
        let model = DayLogModel()
        model.setDayStart(start)
        model.setDrivingMinutes(120)
        model.setDayEnd(start.addingTimeInterval(-1))
        #expect(model.dayEnd == nil)
        model.setDayEnd(start.addingTimeInterval(3600))
        model.closeDay()
        model.resumeShift(at: start)
        model.deleteEntry(.dayEnd)
        #expect(model.isResting)
        #expect(model.restSegments.count == 1)
        let url = FileManager.default.temporaryDirectory.appending(path: "broken-\(UUID()).store")
        defer { try? FileManager.default.removeItem(at: url) }
        let bytes = Data("invalid journal".utf8)
        try bytes.write(to: url)
        let broken = DayLogModel(storageURL: url)
        broken.setDayStart(start)
        #expect(broken.storageError != nil)
        #expect(try Data(contentsOf: url) == bytes)
    }
    @Test func closingWithoutDrivingImmediatelyStartsRestAndMilestonesDoNotResetPeriod() {
        let model = DayLogModel()
        model.setDayStart(start)
        model.closeShift(at: start.addingTimeInterval(3600))
        #expect(model.isResting)
        #expect(model.drivingMinutes == nil)
        #expect(model.restMilestone(hours: 9) == start.addingTimeInterval(10 * 3600))
        let id = model.dutyID
        #expect(model.restElapsedSeconds(at: start.addingTimeInterval(31 * 3600)) == 30 * 3600)
        #expect(model.dutyID == id)
        #expect(model.archivedPeriods.isEmpty)
        model.setDrivingMinutes(80)
        model.deleteEntry(.driving)
        #expect(model.isDayClosed)
        #expect(model.isResting)
    }

}
