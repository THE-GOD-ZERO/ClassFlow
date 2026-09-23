import Foundation

public enum TodayCourseStatus: String, Equatable, Sendable {
    case finished
    case current
    case next
    case upcoming
}

public struct TodayCourseItem: Identifiable, Equatable, Sendable {
    public var id: String { occurrence.id }
    public let occurrence: CourseOccurrence
    public let status: TodayCourseStatus

    public init(occurrence: CourseOccurrence, status: TodayCourseStatus) {
        self.occurrence = occurrence
        self.status = status
    }
}

public typealias TodayDayKind = ScheduleDayStatus

public enum TodayCountdown: Equatable, Sendable {
    case startsIn(minutes: Int)
    case endsIn(minutes: Int)

    public var minutes: Int {
        switch self {
        case let .startsIn(minutes), let .endsIn(minutes): return minutes
        }
    }
}

/// Immutable presentation input for Today. It contains no SwiftData or SwiftUI types.
public struct TodaySnapshot: Equatable, Sendable {
    public let day: LocalDay
    public let academicPosition: AcademicPosition
    public let effectiveWeekday: Weekday
    public let dayKind: TodayDayKind
    public let specialDayTitle: String?
    public let appliedOverride: OverrideDefinition?
    public let courses: [TodayCourseItem]
    public let currentCourse: TodayCourseItem?
    public let nextCourse: TodayCourseItem?
    public let countdown: TodayCountdown?
    public let issues: [ResolutionIssue]

    public init(day: LocalDay, academicPosition: AcademicPosition, effectiveWeekday: Weekday,
                dayKind: TodayDayKind, specialDayTitle: String?, appliedOverride: OverrideDefinition?,
                courses: [TodayCourseItem], currentCourse: TodayCourseItem?, nextCourse: TodayCourseItem?,
                countdown: TodayCountdown?, issues: [ResolutionIssue]) {
        self.day = day
        self.academicPosition = academicPosition
        self.effectiveWeekday = effectiveWeekday
        self.dayKind = dayKind
        self.specialDayTitle = specialDayTitle
        self.appliedOverride = appliedOverride
        self.courses = courses
        self.currentCourse = currentCourse
        self.nextCourse = nextCourse
        self.countdown = countdown
        self.issues = issues
    }
}

public struct TodaySnapshotBuilder: Sendable {
    public init() {}

    public func make(from resolved: ResolvedDay, now: Date) -> TodaySnapshot {
        let kind = ScheduleDayStatus(resolved: resolved)

        // Resolver exposes the actual-weekday schedule as a provisional preview for generic clients.
        // Today deliberately hides it until the user confirms a replacement weekday.
        let visibleOccurrences = resolved.needsConfirmation ? [] : resolved.courses.sorted {
            $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start
        }
        let currentOccurrence = visibleOccurrences.first { $0.start <= now && now < $0.end }
        let nextOccurrence = visibleOccurrences.first { $0.start > now }

        let items = visibleOccurrences.map { occurrence in
            let status: TodayCourseStatus
            if occurrence.end <= now {
                status = .finished
            } else if occurrence.start <= now && now < occurrence.end {
                status = .current
            } else if occurrence.id == nextOccurrence?.id {
                status = .next
            } else {
                status = .upcoming
            }
            return TodayCourseItem(occurrence: occurrence, status: status)
        }
        let current = currentOccurrence.flatMap { occurrence in items.first { $0.id == occurrence.id } }
        let next = nextOccurrence.flatMap { occurrence in items.first { $0.id == occurrence.id } }
        let countdown: TodayCountdown?
        if let current {
            countdown = .endsIn(minutes: remainingMinutes(from: now, to: current.occurrence.end))
        } else if let next {
            countdown = .startsIn(minutes: remainingMinutes(from: now, to: next.occurrence.start))
        } else {
            countdown = nil
        }

        return TodaySnapshot(day: resolved.day, academicPosition: resolved.academicPosition,
            effectiveWeekday: resolved.effectiveWeekday, dayKind: kind,
            specialDayTitle: resolved.appliedOverride?.title, appliedOverride: resolved.appliedOverride,
            courses: items, currentCourse: current, nextCourse: next, countdown: countdown,
            issues: resolved.issues)
    }

    private func remainingMinutes(from start: Date, to end: Date) -> Int {
        max(0, Int(ceil(end.timeIntervalSince(start) / 60)))
    }
}
