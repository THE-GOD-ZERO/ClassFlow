import XCTest
@testable import ClassFlowCore

final class ScheduleResolverTests: XCTestCase {
    private func resolve(_ date: String, rules: [OverrideDefinition] = [],
                         courses: [CourseDefinition]? = nil) throws -> ResolvedDay {
        try ScheduleResolver().resolve(day: day(date), semester: semester(),
            courses: courses ?? [course(.monday), course(.friday), course(.sunday)],
            timeSlots: slots(), overrides: rules)
    }

    func testOrdinaryMondayAndSunday() throws {
        XCTAssertEqual(try resolve("2026-09-07").courses.count, 1)
        let sunday = try resolve("2026-09-13")
        XCTAssertEqual(sunday.effectiveWeekday, .sunday)
        XCTAssertEqual(sunday.courses.count, 1)
    }

    func testEmptyCourseAndNoSemester() throws {
        XCTAssertTrue(try resolve("2026-09-07", courses: []).courses.isEmpty)
        let result = try ScheduleResolver().resolve(day: day("2026-09-07"), semester: nil,
                                                    courses: [course()], timeSlots: slots(), overrides: [])
        XCTAssertEqual(result.academicPosition, .noSemester)
        XCTAssertTrue(result.courses.isEmpty)
    }

    func testHolidaySuppressesOrdinaryCourses() throws {
        let result = try resolve("2026-09-07", rules: [rule("2026-09-07", type: .holiday)])
        XCTAssertTrue(result.isHoliday)
        XCTAssertTrue(result.courses.isEmpty)
    }

    func testSundayMappedToMondayKeepsActualDate() throws {
        let result = try resolve("2026-09-13", rules: [rule("2026-09-13", weekday: .monday)])
        XCTAssertEqual(result.day.weekday, .sunday)
        XCTAssertEqual(result.effectiveWeekday, .monday)
        XCTAssertEqual(result.courses.count, 1)
        XCTAssertEqual(result.courses.first?.day, try day("2026-09-13"))
    }

    func testSaturdayMappedToFriday() throws {
        let result = try resolve("2026-10-10", rules: [rule("2026-10-10", weekday: .friday)])
        XCTAssertEqual(result.day.weekday, .saturday)
        XCTAssertEqual(result.effectiveWeekday, .friday)
        XCTAssertEqual(result.courses.count, 1)
    }

    func testUnknownWorkdayKeepsProvisionalOrdinarySchedule() throws {
        let result = try resolve("2026-09-13", rules: [rule("2026-09-13", confirmed: false)])
        XCTAssertTrue(result.needsConfirmation)
        XCTAssertEqual(result.effectiveWeekday, .sunday)
        XCTAssertEqual(result.courses.count, 1)
    }

    func testUnknownWorkdayDoesNotDisappearUnderHoliday() throws {
        let result = try resolve("2026-09-13", rules: [
            rule("2026-09-13", type: .holiday), rule("2026-09-13", confirmed: false)
        ])
        XCTAssertTrue(result.needsConfirmation)
        XCTAssertFalse(result.isHoliday)
    }

    func testManualRuleOverridesSchoolAndSystem() throws {
        let result = try resolve("2026-09-13", rules: [
            rule("2026-09-13", type: .holiday),
            rule("2026-09-13", type: .schoolOverride, weekday: .monday, source: .schoolCalendar),
            rule("2026-09-13", weekday: .friday, source: .manual)
        ])
        XCTAssertEqual(result.effectiveWeekday, .friday)
        XCTAssertEqual(result.appliedOverride?.source, .manual)
    }

    func testSchoolNormalClassOverridesNationalHoliday() throws {
        let result = try resolve("2026-09-07", rules: [
            rule("2026-09-07", type: .holiday),
            rule("2026-09-07", type: .schoolOverride, source: .schoolCalendar)
        ])
        XCTAssertFalse(result.isHoliday)
        XCTAssertEqual(result.courses.count, 1)
    }

    func testConfirmedMappingOutranksSystemHoliday() throws {
        let result = try resolve("2026-09-13", rules: [
            rule("2026-09-13", type: .holiday), rule("2026-09-13", weekday: .monday)
        ])
        XCTAssertEqual(result.effectiveWeekday, .monday)
        XCTAssertFalse(result.isHoliday)
    }

    func testCrossWeekMappingUsesActualAcademicWeek() throws {
        // 9/20 is week 2; mapping Sunday to Monday must not select week 3 or week 1.
        let result = try resolve("2026-09-20", rules: [rule("2026-09-20", weekday: .monday)],
                                 courses: [course(.monday, weeks: [2])])
        XCTAssertEqual(result.academicPosition, .week(2))
        XCTAssertEqual(result.courses.count, 1)
        XCTAssertTrue(try resolve("2026-09-20", rules: [rule("2026-09-20", weekday: .monday)],
                                 courses: [course(.monday, weeks: [1, 3])]).courses.isEmpty)
    }

