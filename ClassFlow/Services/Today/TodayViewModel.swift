import Combine
import Foundation
import SwiftData
import ClassFlowCore

struct TodayPageModel: Equatable {
    let semesterID: UUID
    let semesterName: String
    let timeZoneID: String
    let snapshot: TodaySnapshot
}

enum TodayScreenState: Equatable {
    case loading
    case noSemester(LocalDay)
    case loaded(TodayPageModel)
    case failed(LocalDay, String)
}

@MainActor
final class TodayViewModel: ObservableObject {
    @Published private(set) var state: TodayScreenState = .loading

    var page: TodayPageModel? {
        guard case let .loaded(page) = state else { return nil }
        return page
    }
    var currentDate: LocalDay? { page?.snapshot.day }
    var academicWeek: Int? { page?.snapshot.academicPosition.weekNumber }
    var dayStatus: TodayDayKind? { page?.snapshot.dayKind }
    var effectiveWeekday: Weekday? { page?.snapshot.effectiveWeekday }
    var todayCourses: [TodayCourseItem] { page?.snapshot.courses ?? [] }
    var finishedCourses: [TodayCourseItem] { todayCourses.filter { $0.status == .finished } }
    var upcomingCourses: [TodayCourseItem] { todayCourses.filter { $0.status == .upcoming } }
    var currentCourse: TodayCourseItem? { page?.snapshot.currentCourse }
    var nextCourse: TodayCourseItem? { page?.snapshot.nextCourse }
    var nextCourseCountdown: TodayCountdown? { page?.snapshot.countdown }
    var specialDayTitle: String? { page?.snapshot.specialDayTitle }
    var scheduleOverride: OverrideDefinition? { page?.snapshot.appliedOverride }

    private let container: ModelContainer
    private let nowProvider: () -> Date
    private var resolvedDay: ResolvedDay?
    private var minuteTask: Task<Void, Never>?

    init(container: ModelContainer, nowProvider: @escaping () -> Date = Date.init) {
        self.container = container
        self.nowProvider = nowProvider
    }

    func reload(at date: Date? = nil) {
        let now = date ?? nowProvider()
        do {
            let context = ModelContext(container)
            guard let semester = try SemesterRepository(context: context).current() else {
                resolvedDay = nil
                state = .noSemester(LocalDay(date: now, timeZone: .autoupdatingCurrent))
                return
            }
            let definition = try semester.definition()
            let day = LocalDay(date: now, timeZone: definition.timeZone)
            let resolved = try ScheduleService().resolve(day: day, semester: semester)
            resolvedDay = resolved
            state = .loaded(TodayPageModel(semesterID: semester.id, semesterName: semester.name,
                timeZoneID: semester.timeZoneID,
                snapshot: TodaySnapshotBuilder().make(from: resolved, now: now)))
        } catch {
            resolvedDay = nil
            state = .failed(LocalDay(date: now, timeZone: .autoupdatingCurrent), error.localizedDescription)
        }
    }

    func refreshClock(at date: Date? = nil) {
        let now = date ?? nowProvider()
        guard case let .loaded(page) = state, let resolvedDay,
              let zone = TimeZone(identifier: page.timeZoneID),
              LocalDay(date: now, timeZone: zone) == page.snapshot.day else {
            reload(at: now)
            return
        }
        state = .loaded(TodayPageModel(semesterID: page.semesterID, semesterName: page.semesterName,
            timeZoneID: page.timeZoneID,
            snapshot: TodaySnapshotBuilder().make(from: resolvedDay, now: now)))
    }

    func selectReplacementWeekday(_ weekday: Weekday) throws {
        guard case let .loaded(page) = state, page.snapshot.dayKind == .needsConfirmation else {
            throw DomainError.invalidOverride
        }
        try ScheduleOverrideService(container: container).confirmReplacement(day: page.snapshot.day,
            weekday: weekday, semesterID: page.semesterID, title: page.snapshot.specialDayTitle,
            note: "用户确认调休课表")
        reload()
    }

    func createSemester(name: String, startDate: Date, totalWeeks: Int) throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let startDay = LocalDay(date: startDate, timeZone: .autoupdatingCurrent)
        let context = ModelContext(container)
        let semester = try Semester(name: cleanName, startDay: startDay, totalWeeks: totalWeeks)
        context.insert(semester)
        try SemesterRepository(context: context).setCurrent(semester)
        reload()
    }

    func startMinuteUpdates() {
        guard minuteTask == nil else { return }
        minuteTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                let now = Date()
                let remainder = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 60)
                let delay = max(1, 60 - remainder + 0.05)
                do { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
                catch { return }
                self?.refreshClock()
            }
        }
    }

    func stopMinuteUpdates() {
        minuteTask?.cancel()
        minuteTask = nil
    }
}
