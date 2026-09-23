import Foundation

public enum AcademicPosition: Equatable, Sendable {
    case noSemester, beforeSemester, week(Int), afterSemester
    public var weekNumber: Int? { if case let .week(number) = self { return number }; return nil }
}

public struct AcademicCalendarService: Sendable {
    public init() {}

    /// Teaching weeks are Monday–Sunday. A midweek start produces a partial first week.
    public func firstMonday(of semester: SemesterDefinition) throws -> LocalDay {
        try semester.startDay.adding(days: 1 - semester.startDay.weekday.rawValue)
    }

    public func endExclusive(of semester: SemesterDefinition) throws -> LocalDay {
        try firstMonday(of: semester).adding(days: semester.totalWeeks * 7)
    }

    public func position(on day: LocalDay, semester: SemesterDefinition?) throws -> AcademicPosition {
        guard let semester else { return .noSemester }
        guard day >= semester.startDay else { return .beforeSemester }
        let delta = try firstMonday(of: semester).distance(to: day)
        guard delta < semester.totalWeeks * 7 else { return .afterSemester }
        return .week(delta / 7 + 1)
    }

    public func position(at date: Date, semester: SemesterDefinition?) throws -> AcademicPosition {
        guard let semester else { return .noSemester }
        return try position(on: LocalDay(date: date, timeZone: semester.timeZone), semester: semester)
    }
}
