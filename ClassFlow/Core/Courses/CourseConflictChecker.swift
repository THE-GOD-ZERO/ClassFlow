import Foundation

public struct DraftConflict: Identifiable, Equatable, Sendable {
    public let firstID: UUID
    public let secondID: UUID
    public let otherCourseName: String
    public let weekday: Int
    public let startSection: Int
    public let endSection: Int
    public let weeks: [Int]
    public var id: String { "\(firstID):\(secondID)" }
}

/// Checks recurring arrangements only; date overrides remain exclusively in ScheduleResolver.
public enum CourseConflictChecker {
    public static func conflicts(for draft: CourseDraft, among courses: [CourseDraft]) -> [DraftConflict] {
        var output = [DraftConflict]()
        let schedules = draft.sortedSchedules
        let peers = courses.filter { $0.id != draft.id }.flatMap { course in
            course.sortedSchedules.map { (course.name, $0) }
        }
        for (index, first) in schedules.enumerated() {
            let otherSchedules = peers + schedules.dropFirst(index + 1).map { (draft.name, $0) }
            for (name, second) in otherSchedules {
                let weeks = first.activeWeeks.intersection(second.activeWeeks).sorted()
                let start = max(first.startSection, second.startSection)
                let end = min(first.endSection, second.endSection)
                if first.weekday == second.weekday, start <= end, !weeks.isEmpty {
                    output.append(DraftConflict(firstID: first.id, secondID: second.id,
                        otherCourseName: name, weekday: first.weekday,
                        startSection: start, endSection: end, weeks: weeks))
                }
            }
        }
        return output
    }
}