    func testOutsideSemesterOverrideDoesNotCreateCourses() throws {
        for date in ["2026-09-06", "2027-01-17"] {
            XCTAssertTrue(try resolve(date, rules: [rule(date, weekday: .monday)]).courses.isEmpty)
        }
    }

    func testSamePriorityContradictionIsReportedDeterministically() throws {
        let a = try rule("2026-09-13", weekday: .monday, updatedAt: Date(timeIntervalSince1970: 1))
        let b = try rule("2026-09-13", weekday: .friday, updatedAt: Date(timeIntervalSince1970: 2))
        let result = try resolve("2026-09-13", rules: [a, b])
        XCTAssertEqual(result.effectiveWeekday, .friday)
        XCTAssertTrue(result.issues.contains(.conflictingOverrides))
    }

    func testMultipleSectionsUseEntireTimeRange() throws {
        let occurrence = try XCTUnwrap(resolve("2026-09-07").courses.first)
        XCTAssertEqual(occurrence.end.timeIntervalSince(occurrence.start), 100 * 60)
        XCTAssertEqual(occurrence.location, "A301")
    }

    func testOverlapsReportedButTouchingIntervalsAllowed() throws {
        let overlapping = try resolve("2026-09-07", courses: [course(), course(start: 2, end: 3)])
        XCTAssertEqual(overlapping.conflicts.count, 1)
        let separated = try resolve("2026-09-07", courses: [course(), course(start: 3, end: 3)])
        XCTAssertTrue(separated.conflicts.isEmpty)
    }

    func testMissingSectionReportedWithoutCrash() throws {
        let result = try ScheduleResolver().resolve(day: day("2026-09-07"), semester: semester(),
            courses: [course()], timeSlots: [], overrides: [])
        XCTAssertEqual(result.issues.count, 1)
        XCTAssertTrue(result.courses.isEmpty)
    }

    func testDuplicateAndOverlappingSlotsRejectedBeforeDictionaryCreation() throws {
        let slot = try TimeSlotDefinition(sectionNumber: 1, startMinute: 480, endMinute: 525)
        XCTAssertThrowsError(try TimeSlotDefinition.validate([slot, slot]))
        XCTAssertThrowsError(try TimeSlotDefinition.validate([slot,
            TimeSlotDefinition(sectionNumber: 2, startMinute: 500, endMinute: 540)]))
    }

    func testChangedTimeSlotsRecomputeOccurrenceWithoutChangingScheduleID() throws {
        let courses = try [course()]
        let resolver = ScheduleResolver()
        let before = try resolver.resolve(day: day("2026-09-07"), semester: semester(), courses: courses,
                                          timeSlots: slots(), overrides: [])
        let after = try resolver.resolve(day: day("2026-09-07"), semester: semester(), courses: courses,
            timeSlots: [TimeSlotDefinition(sectionNumber: 1, startMinute: 540, endMinute: 585),
                        TimeSlotDefinition(sectionNumber: 2, startMinute: 595, endMinute: 640)], overrides: [])
        XCTAssertEqual(before.courses.first?.id, after.courses.first?.id)
        XCTAssertEqual(try XCTUnwrap(after.courses.first).start.timeIntervalSince(XCTUnwrap(before.courses.first).start), 3600)
    }

    func testNonexistentDSTClassTimeIsReported() throws {
        let result = try ScheduleResolver().resolve(day: day("2026-03-08"),
            semester: semester(start: "2026-03-02", zone: "America/New_York"),
            courses: [course(.sunday, start: 1, end: 1)],
            timeSlots: [TimeSlotDefinition(sectionNumber: 1, startMinute: 150, endMinute: 210)], overrides: [])
        XCTAssertTrue(result.courses.isEmpty)
        XCTAssertEqual(result.issues.count, 1)
    }

    func testConfirmedWorkdayMustHaveMapping() throws {
        XCTAssertThrowsError(try rule("2026-09-13", confirmed: true))
    }

    func testExactlyTouchingClassesDoNotConflict() throws {
        let result = try ScheduleResolver().resolve(day: day("2026-09-07"), semester: semester(),
            courses: [course(start: 1, end: 1), course(start: 2, end: 2)],
            timeSlots: [TimeSlotDefinition(sectionNumber: 1, startMinute: 480, endMinute: 525),
                        TimeSlotDefinition(sectionNumber: 2, startMinute: 525, endMinute: 570)], overrides: [])
        XCTAssertEqual(result.courses.count, 2)
        XCTAssertTrue(result.conflicts.isEmpty)
    }
}
