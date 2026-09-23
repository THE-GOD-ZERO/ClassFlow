import XCTest
import SwiftData
import ClassFlowCore
@testable import ClassFlow

@MainActor
private final class FakeCalendar: CalendarProviding {
    var access: CalendarAccess = .fullAccess
    var snapshots = [CalendarEventSnapshot]()
    var readCount = 0
    var shouldFail = false
    func requestAccess() async throws -> CalendarAccess { access }
    func calendars() throws -> [CalendarDescriptor] { [] }
    func events(in range: DayRange, timeZone: TimeZone,
                selections: [String: CalendarRole]) throws -> [CalendarEventSnapshot] {
        readCount += 1
        if shouldFail { throw CalendarReadError.accessUnavailable }
        return snapshots
    }
}

final class CalendarSyncTests: XCTestCase {
    @MainActor
    private func makeSemester(_ container: ModelContainer) throws -> UUID {
        let context = ModelContext(container)
        let term = try Semester(name: "秋季", startDay: LocalDay(key: "2026-09-07"), totalWeeks: 18, isCurrent: true)
        context.insert(term)
        try context.save()
        return term.id
    }

    private func event(title: String = "调休上班", id: String = "event-1", date: String = "2026-10-10",
                       role: CalendarRole = .holidays) throws -> CalendarEventSnapshot {
        let day = try LocalDay(key: date)
        return try CalendarEventSnapshot(calendarID: "selected", eventID: id, title: title,
            start: day.start(in: LocalDay.schoolTimeZone), end: day.adding(days: 1).start(in: LocalDay.schoolTimeZone),
            isAllDay: true, timeZoneID: "Asia/Shanghai", role: role)
    }

