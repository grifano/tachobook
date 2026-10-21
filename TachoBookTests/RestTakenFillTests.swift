import Testing
@testable import TachoBook

/// Past-day Rest Taken arc: fills against the 9 h daily scale and stays full above it.
struct RestTakenFillTests {
    @Test func noRecordStaysEmpty() {
        #expect(HomeTimeline.restTakenFill(seconds: nil) == 0)
    }

    @Test func zeroIsEmpty() {
        #expect(HomeTimeline.restTakenFill(seconds: 0) == 0)
    }

    @Test func partialRestFillsProportionally() {
        #expect(abs(HomeTimeline.restTakenFill(seconds: 7 * 3600) - 7.0 / 9.0) < 1e-9)
    }

    @Test func exactlyNineHoursIsFull() {
        #expect(HomeTimeline.restTakenFill(seconds: 9 * 3600) == 1)
    }

    @Test func aboveNineHoursStaysFull() {
        #expect(HomeTimeline.restTakenFill(seconds: 18 * 3600 + 60) == 1)
    }
}
