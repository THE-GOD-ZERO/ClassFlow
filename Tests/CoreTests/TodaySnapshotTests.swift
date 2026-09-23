import XCTest
@testable import ClassFlowCore

final class TodaySnapshotTests: XCTestCase {
    private let builder = TodaySnapshotBuilder()

    private func fullSlots() throws -> [TimeSlotDefinition] {
        try [
            TimeSlotDefinition(sectionNumber: 1, startMinute: 480, endMinute: 525),
            TimeSlotDefinition(sectionNumber: 2, startMinute: 535, endMinute: 580),
            TimeSlotDefinition(sectionNumber: 3, startMinute: 600, endMinute: 645),
            TimeSlotDefinition(sectionNumber: 4, startMinute: 655, endMinute: 700),
            TimeSlotDefinition(sectionNumber: 5, startMinute: 840, endMinute: 885),
            TimeSlotDefinition(sectionNumber: 6, startMinute: 895, endMinute: 940)
        ]
    }

    private func instant(_ date: String, hour: Int, minute: Int = 0,
                         zone: TimeZone = LocalDay.schoolTimeZone) throws -> Date {
        var components = DateComponents()
        let value = try day(date)
        components.year = value.year
        components.month = value.month
        components.day = value.day
        components.hour = hour
        components.minute = minute
        guard let result = LocalDay.calendar(in: zone).date(from: components) else {
            throw DomainError.invalidDate
        }
        return result
    }

    private func resolve(_ date: String = "2026-09-07", courses: [CourseDefinition],
                         rules: [OverrideDefinition] = [], term: SemesterDefinition? = nil) throws -> ResolvedDay {
        try ScheduleResolver().resolve(day: day(date), semester: term ?? semester(),
                                       courses: courses, timeSlots: fullSlots(), overrides: rules)
    }

    func testTodayCoursesAreSortedByStartTime() throws {
        let result = try resolve(courses: [
            course(start: 5, end: 6, name: "下午"),
            course(start: 3, end: 4, name: "上午二"),
            course(start: 1, end: 2, name: "上午一")
        ])
        let snapshot = builder.make(from: result, now: try instant("2026-09-07", hour: 7))
        XCTAssertEqual(snapshot.courses.map(\.occurrence.courseName), ["上午一", "上午二", "下午"])
    }

    func testPastCourseIsFinished() throws {
        let snapshot = builder.make(from: try resolve(courses: [course()]),
                                    now: try instant("2026-09-07", hour: 9, minute: 41))
        XCTAssertEqual(snapshot.courses.first?.status, .finished)
    }

    func testCurrentCourseIsRecognized() throws {
        let snapshot = builder.make(from: try resolve(courses: [course()]),
                                    now: try instant("2026-09-07", hour: 9))
        XCTAssertEqual(snapshot.currentCourse?.occurrence.courseName, "高等数学")
        XCTAssertEqual(snapshot.courses.first?.status, .current)
    }

    func testNextCourseIsRecognized() throws {
        let snapshot = builder.make(from: try resolve(courses: [
            course(start: 1, end: 2, name: "早课"), course(start: 3, end: 4, name: "下一节")
        ]), now: try instant("2026-09-07", hour: 9, minute: 50))
        XCTAssertEqual(snapshot.nextCourse?.occurrence.courseName, "下一节")
        XCTAssertEqual(snapshot.nextCourse?.status, .next)
    }

    func testNextCourseExistsWhileAnotherCourseIsCurrent() throws {
        let snapshot = builder.make(from: try resolve(courses: [
            course(start: 1, end: 2, name: "当前"), course(start: 3, end: 4, name: "下一节")
        ]), now: try instant("2026-09-07", hour: 9))
        XCTAssertEqual(snapshot.currentCourse?.occurrence.courseName, "当前")
        XCTAssertEqual(snapshot.nextCourse?.occurrence.courseName, "下一节")
    }

