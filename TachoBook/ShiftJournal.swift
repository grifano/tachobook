import Foundation

public struct RestSegment: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var start: Date
    public var end: Date?
    public var dailyRestConfirmed: Bool?
}

public struct DutyPeriod: Codable, Identifiable {
    public var id = UUID()
    public var calendarZone = TimeZone.current.identifier
    public var date: Date
    public var start: Date?
    public var drivingMinutes: Int?
    public var end: Date?
    public var isClosed = false
    public var rests: [RestSegment] = []
}

struct ShiftJournal: Codable {
    var current: DutyPeriod
    var history: [DutyPeriod] = []
}
