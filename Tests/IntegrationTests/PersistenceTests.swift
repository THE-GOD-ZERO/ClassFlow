import XCTest
import SwiftData
import ClassFlowCore
@testable import ClassFlow

final class PersistenceTests: XCTestCase {
    @MainActor
    private func fixture(_ container: ModelContainer) throws -> UUID {
        let context = ModelContext(container)
        let term = try Semester(name: "2026-2027 第一学期", startDay: LocalDay(key: "2026-09-07"),
                                totalWeeks: 18, isCurrent: true)
        context.insert(term)
        let course = try Course(name: "高等数学", semester: term)
        context.insert(course)
        context.insert(try CourseSchedule(weekday: .monday, startSection: 1, endSection: 2,
                                         activeWeeks: ActiveWeeks([1, 3, 5]), course: course))
        context.insert(try ClassTimeSlot(sectionNumber: 1, startMinute: 480, endMinute: 525, semester: term))
        context.insert(try ClassTimeSlot(sectionNumber: 2, startMinute: 535, endMinute: 580, semester: term))
        let rule = try OverrideDefinition(day: LocalDay(key: "2026-10-01"), type: .holiday,
                                          title: "放假", source: .manual, isConfirmed: true)
        context.insert(ScheduleOverride(rule: rule, semester: term))
        try context.save()
        return term.id
    }

    @MainActor
    func testRelationshipInversesAndWeekArrayRoundTrip() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        _ = try fixture(container)
        let context = ModelContext(container)
        let term = try XCTUnwrap(context.fetch(FetchDescriptor<Semester>()).first)
        XCTAssertEqual(term.courses.count, 1)
        XCTAssertEqual(term.timeSlots.count, 2)
        XCTAssertEqual(term.overrides.count, 1)
        let course = try XCTUnwrap(term.courses.first)
        XCTAssertEqual(course.semester?.id, term.id)
        XCTAssertEqual(course.schedules.count, 1)
        XCTAssertEqual(course.schedules.first?.activeWeeks, [1, 3, 5])
        XCTAssertEqual(course.schedules.first?.course?.id, course.id)
    }

    @MainActor
    func testCourseDeletionCascadesOnlySchedules() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        _ = try fixture(container)
        let context = ModelContext(container)
        context.delete(try XCTUnwrap(context.fetch(FetchDescriptor<Course>()).first))
        try context.save()
        let check = ModelContext(container)
        XCTAssertEqual(try check.fetchCount(FetchDescriptor<CourseSchedule>()), 0)
        XCTAssertEqual(try check.fetchCount(FetchDescriptor<Semester>()), 1)
        XCTAssertEqual(try check.fetchCount(FetchDescriptor<ClassTimeSlot>()), 2)
    }

    @MainActor
    func testSemesterDeletionLeavesNoOrphanModels() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        _ = try fixture(container)
        let context = ModelContext(container)
        let term = try XCTUnwrap(context.fetch(FetchDescriptor<Semester>()).first)
        try SemesterRepository(context: context).delete(term)
        let check = ModelContext(container)
        XCTAssertEqual(try check.fetchCount(FetchDescriptor<Semester>()), 0)
        XCTAssertEqual(try check.fetchCount(FetchDescriptor<Course>()), 0)
        XCTAssertEqual(try check.fetchCount(FetchDescriptor<CourseSchedule>()), 0)
        XCTAssertEqual(try check.fetchCount(FetchDescriptor<ClassTimeSlot>()), 0)
        XCTAssertEqual(try check.fetchCount(FetchDescriptor<ScheduleOverride>()), 0)
    }

    @MainActor
    func testCurrentSemesterIsExclusive() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        _ = try fixture(container)
        let context = ModelContext(container)
        let next = try Semester(name: "第二学期", startDay: LocalDay(key: "2027-02-22"), totalWeeks: 18)
        context.insert(next)
        let repository = SemesterRepository(context: context)
        try repository.setCurrent(next)
        XCTAssertEqual(try repository.current()?.id, next.id)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Semester>()).filter(\.isCurrent).count, 1)
    }

    @MainActor
    func testTimeSlotEditsPreserveSchedulesAndRejectReferencedSectionRemoval() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        _ = try fixture(container)
        let context = ModelContext(container)
        let term = try XCTUnwrap(context.fetch(FetchDescriptor<Semester>()).first)
        let scheduleID = term.courses.first?.schedules.first?.id
        let repository = SemesterRepository(context: context)
        XCTAssertThrowsError(try repository.updateTimeSlots([], semester: term))
        try repository.updateTimeSlots([
            TimeSlotDefinition(sectionNumber: 1, startMinute: 540, endMinute: 585),
            TimeSlotDefinition(sectionNumber: 2, startMinute: 595, endMinute: 640)
        ], semester: term)
        XCTAssertEqual(term.courses.first?.schedules.first?.id, scheduleID)
        let result = try ScheduleService().resolve(day: LocalDay(key: "2026-09-07"), semester: term)
        let start = try XCTUnwrap(result.courses.first?.start)
        XCTAssertEqual(LocalDay.calendar(in: LocalDay.schoolTimeZone).component(.hour, from: start), 9)
    }

    @MainActor
    func testManualRuleUpsertAndMappingValidation() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        _ = try fixture(container)
        let context = ModelContext(container)
        let term = try XCTUnwrap(context.fetch(FetchDescriptor<Semester>()).first)
        let repository = OverrideRepository(context: context)
        let date = try LocalDay(key: "2026-10-10")
        XCTAssertThrowsError(try repository.saveManual(day: date, type: .adjustedWorkday,
                                                       weekday: nil, title: "调休", semester: term))
        let first = try repository.saveManual(day: date, type: .adjustedWorkday,
                                              weekday: .monday, title: "调休", semester: term)
        let second = try repository.saveManual(day: date, type: .adjustedWorkday,
                                               weekday: .friday, title: "修改", semester: term)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(term.overrides.filter { $0.dayKey == date.key }.count, 1)
    }

    @MainActor
    func testDiskStoreSurvivesContainerReopen() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("ClassFlow.store")
        var container: ModelContainer? = try PersistenceController.makeContainer(storeURL: url)
        let id = try fixture(XCTUnwrap(container))
        container = nil
        let reopened = try PersistenceController.makeContainer(storeURL: url)
        let context = ModelContext(reopened)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Semester>()).first?.id, id)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CourseSchedule>()), 1)
    }
}
