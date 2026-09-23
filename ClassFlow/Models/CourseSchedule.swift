import Foundation
import SwiftData
import ClassFlowCore

@Model
final class CourseSchedule {
    @Attribute(.unique) var id: UUID
    var weekdayRawValue: Int
    var startSection: Int
    var endSection: Int
    var activeWeeks: [Int]
    var locationOverride: String?
    var course: Course?

    init(weekday: Weekday, startSection: Int, endSection: Int, activeWeeks: ActiveWeeks,
         locationOverride: String? = nil, course: Course) throws {
        _ = try ScheduleDefinition(weekday: weekday, startSection: startSection,
                                   endSection: endSection, activeWeeks: activeWeeks)
        self.id = UUID()
        self.weekdayRawValue = weekday.rawValue
        self.startSection = startSection
        self.endSection = endSection
        self.activeWeeks = activeWeeks.sorted
        self.locationOverride = locationOverride
        self.course = course
    }

    func definition() throws -> ScheduleDefinition {
        guard let weekday = Weekday(rawValue: weekdayRawValue) else { throw DomainError.invalidSchedule }
        return try ScheduleDefinition(id: id, weekday: weekday, startSection: startSection,
            endSection: endSection, activeWeeks: ActiveWeeks(activeWeeks), location: locationOverride)
    }
}
