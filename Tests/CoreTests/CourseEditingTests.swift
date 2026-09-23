import XCTest
@testable import ClassFlowCore

final class CourseEditingTests: XCTestCase {
    private func slots() throws -> [TimeSlotDefinition] {
        try (1...6).map { try TimeSlotDefinition(sectionNumber: $0, startMinute: 480 + ($0 - 1) * 60, endMinute: 525 + ($0 - 1) * 60) }
    }
    private func schedule(_ day: Int = 1, _ start: Int = 1, _ end: Int = 2, _ weeks: Set<Int> = [1, 2, 3]) -> CourseScheduleDraft {
        CourseScheduleDraft(weekday: day, startSection: start, endSection: end, activeWeeks: weeks)
    }
    private func course(_ schedules: [CourseScheduleDraft]? = nil) -> CourseDraft {
        CourseDraft(name: "高等数学", schedules: schedules ?? [schedule()])
    }
    func testNewDraftHasNoPersistedContent() {
        let value = CourseDraft()
        XCTAssertTrue(value.name.isEmpty); XCTAssertTrue(value.schedules.isEmpty)
        XCTAssertNotEqual(value.id, CourseDraft().id)
    }
    func testValueRoundTripPreservesCourseAndScheduleIdentity() throws {
        let value = course()
        XCTAssertEqual(try CourseDraft(value.definition()), value)
    }
    func testConversionTrimsFieldsAndInheritsBlankLocation() throws {
        var value = course(); value.name = " 高数 \n"; value.teacher = " 王老师 "
        value.location = " A301 "; value.schedules[0].location = " \n"
        let definition = try value.definition()
        XCTAssertEqual(definition.name, "高数"); XCTAssertEqual(definition.teacher, "王老师")
        XCTAssertEqual(definition.location, "A301"); XCTAssertNil(definition.schedules[0].location)
    }
    func testArrangementLocationTakesItsOwnValue() throws {
        var value = course(); value.location = "A301"; value.schedules[0].location = "B205"
        XCTAssertEqual(try value.definition().schedules[0].location, "B205")
    }
    func testBlankNameIsInvalid() throws {
        var value = course(); value.name = " \n\t"
        XCTAssertTrue(value.issues(totalWeeks: 18, slots: try slots()).contains("请输入课程名称。"))
    }
    func testLongMultilingualNameAndOptionalFieldsAreValid() throws {
        var value = course(); value.name = "大学英语 Academic Writing（学术写作）2026"
        XCTAssertTrue(value.issues(totalWeeks: 18, slots: try slots()).isEmpty)
    }
    func testNoScheduleCannotBeSaved() throws {
        XCTAssertTrue(course([]).issues(totalWeeks: 18, slots: try slots()).contains("请至少添加一个上课安排。"))
    }
    func testInvalidWeekdayRejected() throws {
        XCTAssertFalse(schedule(8).issues(totalWeeks: 18, slots: try slots()).isEmpty)
        XCTAssertThrowsError(try course([schedule(0)]).definition())
    }
    func testReversedSectionsRejected() throws {
        XCTAssertFalse(schedule(1, 3, 2).issues(totalWeeks: 18, slots: try slots()).isEmpty)
    }
    func testOutOfRangeSectionsRejected() throws {
        for (start, end) in [(0, 2), (1, 31), (-1, -2), (31, 31)] {
            XCTAssertFalse(schedule(1, start, end).issues(totalWeeks: 18, slots: try slots()).isEmpty)
        }
    }
    func testMissingIntermediateSectionRejected() throws {
        let values = try slots().filter { $0.sectionNumber != 2 }
        XCTAssertFalse(schedule(1, 1, 3).issues(totalWeeks: 18, slots: values).isEmpty)
    }
    func testNoTimeSlotsRejected() {
        XCTAssertFalse(course().issues(totalWeeks: 18, slots: []).isEmpty)
    }
    func testEmptyWeeksRejected() throws {
        XCTAssertFalse(schedule(1, 1, 2, []).issues(totalWeeks: 18, slots: try slots()).isEmpty)
    }
    func testWeeksOutsideSemesterRejected() throws {
        XCTAssertFalse(schedule(1, 1, 2, [0, 19]).issues(totalWeeks: 18, slots: try slots()).isEmpty)
    }
    func testCustomWeeksRoundTrip() throws {
        let weeks: Set<Int> = [1, 2, 3, 5, 7, 9, 12]
        XCTAssertEqual(try course([schedule(1, 1, 2, weeks)]).definition().schedules[0].activeWeeks.values, weeks)
    }
    func testOddAndEvenDefinitionsFollowSemesterLength() throws {
        XCTAssertEqual(try ActiveWeeks.odd(1...7).sorted, [1, 3, 5, 7])
        XCTAssertEqual(try ActiveWeeks.even(1...7).sorted, [2, 4, 6])
    }
    func testSchedulesSortByWeekdayThenSection() {
        let value = course([schedule(5), schedule(1, 3, 4), schedule(1), schedule(3)])
        XCTAssertEqual(value.sortedSchedules.map(\.weekday), [1, 1, 3, 5])
        XCTAssertEqual(value.sortedSchedules.prefix(2).map(\.startSection), [1, 3])
    }
    func testDuplicateArrangementRejectedEvenWithDifferentLocation() throws {
        var second = schedule(); second.location = "另一个教室"
        XCTAssertTrue(course([schedule(), second]).issues(totalWeeks: 18, slots: try slots()).contains { $0.contains("重复安排") })
    }
    func testDistinctWeeksAreNotDuplicate() throws {
        XCTAssertTrue(course([schedule(), schedule(1, 1, 2, [4, 5])]).issues(totalWeeks: 18, slots: try slots()).isEmpty)
    }
    func testDuplicateScheduleIdentityRejected() throws {
        let first = schedule(); var second = schedule(3); second.id = first.id
        XCTAssertTrue(course([first, second]).issues(totalWeeks: 18, slots: try slots()).contains("上课安排标识重复。"))
    }
    func testRemovingDraftScheduleKeepsOtherScheduleAndOriginal() {
        let original = course([schedule(), schedule(3)])
        var edited = original; edited.schedules.removeFirst()
        XCTAssertEqual(original.schedules.count, 2); XCTAssertEqual(edited.schedules.count, 1)
        XCTAssertEqual(edited.schedules[0].id, original.schedules[1].id)
    }
    func testFormatterCompressesRanges() {
        XCTAssertEqual(ActiveWeeksFormatter.string([1, 2, 3, 5, 7, 8]), "1–3, 5, 7–8周")
    }
    func testFormatterSortsAndDeduplicates() {
        XCTAssertEqual(ActiveWeeksFormatter.string([3, 1, 2, 2]), "1–3周")
    }
    func testFormatterRecognizesEveryWeek() {
        XCTAssertEqual(ActiveWeeksFormatter.string(Array(1...7), totalWeeks: 7), "每周（1–7周）")
    }
    func testFormatterRecognizesOnlyFullOddOrEvenSelection() {
        XCTAssertEqual(ActiveWeeksFormatter.string([1, 3, 5, 7], totalWeeks: 7), "单周")
        XCTAssertEqual(ActiveWeeksFormatter.string([2, 4, 6], totalWeeks: 7), "双周")
        XCTAssertEqual(ActiveWeeksFormatter.string([1, 3], totalWeeks: 7), "1, 3周")
    }
    func testFormatterEmptySelection() { XCTAssertEqual(ActiveWeeksFormatter.string([]), "未选择教学周") }
    func testFullOverlapReportsSharedSectionsAndWeeks() {
        let first = course(); let second = course()
        let results = CourseConflictChecker.conflicts(for: first, among: [second])
        XCTAssertEqual(results.count, 1); XCTAssertEqual(results.first?.weeks, [1, 2, 3])
        XCTAssertEqual(results.first?.startSection, 1); XCTAssertEqual(results.first?.endSection, 2)
    }
    func testPartialOverlapReportsIntersection() {
        let results = CourseConflictChecker.conflicts(for: course(), among: [course([schedule(1, 2, 3, [3, 4])])])
        XCTAssertEqual(results.first?.weeks, [3]); XCTAssertEqual(results.first?.startSection, 2)
        XCTAssertEqual(results.first?.endSection, 2)
    }
    func testAdjacentSectionsDoNotConflict() {
        XCTAssertTrue(CourseConflictChecker.conflicts(for: course(), among: [course([schedule(1, 3, 4)])]).isEmpty)
    }
    func testDifferentWeekdaysDoNotConflict() {
        XCTAssertTrue(CourseConflictChecker.conflicts(for: course(), among: [course([schedule(3)])]).isEmpty)
    }
    func testDisjointWeekRangesDoNotConflict() {
        XCTAssertTrue(CourseConflictChecker.conflicts(for: course(), among: [course([schedule(1, 1, 2, [9, 10])])]).isEmpty)
    }
    func testOddEvenOverlapDoesNotConflict() throws {
        let odd = course([schedule(1, 1, 2, try ActiveWeeks.odd(1...18).values)])
        let even = course([schedule(1, 1, 2, try ActiveWeeks.even(1...18).values)])
        XCTAssertTrue(CourseConflictChecker.conflicts(for: odd, among: [even]).isEmpty)
    }
    func testEditingExcludesStoredVersionOfSameCourse() {
        let original = course(); var edit = original; edit.name = "新名字"
        XCTAssertTrue(CourseConflictChecker.conflicts(for: edit, among: [original]).isEmpty)
    }
    func testInternalOverlapsReportedOncePerPair() {
        XCTAssertEqual(CourseConflictChecker.conflicts(for: course([schedule(), schedule(), schedule()]), among: []).count, 3)
    }
    func testColorAllocatorUsesLeastUsedPaletteEntry() {
        XCTAssertEqual(CourseColorAllocator.next(used: [.blue, .blue, .teal]), .green)
        XCTAssertEqual(CourseColorAllocator.next(used: CourseColor.allCases + [.blue]), .teal)
    }
    func testPaletteContainsTenStableDistinctKeys() {
        XCTAssertEqual(CourseColor.allCases.count, 10)
        XCTAssertEqual(CourseColor(rawValue: "blue"), .blue)
        XCTAssertEqual(Set(CourseColor.allCases.map(\.rawValue)).count, 10)
    }
    func testKnownKeysKeepTheirColorsAndUnknownKeyOnlyFallsBackForDisplay() throws {
        for color in CourseColor.allCases { XCTAssertEqual(CourseColor.resolve(color.rawValue), color) }
        let source = CourseDefinition(name: "旧颜色课程", schedules: [], colorKey: "future-copper")
        var draft = CourseDraft(source)
        XCTAssertEqual(draft.color, .blue)
        draft.name = "只改名字"
        XCTAssertEqual(try draft.definition().colorKey, "future-copper")
    }
    func testExplicitColorSelectionReplacesUnknownKey() throws {
        var draft = CourseDraft(CourseDefinition(name: "课程", schedules: [], colorKey: "future-copper"))
        draft.color = .blue
        XCTAssertEqual(try draft.definition().colorKey, "blue")
    }
}
