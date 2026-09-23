import XCTest
import ClassFlowCore

final class WeekScheduleSnapshotTests: XCTestCase {
    private func week(_ number: Int = 1, semester term: SemesterDefinition? = nil,
                      courses: [CourseDefinition] = [], overrides: [OverrideDefinition] = [],
                      currentDate: LocalDay? = nil) throws -> WeekScheduleSnapshot {
        let activeTerm: SemesterDefinition
        if let term { activeTerm = term } else { activeTerm = try semester() }
        let monday = try AcademicCalendarService().firstMonday(of: activeTerm)
            .adding(days: (number - 1) * 7)
        let resolved = try (0..<7).map { offset in
            try ScheduleResolver().resolve(day: monday.adding(days: offset), semester: activeTerm,
                courses: courses, timeSlots: slots(), overrides: overrides)
        }
        return try WeekScheduleSnapshotBuilder().make(weekNumber: number,
            resolvedDays: resolved, currentDate: currentDate)
    }

    func testWeekStartAndEndAreMondayAndSunday() throws {
        let result = try week(3)
        XCTAssertEqual(result.startDate.key, "2026-09-21")
        XCTAssertEqual(result.endDate.key, "2026-09-27")
    }

    func testSevenWeekdaysMatchDates() throws {
        let result = try week(1)
        XCTAssertEqual(result.days.map(\.realWeekday), Weekday.allCases)
        XCTAssertEqual(result.days.map(\.date.key), ["2026-09-07", "2026-09-08", "2026-09-09",
            "2026-09-10", "2026-09-11", "2026-09-12", "2026-09-13"])
    }

    func testPreviousWeekIsClampedAtFirstWeek() {
        XCTAssertEqual(WeekScheduleNavigation().previous(from: 1, totalWeeks: 18), 1)
        XCTAssertEqual(WeekScheduleNavigation().previous(from: 8, totalWeeks: 18), 7)
    }

    func testNextWeekIsClampedAtLastWeek() {
        XCTAssertEqual(WeekScheduleNavigation().next(from: 18, totalWeeks: 18), 18)
        XCTAssertEqual(WeekScheduleNavigation().next(from: 8, totalWeeks: 18), 9)
    }

    func testCurrentWeekNavigationUsesRealDate() throws {
        XCTAssertEqual(try WeekScheduleNavigation().initialWeek(for: day("2026-10-01"),
            semester: semester()), 4)
    }

    func testBeforeAndAfterSemesterNavigationClamps() throws {
        let term = try semester(weeks: 2)
        XCTAssertEqual(try WeekScheduleNavigation().initialWeek(for: day("2026-09-01"), semester: term), 1)
        XCTAssertEqual(try WeekScheduleNavigation().initialWeek(for: day("2026-10-01"), semester: term), 2)
    }

    func testActiveWeeksUseViewedWeek() throws {
        let weekly = try course(.monday, weeks: [4])
        XCTAssertTrue(try week(3, courses: [weekly]).days[0].courses.isEmpty)
        XCTAssertEqual(try week(4, courses: [weekly]).days[0].courses.count, 1)
    }

    func testOddWeekFiltering() throws {
        let odd = try course(.tuesday, weeks: Array(stride(from: 1, through: 17, by: 2)))
        XCTAssertEqual(try week(3, courses: [odd]).days[1].courses.count, 1)
        XCTAssertTrue(try week(4, courses: [odd]).days[1].courses.isEmpty)
    }

    func testEvenWeekFiltering() throws {
        let even = try course(.wednesday, weeks: Array(stride(from: 2, through: 18, by: 2)))
        XCTAssertTrue(try week(3, courses: [even]).days[2].courses.isEmpty)
        XCTAssertEqual(try week(4, courses: [even]).days[2].courses.count, 1)
    }

    func testCustomWeekFiltering() throws {
        let custom = try course(.friday, weeks: [1, 3, 8, 12])
        XCTAssertEqual(try week(3, courses: [custom]).days[4].courses.count, 1)
        XCTAssertTrue(try week(4, courses: [custom]).days[4].courses.isEmpty)
    }

    func testHolidaySuppressesOrdinaryCourses() throws {
        let holiday = try rule("2026-09-07", type: .holiday)
        let result = try week(1, courses: [course(.monday)], overrides: [holiday])
        XCTAssertEqual(result.days[0].dayStatus, .holiday)
        XCTAssertTrue(result.days[0].courses.isEmpty)
    }

