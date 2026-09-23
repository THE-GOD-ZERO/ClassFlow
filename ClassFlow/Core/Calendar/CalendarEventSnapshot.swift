import Foundation

public enum CalendarRole: String, Codable, Sendable { case holidays, school }

/// EventKit objects never cross into the resolver, persistence models, or views.
public struct CalendarEventSnapshot: Sendable {
    public let calendarID: String
    public let eventID: String
    public let title: String
    public let notes: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    /// Zone used to interpret start/end; the EventKit adapter captures the default zone for floating events.
    public let timeZoneID: String?
    public let role: CalendarRole

    public init(calendarID: String, eventID: String, title: String, notes: String = "",
                start: Date, end: Date, isAllDay: Bool, timeZoneID: String? = nil, role: CalendarRole) {
        self.calendarID = calendarID
        self.eventID = eventID
        self.title = title
        self.notes = notes
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.timeZoneID = timeZoneID
        self.role = role
    }
}

public struct ImportedOverride: Sendable {
    public let syncKey: String
    public let calendarID: String
    public let eventID: String
    public let fingerprint: String
    public let rule: OverrideDefinition
}

public struct DayRange: Equatable, Sendable {
    public let start: LocalDay
    public let endExclusive: LocalDay

    public init(start: LocalDay, endExclusive: LocalDay) throws {
        guard start < endExclusive else { throw DomainError.invalidDate }
        self.start = start
        self.endExclusive = endExclusive
    }

    public func contains(_ day: LocalDay) -> Bool { day >= start && day < endExclusive }
}
