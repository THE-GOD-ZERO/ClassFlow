import XCTest
import SwiftData
import ClassFlowCore
@testable import ClassFlow

final class TodayViewModelTests: XCTestCase {
    @MainActor
    private func instant(_ key: String, hour: Int, minute: Int = 0) throws -> Date {
        let value = try LocalDay(key: key)
        var components = DateComponents()
        components.year = value.year
        components.month = value.month
        components.day = value.day
        components.hour = hour
        components.minute = minute
        guard let result = LocalDay.calendar(in: LocalDay.schoolTimeZone).date(from: components) else {
            throw DomainError.invalidDate
        }
        return result
    }

    @MainActor
    private func insertSemester(in container: ModelContainer, pendingSunday: Bool = false) throws -> Semester {
        let context = ModelContext(container)
        let term = try Semester(name: "2026-2027 第一学期",
                                startDay: LocalDay(key: "2026-09-07"), totalWeeks: 18, isCurrent: true)
        context.insert(term)
        let math = try Course(name: "高等数学", teacher: "王老师", location: "A301", semester: term)
        context.insert(math)
        context.insert(try CourseSchedule(weekday: .monday, startSection: 1, endSection: 2,
                                         activeWeeks: ActiveWeeks(Array(1...18)), course: math))
        context.insert(try ClassTimeSlot(sectionNumber: 1, startMinute: 480, endMinute: 525, semester: term))
        context.insert(try ClassTimeSlot(sectionNumber: 2, startMinute: 535, endMinute: 580, semester: term))
        if pendingSunday {
            let pending = try OverrideDefinition(day: LocalDay(key: "2026-09-13"), type: .adjustedWorkday,
                title: "调休上班", source: .systemCalendar, isConfirmed: false)
            context.insert(ScheduleOverride(rule: pending, semester: term, syncKey: "calendar:test"))
        }
        try context.save()
        return term
    }

    @MainActor
    func testNoSemesterState() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let now = try instant("2026-09-07", hour: 7)
        let model = TodayViewModel(container: container, nowProvider: { now })
        model.reload()
        guard case let .noSemester(day) = model.state else {
            return XCTFail("Expected no-semester state")
        }
        XCTAssertEqual(day, LocalDay(date: now, timeZone: .autoupdatingCurrent))
    }

    @MainActor
    func testViewModelLoadsResolverResultAndTeacher() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        _ = try insertSemester(in: container)
        let now = try instant("2026-09-07", hour: 7)
        let model = TodayViewModel(container: container, nowProvider: { now })
        model.reload()
        XCTAssertEqual(model.academicWeek, 1)
        XCTAssertEqual(model.nextCourse?.occurrence.courseName, "高等数学")
        XCTAssertEqual(model.nextCourse?.occurrence.teacher, "王老师")
    }

    @MainActor
    func testConfirmingPendingAdjustmentCreatesManualRuleAndDoesNotCopyCourses() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let term = try insertSemester(in: container, pendingSunday: true)
        let now = try instant("2026-09-13", hour: 7)
        let model = TodayViewModel(container: container, nowProvider: { now })
        model.reload()
        XCTAssertEqual(model.dayStatus, .needsConfirmation)
        XCTAssertTrue(model.todayCourses.isEmpty)

        try model.selectReplacementWeekday(.monday)

        XCTAssertEqual(model.dayStatus, .adjustedWorkday(.monday))
        XCTAssertEqual(model.todayCourses.count, 1)
        let context = ModelContext(container)
        let schedules = try context.fetch(FetchDescriptor<CourseSchedule>())
        let courses = try context.fetch(FetchDescriptor<Course>())
        let overrides = try context.fetch(FetchDescriptor<ScheduleOverride>())
        XCTAssertEqual(schedules.count, 1)
        XCTAssertEqual(courses.count, 1)
        XCTAssertEqual(overrides.filter { $0.sourceRawValue == OverrideSource.manual.rawValue }.count, 1)
        XCTAssertEqual(overrides.first { $0.sourceRawValue == OverrideSource.manual.rawValue }?.semester?.id, term.id)
    }

    @MainActor
    func testCreateSemesterSetsItCurrent() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let now = try instant("2026-09-07", hour: 7)
        let model = TodayViewModel(container: container, nowProvider: { now })
        try model.createSemester(name: "秋季学期", startDate: now, totalWeeks: 18)
        let context = ModelContext(container)
        let semesters = try context.fetch(FetchDescriptor<Semester>())
        XCTAssertEqual(semesters.count, 1)
        XCTAssertTrue(semesters[0].isCurrent)
        XCTAssertEqual(semesters[0].startDayKey, LocalDay(date: now, timeZone: .autoupdatingCurrent).key)
        XCTAssertEqual(model.page?.semesterName, "秋季学期")
    }

    @MainActor
    func testMinuteRefreshChangesNextCourseToCurrentAtBoundary() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        _ = try insertSemester(in: container)
        let before = try instant("2026-09-07", hour: 7, minute: 59)
        let model = TodayViewModel(container: container, nowProvider: { before })
        model.reload()
        XCTAssertEqual(model.nextCourse?.status, .next)
        model.refreshClock(at: try instant("2026-09-07", hour: 8))
        XCTAssertEqual(model.currentCourse?.status, .current)
    }

    @MainActor
    func testMidnightRefreshResolvesTheNewDay() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        _ = try insertSemester(in: container)
        let model = TodayViewModel(container: container,
                                   nowProvider: { Date(timeIntervalSinceReferenceDate: 0) })
        model.reload(at: try instant("2026-09-07", hour: 23, minute: 59))
        XCTAssertEqual(model.currentDate?.key, "2026-09-07")
        model.refreshClock(at: try instant("2026-09-08", hour: 0))
        XCTAssertEqual(model.currentDate?.key, "2026-09-08")
        XCTAssertTrue(model.todayCourses.isEmpty)
    }

    @MainActor
    func testLongCountdownUsesHoursAndMinutes() async throws {
        XCTAssertEqual(TodayDisplayText.duration(minutes: 135), "2小时15分钟")
        XCTAssertEqual(TodayDisplayText.duration(minutes: 120), "2小时")
        XCTAssertEqual(TodayDisplayText.duration(minutes: 26), "26分钟")
    }
}