    func testAllCoursesEndedHasNoNextCourse() throws {
        let snapshot = builder.make(from: try resolve(courses: [course()]),
                                    now: try instant("2026-09-07", hour: 18))
        XCTAssertNil(snapshot.currentCourse)
        XCTAssertNil(snapshot.nextCourse)
        XCTAssertNil(snapshot.countdown)
    }

    func testCourseStartBoundaryIsCurrent() throws {
        let snapshot = builder.make(from: try resolve(courses: [course()]),
                                    now: try instant("2026-09-07", hour: 8))
        XCTAssertEqual(snapshot.currentCourse?.status, .current)
        XCTAssertEqual(snapshot.countdown, .endsIn(minutes: 100))
    }

    func testCourseEndBoundaryIsFinished() throws {
        let snapshot = builder.make(from: try resolve(courses: [course()]),
                                    now: try instant("2026-09-07", hour: 9, minute: 40))
        XCTAssertEqual(snapshot.courses.first?.status, .finished)
        XCTAssertNil(snapshot.currentCourse)
    }

    func testCountdownRoundsUpToTheNextMinute() throws {
        let result = try resolve(courses: [course()])
        let now = try instant("2026-09-07", hour: 7, minute: 33).addingTimeInterval(20)
        XCTAssertEqual(builder.make(from: result, now: now).countdown, .startsIn(minutes: 27))
    }

    func testCrossSectionCourseUsesFirstStartAndLastEnd() throws {
        let snapshot = builder.make(from: try resolve(courses: [course(start: 1, end: 4)]),
                                    now: try instant("2026-09-07", hour: 7))
        let value = try XCTUnwrap(snapshot.nextCourse?.occurrence)
        XCTAssertEqual(value.end.timeIntervalSince(value.start), 220 * 60)
        XCTAssertEqual(value.startSection, 1)
        XCTAssertEqual(value.endSection, 4)
    }

    func testTeacherFlowsIntoTodayOccurrence() throws {
        let snapshot = builder.make(from: try resolve(courses: [course(teacher: "王老师")]),
                                    now: try instant("2026-09-07", hour: 7))
        XCTAssertEqual(snapshot.nextCourse?.occurrence.teacher, "王老师")
    }

    func testSundayAdjustmentUsesMondayCourses() throws {
        let result = try resolve("2026-09-13", courses: [course(.monday)],
                                 rules: [rule("2026-09-13", weekday: .monday)])
        let snapshot = builder.make(from: result, now: try instant("2026-09-13", hour: 7))
        XCTAssertEqual(snapshot.day.weekday, .sunday)
        XCTAssertEqual(snapshot.effectiveWeekday, .monday)
        XCTAssertEqual(snapshot.dayKind, .adjustedWorkday(.monday))
        XCTAssertEqual(snapshot.courses.count, 1)
    }

    func testSaturdayAdjustmentUsesFridayCourses() throws {
        let result = try resolve("2026-10-10", courses: [course(.friday)],
                                 rules: [rule("2026-10-10", weekday: .friday)])
        let snapshot = builder.make(from: result, now: try instant("2026-10-10", hour: 7))
        XCTAssertEqual(snapshot.effectiveWeekday, .friday)
        XCTAssertEqual(snapshot.dayKind, .adjustedWorkday(.friday))
        XCTAssertEqual(snapshot.courses.count, 1)
    }

    func testHolidayHasNoCourses() throws {
        let result = try resolve(courses: [course()], rules: [rule("2026-09-07", type: .holiday)])
        let snapshot = builder.make(from: result, now: try instant("2026-09-07", hour: 7))
        XCTAssertEqual(snapshot.dayKind, .holiday)
        XCTAssertTrue(snapshot.courses.isEmpty)
    }

    func testSchoolOverrideWinsAndUsesFriday() throws {
        let result = try resolve("2026-09-13", courses: [course(.friday)], rules: [
            rule("2026-09-13", type: .holiday),
            rule("2026-09-13", type: .schoolOverride, weekday: .friday, source: .schoolCalendar)
        ])
        let snapshot = builder.make(from: result, now: try instant("2026-09-13", hour: 7))
        XCTAssertEqual(snapshot.dayKind, .schoolOverride(.friday))
        XCTAssertEqual(snapshot.courses.count, 1)
    }

