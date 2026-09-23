import Foundation

public enum ScheduleDayStatus: Equatable, Sendable {
    case normal
    case holiday
    case adjustedWorkday(Weekday)
    case schoolOverride(Weekday?)
    case needsConfirmation

    public init(resolved: ResolvedDay) {
        if resolved.needsConfirmation {
            self = .needsConfirmation
        } else if resolved.isHoliday {
            self = .holiday
        } else if let rule = resolved.appliedOverride {
            switch rule.type {
            case .holiday: self = .holiday
            case .adjustedWorkday:
                self = rule.replacementWeekday.map(Self.adjustedWorkday) ?? .needsConfirmation
            case .schoolOverride:
                self = .schoolOverride(rule.replacementWeekday)
            }
        } else {
            self = .normal
        }
    }
}

public struct DayScheduleSnapshot: Identifiable, Equatable, Sendable {
    public var id: String { date.key }
    public let date: LocalDay
    public let realWeekday: Weekday
    public let effectiveWeekday: Weekday
    public let academicWeek: Int?
    public let academicPosition: AcademicPosition
    public let dayStatus: ScheduleDayStatus
    public let specialTitle: String?
    public let courses: [CourseOccurrence]
    public let scheduleOverride: OverrideDefinition?
    public let issues: [ResolutionIssue]

    public init(resolved: ResolvedDay) {
        date = resolved.day
        realWeekday = resolved.day.weekday
        effectiveWeekday = resolved.effectiveWeekday
        academicWeek = resolved.academicPosition.weekNumber
        academicPosition = resolved.academicPosition
        dayStatus = ScheduleDayStatus(resolved: resolved)
        specialTitle = resolved.appliedOverride?.title
        courses = resolved.needsConfirmation ? [] : resolved.courses
        scheduleOverride = resolved.appliedOverride
        issues = resolved.issues
    }
}

public struct WeekScheduleSnapshot: Equatable, Sendable {
    public let weekNumber: Int
    public let startDate: LocalDay
    public let endDate: LocalDay
    public let days: [DayScheduleSnapshot]
    public let currentDate: LocalDay?

    public var isCurrentWeek: Bool {
        guard let currentDate else { return false }
        return days.contains { $0.date == currentDate }
    }

    public init(weekNumber: Int, startDate: LocalDay, endDate: LocalDay,
                days: [DayScheduleSnapshot], currentDate: LocalDay?) {
        self.weekNumber = weekNumber
        self.startDate = startDate
        self.endDate = endDate
        self.days = days
        self.currentDate = currentDate
    }
}

public struct WeekScheduleSnapshotBuilder: Sendable {
    public init() {}

    public func make(weekNumber: Int, resolvedDays: [ResolvedDay], currentDate: LocalDay?) throws
        -> WeekScheduleSnapshot {
        guard weekNumber > 0, resolvedDays.count == 7 else { throw DomainError.invalidWeek }
        let days = resolvedDays.map(DayScheduleSnapshot.init)
        guard days.first?.realWeekday == .monday, days.last?.realWeekday == .sunday else {
            throw DomainError.invalidWeek
        }
        for (first, second) in zip(days, days.dropFirst()) {
            guard try first.date.adding(days: 1) == second.date else { throw DomainError.invalidWeek }
        }
        // A semester may start midweek, so the first Monday/Tuesday can legitimately be beforeSemester.
        // Any in-semester day must still belong to the requested week, and at least one must match it.
        guard days.contains(where: { $0.academicWeek == weekNumber }),
              days.allSatisfy({ $0.academicWeek == nil || $0.academicWeek == weekNumber }) else {
            throw DomainError.invalidWeek
        }
        return WeekScheduleSnapshot(weekNumber: weekNumber, startDate: days[0].date,
            endDate: days[6].date, days: days, currentDate: currentDate)
    }
}

public struct WeekScheduleNavigation: Sendable {
    public init() {}

    public func initialWeek(for day: LocalDay, semester: SemesterDefinition) throws -> Int {
        switch try AcademicCalendarService().position(on: day, semester: semester) {
        case let .week(number): return number
        case .beforeSemester, .noSemester: return 1
        case .afterSemester: return semester.totalWeeks
        }
    }

    public func previous(from week: Int, totalWeeks: Int) -> Int { max(1, min(totalWeeks, week - 1)) }
    public func next(from week: Int, totalWeeks: Int) -> Int { max(1, min(totalWeeks, week + 1)) }
}
