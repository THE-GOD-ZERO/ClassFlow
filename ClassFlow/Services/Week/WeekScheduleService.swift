import Foundation
import SwiftData
import ClassFlowCore

@MainActor
struct WeekScheduleService {
    func snapshot(weekNumber: Int, semester: Semester, currentDate: LocalDay?) throws
        -> WeekScheduleSnapshot {
        let definition = try semester.definition()
        guard (1...definition.totalWeeks).contains(weekNumber) else { throw DomainError.invalidWeek }
        let firstMonday = try AcademicCalendarService().firstMonday(of: definition)
        let weekStart = try firstMonday.adding(days: (weekNumber - 1) * 7)
        let resolver = ScheduleService()
        let resolvedDays = try (0..<7).map { offset in
            try resolver.resolve(day: weekStart.adding(days: offset), semester: semester)
        }
        return try WeekScheduleSnapshotBuilder().make(weekNumber: weekNumber,
            resolvedDays: resolvedDays, currentDate: currentDate)
    }
}