    func testManualOverrideWinsOverSchoolRule() throws {
        let result = try resolve("2026-09-13", courses: [course(.monday), course(.friday)], rules: [
            rule("2026-09-13", type: .schoolOverride, weekday: .friday, source: .schoolCalendar),
            rule("2026-09-13", weekday: .monday, source: .manual)
        ])
        let snapshot = builder.make(from: result, now: try instant("2026-09-13", hour: 7))
        XCTAssertEqual(snapshot.effectiveWeekday, .monday)
        XCTAssertEqual(snapshot.courses.count, 1)
        XCTAssertEqual(snapshot.appliedOverride?.source, .manual)
    }

    func testUnconfirmedAdjustmentDoesNotExposeGuessedCourses() throws {
        let result = try resolve("2026-09-13", courses: [course(.sunday)],
                                 rules: [rule("2026-09-13", confirmed: false)])
        XCTAssertEqual(result.courses.count, 1, "Resolver retains a provisional actual-weekday preview")
        let snapshot = builder.make(from: result, now: try instant("2026-09-13", hour: 7))
        XCTAssertEqual(snapshot.dayKind, .needsConfirmation)
        XCTAssertTrue(snapshot.courses.isEmpty)
        XCTAssertNil(snapshot.currentCourse)
        XCTAssertNil(snapshot.nextCourse)
    }

    func testTeachingWeekFiltersCourses() throws {
        let snapshot = builder.make(from: try resolve("2026-09-14", courses: [
            course(.monday, weeks: [1], name: "第一周"),
            course(.monday, weeks: [2], name: "第二周")
        ]), now: try instant("2026-09-14", hour: 7))
        XCTAssertEqual(snapshot.academicPosition, .week(2))
        XCTAssertEqual(snapshot.courses.map(\.occurrence.courseName), ["第二周"])
    }

    func testOddEvenWeekFiltering() throws {
        let odd = try ActiveWeeks.odd(1...18).sorted
        let even = try ActiveWeeks.even(1...18).sorted
        let snapshot = builder.make(from: try resolve("2026-09-14", courses: [
            course(.monday, weeks: odd, name: "单周课"),
            course(.monday, weeks: even, name: "双周课")
        ]), now: try instant("2026-09-14", hour: 7))
        XCTAssertEqual(snapshot.courses.map(\.occurrence.courseName), ["双周课"])
    }

    func testBeforeSemesterHasNoCourses() throws {
        let result = try resolve("2026-09-06", courses: [course(.sunday)])
        let snapshot = builder.make(from: result, now: try instant("2026-09-06", hour: 7))
        XCTAssertEqual(snapshot.academicPosition, .beforeSemester)
        XCTAssertTrue(snapshot.courses.isEmpty)
    }

    func testAfterSemesterHasNoCourses() throws {
        let result = try resolve("2027-01-11", courses: [course(.monday)])
        let snapshot = builder.make(from: result, now: try instant("2027-01-11", hour: 7))
        XCTAssertEqual(snapshot.academicPosition, .afterSemester)
        XCTAssertTrue(snapshot.courses.isEmpty)
    }

    func testNoSemesterIsRepresentedWithoutCourses() throws {
        let result = try ScheduleResolver().resolve(day: day("2026-09-07"), semester: nil,
                                                    courses: [], timeSlots: [], overrides: [])
        let snapshot = builder.make(from: result, now: try instant("2026-09-07", hour: 7))
        XCTAssertEqual(snapshot.academicPosition, .noSemester)
        XCTAssertTrue(snapshot.courses.isEmpty)
    }

    func testNoCoursesHasNoPrimaryCourse() throws {
        let snapshot = builder.make(from: try resolve(courses: []),
                                    now: try instant("2026-09-07", hour: 7))
        XCTAssertTrue(snapshot.courses.isEmpty)
        XCTAssertNil(snapshot.currentCourse)
        XCTAssertNil(snapshot.nextCourse)
    }
}
