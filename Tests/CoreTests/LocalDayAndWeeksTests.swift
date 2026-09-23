import XCTest
@testable import ClassFlowCore

final class LocalDayAndWeeksTests: XCTestCase {
    func testCivilDayValidationAndLeapYear() throws {
        XCTAssertEqual(try day("2024-02-28").adding(days: 1).key, "2024-02-29")
        XCTAssertEqual(try day("2026-12-31").adding(days: 1).key, "2027-01-01")
        XCTAssertThrowsError(try day("2026-02-29"))
        XCTAssertThrowsError(try day("2026-2-01"))
        XCTAssertThrowsError(try day("2026-13-01"))
    }

    func testWeekdayConvention() throws {
        XCTAssertEqual(try day("2026-09-07").weekday, .monday)
        XCTAssertEqual(try day("2026-09-13").weekday, .sunday)
    }

    func testDayNormalizationIgnoresTimeOfDay() throws {
        let start = try day("2026-09-22").start(in: LocalDay.schoolTimeZone)
        XCTAssertEqual(LocalDay(date: start, timeZone: LocalDay.schoolTimeZone),
                       LocalDay(date: start.addingTimeInterval(20 * 3600), timeZone: LocalDay.schoolTimeZone))
    }

    func testDSTDayArithmetic() throws {
        let zone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let spring = try day("2026-03-08")
        let next = try spring.adding(days: 1)
        XCTAssertEqual(try spring.distance(to: next), 1)
        XCTAssertEqual(try next.start(in: zone).timeIntervalSince(spring.start(in: zone)), 23 * 3600)
        let fall = try day("2026-11-01")
        XCTAssertEqual(try fall.adding(days: 1).start(in: zone).timeIntervalSince(fall.start(in: zone)), 25 * 3600)
    }

    func testContinuousAndSegmentedWeeks() throws {
        XCTAssertEqual(try ActiveWeeks.every(1...16).sorted, Array(1...16))
        let weeks = try ActiveWeeks.parse("1-8周，10-16周")
        XCTAssertTrue(weeks.contains(8))
        XCTAssertFalse(weeks.contains(9))
        XCTAssertTrue(weeks.contains(10))
    }

    func testOddEvenAndCustomWeeks() throws {
        XCTAssertEqual(try ActiveWeeks.odd(1...8).sorted, [1, 3, 5, 7])
        XCTAssertEqual(try ActiveWeeks.even(1...8).sorted, [2, 4, 6, 8])
        XCTAssertEqual(try ActiveWeeks.parse("1,2,3,5,7,9,12,3").sorted, [1, 2, 3, 5, 7, 9, 12])
    }

    func testInvalidWeekInputNeverPartiallySucceeds() {
        for value in ["", "0", "-1", "8-1", "1,", "1-200", "hello", "1,,3"] {
            XCTAssertThrowsError(try ActiveWeeks.parse(value), value)
        }
    }
}
