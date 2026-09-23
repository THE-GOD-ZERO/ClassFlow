import XCTest
import SwiftData
import ClassFlowCore
@testable import ClassFlow

final class CourseRepositoryTests: XCTestCase {
    @MainActor
    private func fixture() throws -> (ModelContainer, UUID, CourseDraft) {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let semester = try Semester(name: "秋季", startDay: LocalDay(key: "2026-09-07"), totalWeeks: 18, isCurrent: true)
        context.insert(semester)
        for section in 1...4 {
            context.insert(try ClassTimeSlot(sectionNumber: section, startMinute: 480 + (section - 1) * 60,
                endMinute: 525 + (section - 1) * 60, semester: semester))
        }
        try context.save()
        return (container, semester.id, CourseDraft(name: "高等数学", teacher: "王老师", location: "A301", schedules: [
            CourseScheduleDraft(weekday: 1, startSection: 1, endSection: 2, activeWeeks: Set(1...18)),
            CourseScheduleDraft(weekday: 3, startSection: 3, endSection: 4, activeWeeks: [1, 3, 5], location: "B205")
        ]))
    }
    @MainActor
    private func stored(_ container: ModelContainer) throws -> CourseDraft {
        let context = ModelContext(container)
        return try CourseDraft(XCTUnwrap(context.fetch(FetchDescriptor<Course>()).first).definition())
    }
    @MainActor
    func testCreateWritesOneCourseWithTwoInverseRelationships() async throws {
        let (container, semesterID, draft) = try fixture()
        try CourseRepository(container: container).save(draft, semesterID: semesterID, original: nil)
        let context = ModelContext(container)
        let course = try XCTUnwrap(context.fetch(FetchDescriptor<Course>()).first)
        XCTAssertEqual(course.id, draft.id); XCTAssertEqual(course.semester?.id, semesterID)
        XCTAssertEqual(course.schedules.count, 2)
        XCTAssertTrue(course.schedules.allSatisfy { $0.course?.id == draft.id })
        XCTAssertEqual(try stored(container), draft)
    }
    @MainActor
    func testEditingKeepsCourseAndRetainedScheduleIDs() async throws {
        let (container, semesterID, original) = try fixture()
        let repository = CourseRepository(container: container)
        try repository.save(original, semesterID: semesterID, original: nil)
        var edit = original; edit.name = "数学分析"; edit.schedules[0].location = "实验楼"
        try repository.save(edit, semesterID: semesterID, original: original)
        let value = try stored(container)
        XCTAssertEqual(value.id, original.id); XCTAssertEqual(value.schedules.map(\.id), original.schedules.map(\.id))
        XCTAssertEqual(value.name, "数学分析"); XCTAssertEqual(value.schedules[0].location, "实验楼")
    }
    @MainActor
    func testRemoveOnlyOneScheduleDeletesItsRecord() async throws {
        let (container, semesterID, original) = try fixture()
        let repository = CourseRepository(container: container)
        try repository.save(original, semesterID: semesterID, original: nil)
        var edit = original; edit.schedules.removeLast()
        try repository.save(edit, semesterID: semesterID, original: original)
        let context = ModelContext(container)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Course>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CourseSchedule>()), 1)
        XCTAssertEqual(try stored(container).schedules[0].id, original.schedules[0].id)
    }
    @MainActor
    func testDeleteCascadesSchedulesAndKeepsSemesterAndSlots() async throws {
        let (container, semesterID, original) = try fixture()
        let repository = CourseRepository(container: container)
        try repository.save(original, semesterID: semesterID, original: nil)
        try repository.delete(original, semesterID: semesterID)
        let context = ModelContext(container)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Course>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CourseSchedule>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Semester>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ClassTimeSlot>()), 4)
    }
    @MainActor
    func testCancelDraftNeverChangesPersistedData() async throws {
        let (container, semesterID, original) = try fixture()
        try CourseRepository(container: container).save(original, semesterID: semesterID, original: nil)
        var abandoned = try stored(container)
        abandoned.name = "不要保存"; abandoned.schedules.removeAll()
        XCTAssertEqual(try stored(container), original)
    }
    @MainActor
    func testInvalidEditLeavesOriginalUntouched() async throws {
        let (container, semesterID, original) = try fixture()
        let repository = CourseRepository(container: container)
        try repository.save(original, semesterID: semesterID, original: nil)
        var invalid = original; invalid.schedules = []
        XCTAssertThrowsError(try repository.save(invalid, semesterID: semesterID, original: original))
        XCTAssertEqual(try stored(container), original)
    }
    @MainActor
    func testConflictRequiresExplicitAcceptanceAndDoesNotPartiallyInsert() async throws {
        let (container, semesterID, original) = try fixture()
        let repository = CourseRepository(container: container)
        try repository.save(original, semesterID: semesterID, original: nil)
        let second = CourseDraft(name: "大学英语", schedules: [CourseScheduleDraft(weekday: 1, startSection: 2, endSection: 3, activeWeeks: [3, 5, 7])])
        var conflicts: [DraftConflict] = []
        do { try repository.save(second, semesterID: semesterID, original: nil); XCTFail("Must require confirmation") }
        catch CourseWriteError.conflicts(let values) { conflicts = values }
        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<Course>()), 1)
        try repository.save(second, semesterID: semesterID, original: nil, acceptedConflicts: conflicts)
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<Course>()), 2)
    }
    @MainActor
    func testStaleEditAndDeleteDoNotOverwriteNewerData() async throws {
        let (container, semesterID, original) = try fixture()
        let repository = CourseRepository(container: container)
        try repository.save(original, semesterID: semesterID, original: nil)
        var newer = original; newer.note = "更新的备注"
        try repository.save(newer, semesterID: semesterID, original: original)
        XCTAssertThrowsError(try repository.save(original, semesterID: semesterID, original: original))
        XCTAssertThrowsError(try repository.delete(original, semesterID: semesterID))
        XCTAssertEqual(try stored(container), newer)
    }
    @MainActor
    func testRejectsWrongSemesterWithoutWriting() async throws {
        let (container, _, original) = try fixture()
        XCTAssertThrowsError(try CourseRepository(container: container).save(original, semesterID: UUID(), original: nil))
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<Course>()), 0)
    }
    @MainActor
    func testManualSundayMappingReadsEditedMondayWithoutCopying() async throws {
        let (container, semesterID, original) = try fixture()
        let repository = CourseRepository(container: container)
        try repository.save(original, semesterID: semesterID, original: nil)
        let context = ModelContext(container)
        let semester = try XCTUnwrap(context.fetch(FetchDescriptor<Semester>()).first)
        let day = try LocalDay(key: "2026-09-13")
        let rule = try OverrideDefinition(day: day, type: .adjustedWorkday, replacementWeekday: .monday,
            title: "补周一", source: .manual, isConfirmed: true)
        context.insert(ScheduleOverride(rule: rule, semester: semester)); try context.save()
        var edit = original; edit.name = "修改后的高数"; edit.schedules[0].location = "C102"
        try repository.save(edit, semesterID: semesterID, original: original)
        let check = ModelContext(container)
        let updatedSemester = try XCTUnwrap(check.fetch(FetchDescriptor<Semester>()).first)
        let result = try ScheduleService().resolve(day: day, semester: updatedSemester)
        XCTAssertEqual(result.courses.first?.courseName, "修改后的高数")
        XCTAssertEqual(result.courses.first?.location, "C102")
        XCTAssertEqual(try check.fetchCount(FetchDescriptor<CourseSchedule>()), 2)
        XCTAssertEqual(updatedSemester.overrides.count, 1)
        XCTAssertEqual(updatedSemester.overrides.first?.id, rule.id)
    }
    @MainActor
    func testTodayAndWeekReloadObserveCreateEditDelete() async throws {
        let (container, semesterID, original) = try fixture()
        let repository = CourseRepository(container: container)
        let now = try LocalDay(key: "2026-09-07").start(in: LocalDay.schoolTimeZone)
        let today = TodayViewModel(container: container, nowProvider: { now })
        let week = WeekScheduleViewModel(container: container, nowProvider: { now })
        today.reload(); week.reload()
        XCTAssertTrue(today.todayCourses.isEmpty)
        try repository.save(original, semesterID: semesterID, original: nil)
        today.reload(); week.reload()
        XCTAssertEqual(today.todayCourses.count, 1)
        XCTAssertEqual(week.page?.snapshot.days.first?.courses.count, 1)
        var edit = original; edit.name = "Updated"
        try repository.save(edit, semesterID: semesterID, original: original)
        today.reload(); week.reload()
        XCTAssertEqual(today.todayCourses.first?.occurrence.courseName, "Updated")
        XCTAssertEqual(week.page?.snapshot.days.first?.courses.first?.courseName, "Updated")
        try repository.delete(edit, semesterID: semesterID)
        today.reload(); week.reload()
        XCTAssertTrue(today.todayCourses.isEmpty)
        XCTAssertTrue(week.page?.snapshot.days.allSatisfy { $0.courses.isEmpty } == true)
    }
    @MainActor
    func testCourseSearchIncludesArrangementLocation() async throws {
        let (container, semesterID, original) = try fixture()
        try CourseRepository(container: container).save(original, semesterID: semesterID, original: nil)
        let model = CoursesViewModel(container: container); model.reload()
        for query in ["高等", "王", "a301", "b205"] {
            model.search = query; XCTAssertEqual(model.filteredCourses.count, 1)
        }
        model.search = "不存在"; XCTAssertTrue(model.filteredCourses.isEmpty)
    }
    @MainActor
    func testTimeSlotConfigurationPreservesReferencedSchedules() async throws {
        let (container, semesterID, original) = try fixture()
        let repository = CourseRepository(container: container)
        try repository.save(original, semesterID: semesterID, original: nil)
        let slots = try (1...4).map { try TimeSlotDefinition(sectionNumber: $0, startMinute: 540 + ($0 - 1) * 60, endMinute: 585 + ($0 - 1) * 60) }
        try repository.saveTimeSlots(slots, semesterID: semesterID)
        XCTAssertEqual(try stored(container), original)
        XCTAssertThrowsError(try repository.saveTimeSlots(Array(slots.dropLast()), semesterID: semesterID))
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<ClassTimeSlot>()), 4)
    }
    @MainActor
    func testNewColorsPersistUsingExistingStringField() async throws {
        let (container, semesterID, original) = try fixture()
        var draft = original; draft.color = .denim
        try CourseRepository(container: container).save(draft, semesterID: semesterID, original: nil)
        XCTAssertEqual(try stored(container).color, .denim)
    }
    @MainActor
    func testAddingArrangementKeepsExistingIdentities() async throws {
        let (container, semesterID, original) = try fixture()
        let repository = CourseRepository(container: container)
        try repository.save(original, semesterID: semesterID, original: nil)
        var edit = original
        edit.schedules.append(CourseScheduleDraft(weekday: 5, startSection: 1, endSection: 2, activeWeeks: [2, 4]))
        try repository.save(edit, semesterID: semesterID, original: original)
        XCTAssertEqual(try stored(container), edit)
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<CourseSchedule>()), 3)
    }
    @MainActor
    func testForeignScheduleIdentityRollsBackWholeCreation() async throws {
        let (container, semesterID, original) = try fixture()
        let repository = CourseRepository(container: container)
        try repository.save(original, semesterID: semesterID, original: nil)
        var foreign = original.schedules[0]; foreign.weekday = 5
        let invalid = CourseDraft(name: "另一门课程", schedules: [foreign])
        XCTAssertThrowsError(try repository.save(invalid, semesterID: semesterID, original: nil))
        let context = ModelContext(container)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Course>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CourseSchedule>()), 2)
        XCTAssertEqual(try stored(container), original)
    }
    @MainActor
    func testChangedConflictMustBeConfirmedAgain() async throws {
        let (container, semesterID, original) = try fixture()
        let repository = CourseRepository(container: container)
        try repository.save(original, semesterID: semesterID, original: nil)
        let second = CourseDraft(name: "英语", schedules: [CourseScheduleDraft(weekday: 1, startSection: 1, endSection: 2, activeWeeks: [1, 2])])
        let accepted = CourseConflictChecker.conflicts(for: second, among: [original])
        var changed = original; changed.schedules[0].activeWeeks = [2]
        try repository.save(changed, semesterID: semesterID, original: original)
        XCTAssertThrowsError(try repository.save(second, semesterID: semesterID, original: nil, acceptedConflicts: accepted))
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<Course>()), 1)
    }
    @MainActor
    func testCoursesWithoutSemesterHaveEmptyState() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let model = CoursesViewModel(container: container); model.reload()
        XCTAssertNil(model.page); XCTAssertNil(model.error); XCTAssertTrue(model.filteredCourses.isEmpty)
    }
    @MainActor
    func testReadingAndEditingOtherFieldsPreservesUnknownStoredColor() async throws {
        let (container, semesterID, original) = try fixture()
        let repository = CourseRepository(container: container)
        try repository.save(original, semesterID: semesterID, original: nil)
        let context = ModelContext(container)
        let record = try XCTUnwrap(context.fetch(FetchDescriptor<Course>()).first)
        record.colorRawValue = "future-copper"; try context.save()
        let baseline = try stored(container)
        XCTAssertEqual(baseline.color, .blue)
        XCTAssertEqual(record.colorRawValue, "future-copper")
        var edited = baseline; edited.note = "仅改备注"
        try repository.save(edited, semesterID: semesterID, original: baseline)
        let check = ModelContext(container)
        XCTAssertEqual(try check.fetch(FetchDescriptor<Course>()).first?.colorRawValue, "future-copper")
        edited.color = .teal
        try repository.save(edited, semesterID: semesterID, original: try stored(container))
        XCTAssertEqual(try stored(container).colorKey, "teal")
    }
    @MainActor
    func testLowerLevelTimeSlotRepositoryRejectsReferencedRemoval() async throws {
        let (container, semesterID, original) = try fixture()
        try CourseRepository(container: container).save(original, semesterID: semesterID, original: nil)
        let context = ModelContext(container)
        let semester = try XCTUnwrap(context.fetch(FetchDescriptor<Semester>()).first)
        let repository = SemesterRepository(context: context)
        let reduced = try semester.timeSlots.filter { $0.sectionNumber != 2 }.map { try $0.definition() }
        XCTAssertThrowsError(try repository.updateTimeSlots(reduced, semester: semester))
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<ClassTimeSlot>()), 4)
    }
}
