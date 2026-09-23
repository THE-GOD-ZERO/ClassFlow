import Foundation

public struct CourseOccurrence: Identifiable, Equatable, Sendable {
    public var id: String { "\(day.key):\(scheduleID.uuidString)" }
    public let courseID: UUID
    public let scheduleID: UUID
    public let day: LocalDay
    public let courseName: String
    public let teacher: String
    public let location: String
    public let color: CourseColor
    public let note: String
    public let activeWeeks: [Int]
    public let startSection: Int
    public let endSection: Int
    public let start: Date
    public let end: Date

    public init(courseID: UUID, scheduleID: UUID, day: LocalDay, courseName: String,
                teacher: String = "", location: String, color: CourseColor,
                note: String = "", activeWeeks: [Int] = [], startSection: Int, endSection: Int,
                start: Date, end: Date) {
        self.courseID = courseID
        self.scheduleID = scheduleID
        self.day = day
        self.courseName = courseName
        self.teacher = teacher
        self.location = location
        self.color = color
        self.note = note
        self.activeWeeks = activeWeeks
        self.startSection = startSection
        self.endSection = endSection
        self.start = start
        self.end = end
    }
}

public struct CourseConflict: Equatable, Sendable {
    public let firstID: String
    public let secondID: String
}

public enum ResolutionIssue: Equatable, Sendable {
    case missingTimeSlots(UUID)
    case nonexistentLocalTime(UUID)
    case conflictingOverrides
}

public struct ResolvedDay: Sendable {
    public let day: LocalDay
    public let academicPosition: AcademicPosition
    public let effectiveWeekday: Weekday
    public let appliedOverride: OverrideDefinition?
    public let needsConfirmation: Bool
    public let isHoliday: Bool
    public let courses: [CourseOccurrence]
    public let conflicts: [CourseConflict]
    public let issues: [ResolutionIssue]
}

public struct ScheduleResolver: Sendable {
    public init() {}

    public func resolve(day: LocalDay, semester: SemesterDefinition?, courses: [CourseDefinition],
                        timeSlots: [TimeSlotDefinition], overrides: [OverrideDefinition]) throws -> ResolvedDay {
        let position = try AcademicCalendarService().position(on: day, semester: semester)
        let candidates = overrides.filter { $0.day == day }.sorted {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        let rule = candidates.first
        var pending = rule.map { !$0.isConfirmed } ?? false
        let holiday = rule.map { $0.type == .holiday && $0.isConfirmed } ?? false
        let weekday = rule.flatMap { $0.isConfirmed ? $0.replacementWeekday : nil } ?? day.weekday
        var issues = [ResolutionIssue]()
        if let rule, candidates.dropFirst().contains(where: {
            $0.priority == rule.priority && ($0.type != rule.type || $0.replacementWeekday != rule.replacementWeekday)
        }) {
            issues.append(.conflictingOverrides)
            pending = true
        }
        var occurrences = [CourseOccurrence]()
        if let semester, let week = position.weekNumber, !holiday {
            try TimeSlotDefinition.validate(timeSlots)
            let slots = Dictionary(uniqueKeysWithValues: timeSlots.map { ($0.sectionNumber, $0) })
            for course in courses {
                for schedule in course.schedules where schedule.weekday == weekday && schedule.activeWeeks.contains(week) {
                    guard (schedule.startSection...schedule.endSection).allSatisfy({ slots[$0] != nil }),
                          let first = slots[schedule.startSection], let last = slots[schedule.endSection] else {
                        issues.append(.missingTimeSlots(schedule.id)); continue
                    }
                    guard let start = try localTime(first.startMinute, on: day, in: semester.timeZone),
                          let end = try localTime(last.endMinute, on: day, in: semester.timeZone), end > start else {
                        issues.append(.nonexistentLocalTime(schedule.id)); continue
                    }
                    occurrences.append(CourseOccurrence(courseID: course.id, scheduleID: schedule.id, day: day,
                        courseName: course.name, teacher: course.teacher,
                        location: schedule.location ?? course.location, color: course.color,
                        note: course.note, activeWeeks: schedule.activeWeeks.sorted,
                        startSection: schedule.startSection, endSection: schedule.endSection, start: start, end: end))
                }
            }
        }
        occurrences.sort { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
        return ResolvedDay(day: day, academicPosition: position, effectiveWeekday: weekday,
            appliedOverride: rule, needsConfirmation: pending, isHoliday: holiday, courses: occurrences,
            conflicts: Self.conflicts(in: occurrences), issues: issues)
    }

    private func localTime(_ minute: Int, on day: LocalDay, in zone: TimeZone) throws -> Date? {
        let calendar = LocalDay.calendar(in: zone)
        // `.strict` rejects nonexistent spring-forward times; repeated times use the first occurrence.
        let result = calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0,
            of: try day.start(in: zone), matchingPolicy: .strict, repeatedTimePolicy: .first, direction: .forward)
        return result.flatMap { LocalDay(date: $0, timeZone: zone) == day ? $0 : nil }
    }

    public static func conflicts(in courses: [CourseOccurrence]) -> [CourseConflict] {
        var result = [CourseConflict]()
        for (index, first) in courses.enumerated() {
            for second in courses.dropFirst(index + 1) where first.start < second.end && second.start < first.end {
                result.append(CourseConflict(firstID: first.id, secondID: second.id))
            }
        }
        return result
    }
}
