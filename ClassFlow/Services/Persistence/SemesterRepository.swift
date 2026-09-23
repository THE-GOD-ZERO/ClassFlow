import Foundation
import SwiftData
import ClassFlowCore

/// Central writes enforce invariants that a SwiftData relationship alone cannot express.
@MainActor
final class SemesterRepository {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func setCurrent(_ semester: Semester) throws {
        for item in try context.fetch(FetchDescriptor<Semester>()) { item.isCurrent = item.id == semester.id }
        semester.isCurrent = true
        try context.save()
    }

    func current() throws -> Semester? {
        let matches = try context.fetch(FetchDescriptor<Semester>()).filter(\.isCurrent)
        guard matches.count <= 1 else { throw DomainError.invalidSemester }
        return matches.first
    }

    func delete(_ semester: Semester) throws {
        // No automatic choice of a replacement semester. The UI can display “no current semester”.
        context.delete(semester)
        try context.save()
    }

    func updateTimeSlots(_ definitions: [TimeSlotDefinition], semester: Semester) throws {
        try TimeSlotDefinition.validate(definitions)
        let sections = Set(definitions.map(\.sectionNumber))
        // Refuse removal of referenced sections. Changing times never rewrites CourseSchedule.
        guard semester.courses.flatMap(\.schedules).allSatisfy({ schedule in
            schedule.startSection <= schedule.endSection &&
            (schedule.startSection...schedule.endSection).allSatisfy { sections.contains($0) }
        }) else { throw DomainError.invalidTimeSlot }
        let existing = semester.timeSlots
        for definition in definitions {
            if let slot = existing.first(where: { $0.sectionNumber == definition.sectionNumber }) {
                slot.startMinute = definition.startMinute
                slot.endMinute = definition.endMinute
            } else {
                context.insert(try ClassTimeSlot(sectionNumber: definition.sectionNumber,
                    startMinute: definition.startMinute, endMinute: definition.endMinute, semester: semester))
            }
        }
        for slot in existing where !sections.contains(slot.sectionNumber) { context.delete(slot) }
        try context.save()
    }
}
