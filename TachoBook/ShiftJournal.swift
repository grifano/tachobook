import Foundation

/// Which rest milestones apply. Missing in legacy records, where every rest was daily.
public enum RestKind: String, Codable, Sendable {
    case daily
    case weekly

    /// The two milestones shown for this rest: 9/11 h daily, 24/45 h weekly.
    public var milestoneHours: (first: Int, second: Int) {
        switch self {
        case .daily: (9, 11)
        case .weekly: (24, 45)
        }
    }

    /// The milestone after which Start of day becomes available.
    public var requiredHours: Int {
        switch self {
        case .daily: 9
        case .weekly: 45
        }
    }
}

public struct RestSegment: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var start: Date
    public var end: Date?
    public var dailyRestConfirmed: Bool?
    public var kind: RestKind?
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
