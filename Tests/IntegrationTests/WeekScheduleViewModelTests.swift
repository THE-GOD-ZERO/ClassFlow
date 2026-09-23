import XCTest
import SwiftData
import ClassFlowCore
@testable import ClassFlow

final class WeekScheduleViewModelTests: XCTestCase {
    @MainActor
    private func instant(_ key: String, hour: Int = 9) throws -> Date {
        let value = try LocalDay(key: key)
        var components = DateComponents()
        components.year = value.year
        components.month = value.month
        components.day = value.day
        components.hour = hour
        guard let result = LocalDay.calendar(in: LocalDay.schoolTimeZone).date(from: components) else {
            throw DomainError.invalidDate
        }
        return result
    }

    @MainActor
    @discardableResult
    private func fixture(_ container: ModelContainer, pendingSunday: Bool = false,
                         holiday: Bool = false) throws -> Semester {
        let context = ModelContext(container)
        let term = try Semester(name: "秋季学期", startDay: LocalDay(key: "2026-09-07"),
            totalWeeks: 18, isCurrent: true)
        context.insert(term)
        let math = try Course(name: "高等数学", teacher: "王老师", location: "A301",
            note: "带好教材", semester: term)
        context.insert(math)
        context.insert(try CourseSchedule(weekday: .monday, startSection: 1, endSection: 2,
            activeWeeks: ActiveWeeks(Array(1...18)), course: math))
        for section in 1...6 {
            context.insert(try ClassTimeSlot(sectionNumber: section,
                startMinute: 480 + (section - 1) * 55, endMinute: 525 + (section - 1) * 55,
                semester: term))
        }
        if pendingSunday {
            let definition = try OverrideDefinition(day: LocalDay(key: "2026-09-27"),
                type: .adjustedWorkday, title: "调休上班", source: .systemCalendar,
                isConfirmed: false)
            context.insert(ScheduleOverride(rule: definition, semester: term, syncKey: "pending"))
        }
        if holiday {
            let definition = try OverrideDefinition(day: LocalDay(key: "2026-09-21"),
                type: .holiday, title: "校庆日", source: .schoolCalendar, isConfirmed: true)
            context.insert(ScheduleOverride(rule: definition, semester: term, syncKey: "holiday"))
        }
        try context.save()
        return term
    }

    @MainActor
    func testNoSemesterState() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let model = WeekScheduleViewModel(container: container,
            nowProvider: { Date(timeIntervalSinceReferenceDate: 0) })
        model.reload(at: try instant("2026-09-21"))
        guard case .noSemester = model.state else { return XCTFail("Expected no semester") }
    }

    @MainActor
    func testInitialLoadSelectsRealTeachingWeek() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        try fixture(container)
        let now = try instant("2026-09-21")
        let model = WeekScheduleViewModel(container: container, nowProvider: { now })
        model.reload()
        XCTAssertEqual(model.page?.snapshot.weekNumber, 3)
        XCTAssertEqual(model.page?.snapshot.startDate.key, "2026-09-21")
        XCTAssertEqual(model.page?.snapshot.days.count, 7)
        XCTAssertEqual(model.page?.layoutItems.first?.occurrence.note, "带好教材")
        XCTAssertEqual(model.page?.layoutItems.first?.occurrence.activeWeeks.count, 18)
    }

    @MainActor
    func testPreviousAndNextWeekRegenerateOnlySelectedWeek() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        try fixture(container)
        let now = try instant("2026-09-21")
        let model = WeekScheduleViewModel(container: container, nowProvider: { now })
        model.reload()
        model.showNextWeek()
        XCTAssertEqual(model.page?.snapshot.weekNumber, 4)
        XCTAssertEqual(model.page?.snapshot.startDate.key, "2026-09-28")
        model.showPreviousWeek()
        XCTAssertEqual(model.page?.snapshot.weekNumber, 3)
    }

    @MainActor
    func testReturnToCurrentWeek() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        try fixture(container)
        let now = try instant("2026-09-21")
        let model = WeekScheduleViewModel(container: container, nowProvider: { now })
        model.reload()
        model.showNextWeek()
        model.showNextWeek()
        model.showCurrentWeek()
        XCTAssertEqual(model.page?.snapshot.weekNumber, 3)
        XCTAssertTrue(model.page?.snapshot.isCurrentWeek == true)
    }

    @MainActor
    func testWeekNavigationStopsAtSemesterBounds() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        try fixture(container)
        let now = try instant("2026-09-07")
        let model = WeekScheduleViewModel(container: container, nowProvider: { now })
        model.reload()
        model.showPreviousWeek()
        XCTAssertEqual(model.page?.snapshot.weekNumber, 1)
    }

    @MainActor
    func testDateChangeFollowsTodayOnlyWhenUserWasViewingTodayTarget() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        try fixture(container)
        let model = WeekScheduleViewModel(container: container,
            nowProvider: { Date(timeIntervalSinceReferenceDate: 0) })
        model.reload(at: try instant("2026-09-27"))
        XCTAssertEqual(model.page?.snapshot.weekNumber, 3)

        model.reload(at: try instant("2026-09-28"))
        XCTAssertEqual(model.page?.snapshot.weekNumber, 4)

        model.showPreviousWeek()
        XCTAssertEqual(model.page?.snapshot.weekNumber, 3)
        model.reload(at: try instant("2026-10-05"))
        XCTAssertEqual(model.page?.snapshot.weekNumber, 3)
        XCTAssertEqual(model.page?.todayTargetWeek, 5)
    }

    @MainActor
    func testPendingAdjustmentIsEmptyUntilCommonServiceConfirmsIt() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        try fixture(container, pendingSunday: true)
        let now = try instant("2026-09-21")
        let model = WeekScheduleViewModel(container: container, nowProvider: { now })
        model.reload()
        let pending = try XCTUnwrap(model.page?.snapshot.days.last)
        XCTAssertEqual(pending.dayStatus, .needsConfirmation)
        XCTAssertTrue(pending.courses.isEmpty)

        try model.selectReplacementWeekday(.monday, for: pending)

        let sunday = try XCTUnwrap(model.page?.snapshot.days.last)
        XCTAssertEqual(sunday.dayStatus, .adjustedWorkday(.monday))
        XCTAssertEqual(sunday.courses.count, 1)
        let context = ModelContext(container)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Course>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CourseSchedule>()), 1)
    }

    @MainActor
    func testHolidayColumnHasNoLayoutItems() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        try fixture(container, holiday: true)
        let now = try instant("2026-09-21")
        let model = WeekScheduleViewModel(container: container, nowProvider: { now })
        model.reload()
        XCTAssertEqual(model.page?.snapshot.days[0].dayStatus, .holiday)
        XCTAssertFalse(model.page?.layoutItems.contains(where: { $0.dayColumnIndex == 0 }) == true)
    }
}