    @MainActor
    func testRepeatedAndDuplicateScansAreIdempotent() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let id = try makeSemester(container)
        let calendar = FakeCalendar()
        calendar.snapshots = try [event(), event()]
        let sync = CalendarSyncService(container: container, calendar: calendar)
        XCTAssertEqual(try sync.sync(semesterID: id, selections: ["selected": .holidays]).inserted, 1)
        for _ in 0..<3 {
            let report = try sync.sync(semesterID: id, selections: ["selected": .holidays])
            XCTAssertEqual(report.inserted, 0)
            XCTAssertEqual(report.updated, 0)
        }
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<ScheduleOverride>()), 1)
    }

    @MainActor
    func testConfirmationSurvivesRescanButSourceChangesInvalidateIt() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let id = try makeSemester(container)
        let calendar = FakeCalendar()
        calendar.snapshots = try [event()]
        let sync = CalendarSyncService(container: container, calendar: calendar)
        _ = try sync.sync(semesterID: id, selections: ["selected": .holidays])
        let context = ModelContext(container)
        let record = try XCTUnwrap(context.fetch(FetchDescriptor<ScheduleOverride>()).first)
        try OverrideRepository(context: context).confirm(record, weekday: .monday)
        _ = try sync.sync(semesterID: id, selections: ["selected": .holidays])
        var check = ModelContext(container)
        XCTAssertEqual(try check.fetch(FetchDescriptor<ScheduleOverride>()).first?.replacementWeekdayRawValue, 1)
        calendar.snapshots = try [event(title: "调休上班（变更）")]
        _ = try sync.sync(semesterID: id, selections: ["selected": .holidays])
        check = ModelContext(container)
        let changed = try XCTUnwrap(check.fetch(FetchDescriptor<ScheduleOverride>()).first)
        XCTAssertFalse(changed.isConfirmed)
        XCTAssertNil(changed.replacementWeekdayRawValue)
    }

    @MainActor
    func testPermissionDeniedNeverReadsCalendarAndPreservesManualRules() async throws {
        for access in [CalendarAccess.denied, .restricted, .notDetermined, .writeOnly] {
            let container = try PersistenceController.makeContainer(inMemory: true)
            let id = try makeSemester(container)
            let context = ModelContext(container)
            let term = try XCTUnwrap(context.fetch(FetchDescriptor<Semester>()).first)
            _ = try OverrideRepository(context: context).saveManual(day: LocalDay(key: "2026-10-10"),
                type: .adjustedWorkday, weekday: .monday, title: "学校安排", semester: term)
            let calendar = FakeCalendar()
            calendar.access = access
            let report = try CalendarSyncService(container: container, calendar: calendar)
                .sync(semesterID: id, selections: ["selected": .holidays])
            XCTAssertEqual(report.access, access)
            XCTAssertEqual(calendar.readCount, 0)
            XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<ScheduleOverride>()), 1)
        }
    }

    @MainActor
    func testRevokedAccessRemovesAutomaticRules() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let id = try makeSemester(container)
        let calendar = FakeCalendar()
        calendar.snapshots = try [event(title: "国庆节")]
        let sync = CalendarSyncService(container: container, calendar: calendar)
        _ = try sync.sync(semesterID: id, selections: ["selected": .holidays])
        calendar.access = .denied
        XCTAssertEqual(try sync.sync(semesterID: id, selections: ["selected": .holidays]).deleted, 1)
        XCTAssertEqual(calendar.readCount, 1)
    }

    @MainActor
    func testDeletedEventOrCalendarRemovesStaleRule() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let id = try makeSemester(container)
        let calendar = FakeCalendar()
        calendar.snapshots = try [event()]
        let sync = CalendarSyncService(container: container, calendar: calendar)
        _ = try sync.sync(semesterID: id, selections: ["selected": .holidays])
        calendar.snapshots = []
        XCTAssertEqual(try sync.sync(semesterID: id, selections: ["selected": .holidays]).deleted, 1)
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<ScheduleOverride>()), 0)
    }

    @MainActor
    func testDeselectedCalendarCannotReimport() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let id = try makeSemester(container)
        let calendar = FakeCalendar()
        calendar.snapshots = try [event()]
        let sync = CalendarSyncService(container: container, calendar: calendar)
        _ = try sync.sync(semesterID: id, selections: ["selected": .holidays])
        XCTAssertEqual(try sync.sync(semesterID: id, selections: [:]).deleted, 1)
    }

    @MainActor
    func testReadFailureDoesNotDeletePreviousData() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let id = try makeSemester(container)
        let calendar = FakeCalendar()
        calendar.snapshots = try [event()]
        let sync = CalendarSyncService(container: container, calendar: calendar)
        _ = try sync.sync(semesterID: id, selections: ["selected": .holidays])
        calendar.shouldFail = true
        XCTAssertThrowsError(try sync.sync(semesterID: id, selections: ["selected": .holidays]))
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<ScheduleOverride>()), 1)
    }

    @MainActor
    func testSchoolCalendarImportFlowsThroughResolver() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let id = try makeSemester(container)
        let calendar = FakeCalendar()
        calendar.snapshots = try [event(title: "按星期五课表上课", role: .school)]
        _ = try CalendarSyncService(container: container, calendar: calendar)
            .sync(semesterID: id, selections: ["selected": .school])
        let context = ModelContext(container)
        let term = try XCTUnwrap(context.fetch(FetchDescriptor<Semester>()).first)
        let result = try ScheduleService().resolve(day: LocalDay(key: "2026-10-10"), semester: term)
        XCTAssertEqual(result.effectiveWeekday, .friday)
        XCTAssertFalse(result.needsConfirmation)
    }

    @MainActor
    func testSameEventInTwoSemestersDoesNotShareRecords() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let a = try makeSemester(container)
        let b = try makeSemester(container)
        let calendar = FakeCalendar()
        calendar.snapshots = try [event()]
        let sync = CalendarSyncService(container: container, calendar: calendar)
        _ = try sync.sync(semesterID: a, selections: ["selected": .holidays])
        _ = try sync.sync(semesterID: b, selections: ["selected": .holidays])
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<ScheduleOverride>()), 2)
    }

    @MainActor
    func testMovedEventReplacesOldDateAndEmptyFirstScanIsSafe() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let id = try makeSemester(container)
        let calendar = FakeCalendar()
        let sync = CalendarSyncService(container: container, calendar: calendar)
        XCTAssertEqual(try sync.sync(semesterID: id, selections: ["selected": .holidays]).inserted, 0)
        calendar.snapshots = try [event()]
        _ = try sync.sync(semesterID: id, selections: ["selected": .holidays])
        calendar.snapshots = try [event(date: "2026-10-11")]
        let result = try sync.sync(semesterID: id, selections: ["selected": .holidays])
        XCTAssertEqual(result.inserted, 1)
        XCTAssertEqual(result.deleted, 1)
        let records = try ModelContext(container).fetch(FetchDescriptor<ScheduleOverride>())
        XCTAssertEqual(records.map(\.dayKey), ["2026-10-11"])
    }
}
