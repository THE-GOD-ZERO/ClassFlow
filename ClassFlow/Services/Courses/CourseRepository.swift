import Foundation
import SwiftData
import ClassFlowCore

enum CourseWriteError: LocalizedError {
    case invalid([String]), conflicts([DraftConflict]), stale
    var errorDescription: String? {
        switch self {
        case let .invalid(messages): messages.joined(separator: "\n")
        case .conflicts: "发现课程冲突，请确认后保存。"
        case .stale: "课程或学期已发生变化，请关闭编辑器并重新打开。"
        }
    }
}

@MainActor
struct CourseRepository {
    let container: ModelContainer

    @discardableResult
    func save(_ draft: CourseDraft, semesterID: UUID, original: CourseDraft?,
              acceptedConflicts: [DraftConflict] = []) throws -> UUID {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            let semester = try term(semesterID, context: context)
            let slots = try semester.timeSlots.map { try $0.definition() }
            let issues = draft.issues(totalWeeks: semester.totalWeeks, slots: slots)
            guard issues.isEmpty else { throw CourseWriteError.invalid(issues) }
            let current = semester.courses.first { $0.id == draft.id }
            if let original {
                guard let current, try CourseDraft(current.definition()) == original else {
                    throw CourseWriteError.stale
                }
            } else if try context.fetch(FetchDescriptor<Course>()).contains(where: { $0.id == draft.id }) {
                throw CourseWriteError.stale
            }
            let peers = try semester.courses.map { try CourseDraft($0.definition()) }
            let conflicts = CourseConflictChecker.conflicts(for: draft, among: peers)
            guard conflicts.allSatisfy({ acceptedConflicts.contains($0) }) else {
                throw CourseWriteError.conflicts(conflicts)
            }
            let value = try draft.definition()
            let course: Course
            if let current { course = current }
            else {
                course = try Course(name: value.name, semester: semester)
                course.id = draft.id
                context.insert(course)
            }
            course.name = value.name; course.teacher = value.teacher; course.location = value.location
            course.note = value.note; course.colorRawValue = value.colorKey
            let previous = course.schedules
            let allIDs = try context.fetch(FetchDescriptor<CourseSchedule>())
            for schedule in value.schedules {
                if allIDs.contains(where: { $0.id == schedule.id && $0.course?.id != course.id }) {
                    throw CourseWriteError.stale
                }
                let record: CourseSchedule
                if let existing = previous.first(where: { $0.id == schedule.id }) { record = existing }
                else {
                    record = try CourseSchedule(weekday: schedule.weekday,
                        startSection: schedule.startSection, endSection: schedule.endSection,
                        activeWeeks: schedule.activeWeeks, course: course)
                    record.id = schedule.id
                    context.insert(record)
                }
                record.weekdayRawValue = schedule.weekday.rawValue
                record.startSection = schedule.startSection; record.endSection = schedule.endSection
                record.activeWeeks = schedule.activeWeeks.sorted
                record.locationOverride = schedule.location
            }
            let retained = Set(value.schedules.map(\.id))
            for removed in previous where !retained.contains(removed.id) { context.delete(removed) }
            try context.save()
            return course.id
        } catch {
            context.rollback()
            throw error
        }
    }

    func delete(_ draft: CourseDraft, semesterID: UUID) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            let semester = try term(semesterID, context: context)
            guard let course = semester.courses.first(where: { $0.id == draft.id }),
                  try CourseDraft(course.definition()) == draft else { throw CourseWriteError.stale }
            context.delete(course) // Existing cascade owns CourseSchedule deletion.
            try context.save()
        } catch { context.rollback(); throw error }
    }

    func saveTimeSlots(_ slots: [TimeSlotDefinition], semesterID: UUID) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            guard !slots.isEmpty else { throw CourseWriteError.invalid(["请至少添加一个节次。"]) }
            let semester = try term(semesterID, context: context)
            let sections = Set(slots.map(\.sectionNumber))
            guard semester.courses.flatMap(\.schedules).allSatisfy({ schedule in
                schedule.startSection <= schedule.endSection &&
                (schedule.startSection...schedule.endSection).allSatisfy { sections.contains($0) }
            }) else { throw CourseWriteError.invalid(["不能删除课程正在使用的节次，请先修改对应上课安排。"]) }
            try SemesterRepository(context: context).updateTimeSlots(slots, semester: semester)
        } catch { context.rollback(); throw error }
    }

    private func term(_ id: UUID, context: ModelContext) throws -> Semester {
        guard let semester = try SemesterRepository(context: context).current(), semester.id == id else {
            throw CourseWriteError.stale
        }
        return semester
    }
}
