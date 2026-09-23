import XCTest
@testable import ClassFlowCore

final class AcademicCalendarTests: XCTestCase {
    let service = AcademicCalendarService()

    func testNoSemester() throws {
        XCTAssertEqual(try service.position(on: day("2026-09-22"), semester: nil), .noSemester)
    }

    func testSemesterBoundaries() throws {
        let term = try semester()
        let examples: [(String, AcademicPosition)] = [
            ("2026-09-06", .beforeSemester), ("2026-09-07", .week(1)),
            ("2026-09-13", .week(1)), ("2026-09-14", .week(2)),
            ("2026-09-22", .week(3)), ("2026-10-01", .week(4)),
            ("2027-01-01", .week(17)), ("2027-01-10", .week(18)),
            ("2027-01-11", .afterSemester)
        ]
        for (date, expected) in examples {
            XCTAssertEqual(try service.position(on: day(date), semester: term), expected, date)
        }
    }

    func testMidweekStartHasPartialFirstWeek() throws {
        let term = try semester(start: "2026-09-09")
        XCTAssertEqual(try service.position(on: day("2026-09-08"), semester: term), .beforeSemester)
        XCTAssertEqual(try service.position(on: day("2026-09-13"), semester: term), .week(1))
        XCTAssertEqual(try service.position(on: day("2026-09-14"), semester: term), .week(2))
    }

    func testChangingStartDateRecomputesWeek() throws {
        XCTAssertEqual(try service.position(on: day("2026-09-22"), semester: semester(start: "2026-09-14")), .week(2))
    }

    func testInstantUsesSchoolZone() throws {
        // 2026-09-06 16:00 UTC is the first school day in Shanghai, even on a phone abroad.
        let instant = try day("2026-09-06").start(in: .gmt).addingTimeInterval(16 * 3600)
        XCTAssertEqual(try service.position(at: instant, semester: semester()), .week(1))
        XCTAssertEqual(LocalDay(date: instant, timeZone: .gmt).key, "2026-09-06")
    }

    func testInvalidSemester() throws {
        XCTAssertThrowsError(try semester(weeks: 0))
        XCTAssertThrowsError(try semester(zone: "Missing/Zone"))
    }
}
