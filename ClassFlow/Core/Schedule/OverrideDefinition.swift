import Foundation

public enum OverrideType: String, Equatable, Sendable { case holiday, adjustedWorkday, schoolOverride }
public enum OverrideSource: String, Equatable, Sendable { case systemCalendar, manual, schoolCalendar }

public struct OverrideDefinition: Equatable, Sendable {
    public let id: UUID
    public let day: LocalDay
    public let type: OverrideType
    public let replacementWeekday: Weekday?
    public let title: String
    public let note: String
    public let source: OverrideSource
    public let isConfirmed: Bool
    public let updatedAt: Date

    public init(id: UUID = UUID(), day: LocalDay, type: OverrideType, replacementWeekday: Weekday? = nil,
                title: String, note: String = "", source: OverrideSource, isConfirmed: Bool,
                updatedAt: Date = .distantPast) throws {
        guard type != .holiday || replacementWeekday == nil,
              type != .adjustedWorkday || !isConfirmed || replacementWeekday != nil else {
            throw DomainError.invalidOverride
        }
        self.id = id
        self.day = day
        self.type = type
        self.replacementWeekday = replacementWeekday
        self.title = title
        self.note = note
        self.source = source
        self.isConfirmed = isConfirmed
        self.updatedAt = updatedAt
    }

    /// Only actionable/confirmed rules get authoritative priority.
    public var priority: Int {
        if source == .manual && isConfirmed { return 500 }
        if source == .schoolCalendar && isConfirmed { return 400 }
        if isConfirmed && replacementWeekday != nil { return 300 }
        // A workday marker must stop a coincident national holiday from silently cancelling classes.
        if type == .adjustedWorkday || (type == .schoolOverride && !isConfirmed) { return 250 }
        if type == .holiday && isConfirmed { return 200 }
        return 100
    }
}
