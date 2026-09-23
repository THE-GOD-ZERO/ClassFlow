import XCTest
import ClassFlowCore

final class CourseLayoutEngineTests: XCTestCase {
    private struct Spec { let start: Int; let end: Int; let name: String }

    private func layout(_ specs: [Spec], metrics: ScheduleLayoutMetrics = .standard,
                        customSlots: [TimeSlotDefinition]? = nil) throws -> [CourseLayoutItem] {
        let timeSlots = try customSlots ?? (1...6).map {
            try TimeSlotDefinition(sectionNumber: $0, startMinute: 480 + ($0 - 1) * 55,
                                   endMinute: 525 + ($0 - 1) * 55)
        }
        let definitions = try specs.map { spec in
            CourseDefinition(name: spec.name, schedules: [
                try ScheduleDefinition(weekday: .monday, startSection: spec.start,
                    endSection: spec.end, activeWeeks: ActiveWeeks([1]))
            ])
        }
        let resolved = try ScheduleResolver().resolve(day: day("2026-09-07"), semester: semester(),
            courses: definitions, timeSlots: timeSlots, overrides: [])
        return try CourseLayoutEngine().layout(days: [DayScheduleSnapshot(resolved: resolved)],
            timeSlots: timeSlots, metrics: metrics)
    }

    func testOneToTwoSectionsUsesOneContinuousCard() throws {
        let result = try layout([Spec(start: 1, end: 2, name: "A")])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].height, 146, accuracy: 0.001)
    }

    func testThreeToFiveSectionsHeight() throws {
        let result = try layout([Spec(start: 3, end: 5, name: "A")])
        XCTAssertEqual(result[0].height, 222, accuracy: 0.001)
    }

    func testCourseTopOffsetUsesSectionIndex() throws {
        let result = try layout([Spec(start: 3, end: 4, name: "A")])
        XCTAssertEqual(result[0].topOffset, 155, accuracy: 0.001)
    }

    func testFullyOverlappingCoursesUseTwoLanes() throws {
        let result = try layout([Spec(start: 1, end: 2, name: "A"), Spec(start: 1, end: 2, name: "B")])
        XCTAssertEqual(Set(result.map(\.laneCount)), [2])
        XCTAssertEqual(Set(result.map(\.laneIndex)), [0, 1])
        XCTAssertEqual(result[0].width, 52, accuracy: 0.001)
    }

    func testPartialOverlapUsesSeparateLanes() throws {
        let result = try layout([Spec(start: 1, end: 2, name: "A"), Spec(start: 2, end: 3, name: "B")])
        XCTAssertEqual(Set(result.map(\.laneCount)), [2])
        XCTAssertNotEqual(result[0].laneIndex, result[1].laneIndex)
    }

    func testThreeOverlappingCoursesUseThreeLanes() throws {
        let result = try layout([Spec(start: 1, end: 3, name: "A"),
                                 Spec(start: 1, end: 2, name: "B"),
                                 Spec(start: 2, end: 4, name: "C")])
        XCTAssertEqual(Set(result.map(\.laneCount)), [3])
        XCTAssertEqual(Set(result.map(\.laneIndex)), [0, 1, 2])
    }

    func testAdjacentCoursesDoNotOverlap() throws {
        let result = try layout([Spec(start: 1, end: 2, name: "A"), Spec(start: 3, end: 4, name: "B")])
        XCTAssertEqual(result.map(\.laneCount), [1, 1])
        XCTAssertEqual(result.map(\.laneIndex), [0, 0])
    }

    func testLaneCanBeReusedAfterOverlapEnds() throws {
        let result = try layout([Spec(start: 1, end: 2, name: "A"),
                                 Spec(start: 1, end: 4, name: "B"),
                                 Spec(start: 3, end: 4, name: "C")])
        XCTAssertEqual(result.first { $0.occurrence.courseName == "A" }?.laneIndex, 0)
        XCTAssertEqual(result.first { $0.occurrence.courseName == "C" }?.laneIndex, 0)
    }

    func testCustomSectionHeightChangesGeometryInOnePlace() throws {
        let metrics = try ScheduleLayoutMetrics(sectionHeight: 60)
        let result = try layout([Spec(start: 2, end: 3, name: "A")], metrics: metrics)
        XCTAssertEqual(result[0].topOffset, 63, accuracy: 0.001)
        XCTAssertEqual(result[0].height, 114, accuracy: 0.001)
    }

    func testChangedClassTimesChangeOccurrenceTimesWithoutChangingSectionPlacement() throws {
        let changed = try (1...6).map {
            try TimeSlotDefinition(sectionNumber: $0, startMinute: 540 + ($0 - 1) * 60,
                                   endMinute: 585 + ($0 - 1) * 60)
        }
        let result = try layout([Spec(start: 1, end: 2, name: "A")], customSlots: changed)
        let calendar = LocalDay.calendar(in: LocalDay.schoolTimeZone)
        XCTAssertEqual(calendar.component(.hour, from: result[0].occurrence.start), 9)
        XCTAssertEqual(result[0].topOffset, 3, accuracy: 0.001)
    }

    func testCurrentTimeLineInterpolatesWithinSection() throws {
        let date = try day("2026-09-07").start(in: LocalDay.schoolTimeZone).addingTimeInterval(8.5 * 3600)
        let result = try CurrentTimeLayoutEngine().position(at: date, timeZone: LocalDay.schoolTimeZone,
            timeSlots: slots())
        XCTAssertEqual(try XCTUnwrap(result), 50.666, accuracy: 0.01)
    }

    func testCurrentTimeLineIsHiddenOutsideSchoolDay() throws {
        let start = try day("2026-09-07").start(in: LocalDay.schoolTimeZone)
        XCTAssertNil(try CurrentTimeLayoutEngine().position(at: start, timeZone: LocalDay.schoolTimeZone,
            timeSlots: slots()))
    }
}
