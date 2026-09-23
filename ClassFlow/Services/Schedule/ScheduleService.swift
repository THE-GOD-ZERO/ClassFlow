import Foundation
import SwiftData
import ClassFlowCore

/// Entry point for future Today / Schedule / notification consumers.
@MainActor
struct ScheduleService {
    func resolve(day: LocalDay, semester: Semester?) throws -> ResolvedDay {
        guard let semester else {
            return try ScheduleResolver().resolve(day: day, semester: nil, courses: [], timeSlots: [], overrides: [])
        }
        return try ScheduleResolver().resolve(day: day, semester: semester.definition(),
            courses: semester.courses.map { try $0.definition() },
            timeSlots: semester.timeSlots.map { try $0.definition() },
            overrides: semester.overrides.map { try $0.definition() })
    }
}
