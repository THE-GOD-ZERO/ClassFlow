import XCTest
@testable import ClassFlowCore

final class CalendarEventParserTests: XCTestCase {
    private func parse(_ title: String, notes: String = "", role: CalendarRole = .holidays,
                       allDay: Bool = true, start: String = "2026-10-01",
                       end: String = "2026-10-02") throws -> [ImportedOverride] {
        let event = try CalendarEventSnapshot(calendarID: "holidays", eventID: "event-1", title: title,
            notes: notes, start: day(start).start(in: LocalDay.schoolTimeZone),
            end: day(end).start(in: LocalDay.schoolTimeZone), isAllDay: allDay,
            timeZoneID: "Asia/Shanghai", role: role)
        return try CalendarEventParser().parse(event,
            in: DayRange(start: day("2026-09-07"), endExclusive: day("2027-01-11")),
            schoolTimeZone: LocalDay.schoolTimeZone)
    }

    func testSevenNamedHolidays() throws {
        for name in ["元旦", "春节", "清明节", "劳动节", "端午节", "中秋节", "国庆节"] {
            XCTAssertEqual(try parse(name).first?.rule.type, .holiday)
        }
    }

    func testExclusiveEndOfMultidayHoliday() throws {
        let results = try parse("国庆节", end: "2026-10-08")
        XCTAssertEqual(results.count, 7)
        XCTAssertEqual(results.last?.rule.day.key, "2026-10-07")
        XCTAssertEqual(Set(results.map(\.syncKey)).count, 7)
    }

    func testUnknownWorkdayNeverInventsWeekday() throws {
        for title in ["上班", "调休上班", "补班", "调休"] {
            let imported = try XCTUnwrap(parse(title).first)
            XCTAssertNil(imported.rule.replacementWeekday)
            XCTAssertFalse(imported.rule.isConfirmed)
        }
    }

    func testExplicitSchoolMappings() throws {
        for (title, weekday) in [("10月10日调课，按星期一课表上课", Weekday.monday),
                                 ("执行星期五课表", .friday), ("补周三课程", .wednesday)] {
            let imported = try XCTUnwrap(parse(title, role: .school, start: "2026-10-10", end: "2026-10-11").first)
            XCTAssertEqual(imported.rule.replacementWeekday, weekday)
            XCTAssertEqual(imported.rule.source, .schoolCalendar)
            XCTAssertTrue(imported.rule.isConfirmed)
        }
    }

    func testNationalCalendarCannotAssertSchoolMapping() throws {
        XCTAssertNil(try parse("调休，按周一课表上课").first?.rule.replacementWeekday)
    }

    func testAmbiguousSchoolTextRemainsPending() throws {
        let result = try XCTUnwrap(parse("按周一课表上课，执行周五课表", role: .school).first)
        XCTAssertFalse(result.rule.isConfirmed)
        XCTAssertNil(result.rule.replacementWeekday)
    }

    func testNegationAndUnrelatedKeywordsDoNotCancelClasses() throws {
        for title in ["国庆节活动", "午休", "退休讲座", "取消按周一课表上课", "不上班", "可能按周一课表上课", "周一开会"] {
            XCTAssertTrue(try parse(title, role: .school).isEmpty, title)
        }
    }

    func testTimedEventsNotTreatedAsWholeDayHolidays() throws {
        XCTAssertTrue(try parse("国庆节", allDay: false).isEmpty)
    }

    func testStableIdentityAndChangedSourceFingerprint() throws {
        let a = try XCTUnwrap(parse("调休上班").first)
        let b = try XCTUnwrap(parse("调休上班").first)
        let changed = try XCTUnwrap(parse("调休上班", notes: "学校通知有变").first)
        XCTAssertEqual(a.syncKey, b.syncKey)
        XCTAssertEqual(a.fingerprint, b.fingerprint)
        XCTAssertEqual(a.syncKey, changed.syncKey)
        XCTAssertNotEqual(a.fingerprint, changed.fingerprint)
    }

    func testEmptyUnrecognizedCalendarIsSafe() throws {
        XCTAssertTrue(try parse("生日").isEmpty)
    }

    func testMappingForAnotherDateOrMultipleDaysRequiresConfirmation() throws {
        let otherDate = try XCTUnwrap(parse("10月10日按星期一课表上课", role: .school).first)
        XCTAssertFalse(otherDate.rule.isConfirmed)
        XCTAssertNil(otherDate.rule.replacementWeekday)
        let multiple = try parse("按周一课表上课", role: .school, end: "2026-10-08")
        XCTAssertTrue(multiple.allSatisfy { !$0.rule.isConfirmed && $0.rule.replacementWeekday == nil })
    }

    func testFloatingAllDaySnapshotKeepsDateWhenPhoneIsAbroad() throws {
        let abroad = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let holiday = try day("2026-10-01")
        let snapshot = try CalendarEventSnapshot(calendarID: "holiday", eventID: "travel", title: "国庆节",
            start: holiday.start(in: abroad), end: holiday.adding(days: 1).start(in: abroad),
            isAllDay: true, timeZoneID: abroad.identifier, role: .holidays)
        let results = try CalendarEventParser().parse(snapshot,
            in: DayRange(start: day("2026-09-07"), endExclusive: day("2027-01-11")),
            schoolTimeZone: LocalDay.schoolTimeZone)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.rule.day, holiday)
    }
}
