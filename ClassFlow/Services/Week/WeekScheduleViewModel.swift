import Combine
import Foundation
import SwiftData
import ClassFlowCore

struct WeekSchedulePageModel: Equatable {
    let semesterID: UUID
    let semesterName: String
    let timeZoneID: String
    let totalWeeks: Int
    let currentTeachingWeek: Int?
    let todayTargetWeek: Int
    let snapshot: WeekScheduleSnapshot
    let timeSlots: [TimeSlotDefinition]
    let layoutItems: [CourseLayoutItem]
    let currentTimeOffset: Double?
}

enum WeekScheduleScreenState: Equatable {
    case loading
    case noSemester(LocalDay)
    case loaded(WeekSchedulePageModel)
    case failed(String)
}

@MainActor
final class WeekScheduleViewModel: ObservableObject {
    @Published private(set) var state: WeekScheduleScreenState = .loading

    var page: WeekSchedulePageModel? {
        guard case let .loaded(page) = state else { return nil }
        return page
    }

    private let container: ModelContainer
    private let nowProvider: () -> Date
    private let metrics: ScheduleLayoutMetrics
    private var selectedWeek: Int?
    private var minuteTask: Task<Void, Never>?

    init(container: ModelContainer, nowProvider: @escaping () -> Date = Date.init,
         metrics: ScheduleLayoutMetrics = .standard) {
        self.container = container
        self.nowProvider = nowProvider
        self.metrics = metrics
    }

    func reload(at date: Date? = nil, resetToCurrentWeek: Bool = false,
                preserveSelectedWeek: Bool = false) {
        let now = date ?? nowProvider()
        let wasFollowingToday = page.map { $0.snapshot.weekNumber == $0.todayTargetWeek } ?? false
        do {
            let context = ModelContext(container)
            guard let semester = try SemesterRepository(context: context).current() else {
                selectedWeek = nil
                state = .noSemester(LocalDay(date: now, timeZone: .autoupdatingCurrent))
                return
            }
            let definition = try semester.definition()
            let today = LocalDay(date: now, timeZone: definition.timeZone)
            let navigation = WeekScheduleNavigation()
            let currentPosition = try AcademicCalendarService().position(on: today, semester: definition)
            let currentWeek = currentPosition.weekNumber
            let initial = try navigation.initialWeek(for: today, semester: definition)
            let followsToday = resetToCurrentWeek || (wasFollowingToday && !preserveSelectedWeek)
            let week = followsToday ? initial
                : min(max(selectedWeek ?? initial, 1), definition.totalWeeks)
            selectedWeek = week
            let timeSlots = try semester.timeSlots.map { try $0.definition() }
                .sorted { $0.sectionNumber < $1.sectionNumber }
            let snapshot = try WeekScheduleService().snapshot(weekNumber: week, semester: semester,
                currentDate: today)
            let layout = try CourseLayoutEngine().layout(days: snapshot.days,
                timeSlots: timeSlots, metrics: metrics)
            let line = currentWeek == week && snapshot.isCurrentWeek
                ? try CurrentTimeLayoutEngine().position(at: now, timeZone: definition.timeZone,
                    timeSlots: timeSlots, metrics: metrics)
                : nil
            state = .loaded(WeekSchedulePageModel(semesterID: semester.id,
                semesterName: semester.name, timeZoneID: semester.timeZoneID,
                totalWeeks: semester.totalWeeks, currentTeachingWeek: currentWeek,
                todayTargetWeek: initial,
                snapshot: snapshot, timeSlots: timeSlots, layoutItems: layout,
                currentTimeOffset: line))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func showPreviousWeek() {
        guard let page else { return }
        selectedWeek = WeekScheduleNavigation().previous(from: page.snapshot.weekNumber,
            totalWeeks: page.totalWeeks)
        reload(preserveSelectedWeek: true)
    }

    func showNextWeek() {
        guard let page else { return }
        selectedWeek = WeekScheduleNavigation().next(from: page.snapshot.weekNumber,
            totalWeeks: page.totalWeeks)
        reload(preserveSelectedWeek: true)
    }

    func showCurrentWeek() { reload(resetToCurrentWeek: true) }

    func selectReplacementWeekday(_ weekday: Weekday, for day: DayScheduleSnapshot) throws {
        guard let page, day.dayStatus == .needsConfirmation,
              page.snapshot.days.contains(where: { $0.date == day.date }) else {
            throw DomainError.invalidOverride
        }
        try ScheduleOverrideService(container: container).confirmReplacement(day: day.date,
            weekday: weekday, semesterID: page.semesterID, title: day.specialTitle,
            note: "用户确认调休课表")
        reload()
    }

    func refreshClock(at date: Date? = nil) {
        guard case let .loaded(page) = state,
              let zone = TimeZone(identifier: page.timeZoneID) else { return }
        let now = date ?? nowProvider()
        let today = LocalDay(date: now, timeZone: zone)
        if page.snapshot.currentDate != today {
            reload(at: now)
            return
        }
        let line: Double?
        if page.currentTeachingWeek == page.snapshot.weekNumber && page.snapshot.isCurrentWeek {
            line = (try? CurrentTimeLayoutEngine().position(at: now, timeZone: zone,
                timeSlots: page.timeSlots, metrics: metrics)) ?? nil
        } else {
            line = nil
        }
        state = .loaded(WeekSchedulePageModel(semesterID: page.semesterID,
            semesterName: page.semesterName, timeZoneID: page.timeZoneID,
            totalWeeks: page.totalWeeks, currentTeachingWeek: page.currentTeachingWeek,
            todayTargetWeek: page.todayTargetWeek,
            snapshot: page.snapshot, timeSlots: page.timeSlots, layoutItems: page.layoutItems,
            currentTimeOffset: line))
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