    func testAdjustedSundayUsesMondayCourses() throws {
        let adjustment = try rule("2026-09-13", weekday: .monday)
        let result = try week(1, courses: [course(.monday)], overrides: [adjustment])
        XCTAssertEqual(result.days[6].realWeekday, .sunday)
        XCTAssertEqual(result.days[6].effectiveWeekday, .monday)
        XCTAssertEqual(result.days[6].courses.count, 1)
    }

    func testAdjustedSaturdayUsesFridayCourses() throws {
        let adjustment = try rule("2026-09-12", weekday: .friday)
        let result = try week(1, courses: [course(.friday)], overrides: [adjustment])
        XCTAssertEqual(result.days[5].dayStatus, .adjustedWorkday(.friday))
        XCTAssertEqual(result.days[5].courses.first?.courseName, "高等数学")
    }

    func testUnconfirmedAdjustmentDoesNotGuessCourses() throws {
        let pending = try rule("2026-09-13", weekday: nil, confirmed: false)
        let result = try week(1, courses: [course(.sunday)], overrides: [pending])
        XCTAssertEqual(result.days[6].dayStatus, .needsConfirmation)
        XCTAssertTrue(result.days[6].courses.isEmpty)
    }

    func testManualOverrideWinsInsideWeekSnapshot() throws {
        let system = try rule("2026-09-13", weekday: .monday)
        let manual = try rule("2026-09-13", weekday: .friday, source: .manual,
                              updatedAt: Date(timeIntervalSince1970: 10))
        let result = try week(1, courses: [course(.friday)], overrides: [system, manual])
        XCTAssertEqual(result.days[6].effectiveWeekday, .friday)
    }

    func testSchoolRuleWinsNationalHoliday() throws {
        let holiday = try rule("2026-09-12", type: .holiday)
        let school = try rule("2026-09-12", type: .schoolOverride, weekday: .friday,
                              source: .schoolCalendar)
        let result = try week(1, courses: [course(.friday)], overrides: [holiday, school])
        XCTAssertEqual(result.days[5].dayStatus, .schoolOverride(.friday))
        XCTAssertEqual(result.days[5].courses.count, 1)
    }

    func testReplacementWeekdayDoesNotChangeAcademicWeek() throws {
        let mapped = try rule("2026-09-20", weekday: .monday)
        let result = try week(2, courses: [course(.monday, weeks: [2])], overrides: [mapped])
        XCTAssertEqual(result.days[6].academicWeek, 2)
        XCTAssertEqual(result.days[6].effectiveWeekday, .monday)
        XCTAssertEqual(result.days[6].courses.count, 1)
    }

    func testWeekCanCrossMonth() throws {
        let result = try week(4)
        XCTAssertEqual(result.startDate.key, "2026-09-28")
        XCTAssertEqual(result.endDate.key, "2026-10-04")
    }

    func testWeekCanCrossYear() throws {
        let term = try semester(start: "2026-12-28", weeks: 2)
        let result = try week(1, semester: term)
        XCTAssertEqual(result.startDate.key, "2026-12-28")
        XCTAssertEqual(result.endDate.key, "2027-01-03")
    }

    func testFirstAndLastSemesterWeek() throws {
        let term = try semester(weeks: 2)
        XCTAssertEqual(try week(1, semester: term).days.map(\.academicWeek), Array(repeating: 1, count: 7))
        XCTAssertEqual(try week(2, semester: term).days.map(\.academicWeek), Array(repeating: 2, count: 7))
    }

    func testFirstWeekSupportsMidweekSemesterStart() throws {
        let term = try semester(start: "2026-09-09", weeks: 2)
        let result = try week(1, semester: term)
        XCTAssertEqual(result.startDate.key, "2026-09-07")
        XCTAssertEqual(result.days[0].academicPosition, .beforeSemester)
        XCTAssertEqual(result.days[1].academicPosition, .beforeSemester)
        XCTAssertEqual(result.days[2].academicWeek, 1)
    }

    func testBuilderRejectsDatesOutsideRequestedAcademicWeek() throws {
        let term = try semester(weeks: 2)
        let monday = try AcademicCalendarService().firstMonday(of: term).adding(days: 14)
        let resolved = try (0..<7).map {
            try ScheduleResolver().resolve(day: monday.adding(days: $0), semester: term,
                courses: [], timeSlots: [], overrides: [])
        }
        XCTAssertThrowsError(try WeekScheduleSnapshotBuilder().make(weekNumber: 2,
            resolvedDays: resolved, currentDate: nil))
    }
}
