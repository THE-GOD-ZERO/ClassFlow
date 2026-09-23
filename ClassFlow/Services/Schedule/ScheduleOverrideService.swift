import Foundation
import SwiftData
import ClassFlowCore

/// The single write path used by Today and Schedule when a user confirms a replacement timetable.
@MainActor
struct ScheduleOverrideService {
    let container: ModelContainer

    func confirmReplacement(day: LocalDay, weekday: Weekday, semesterID: UUID,
                            title: String?, note: String) throws {
        let context = ModelContext(container)
        guard let semester = try context.fetch(FetchDescriptor<Semester>())
            .first(where: { $0.id == semesterID }) else { throw DomainError.invalidSemester }
        let cleanTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        try OverrideRepository(context: context).saveManual(day: day, type: .adjustedWorkday,
            weekday: weekday, title: cleanTitle.flatMap { $0.isEmpty ? nil : $0 } ?? "调休",
            note: note, semester: semester)
    }
}
