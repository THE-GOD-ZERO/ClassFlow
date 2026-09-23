import SwiftUI
import SwiftData
import ClassFlowCore

@MainActor
struct WeekScheduleView: View {
    @StateObject private var viewModel: WeekScheduleViewModel
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase
    @State private var pendingDay: DayScheduleSnapshot?
    @State private var actionError: String?

    init(container: ModelContainer) {
        _viewModel = StateObject(wrappedValue: WeekScheduleViewModel(container: container))
    }

    var body: some View {
        NavigationStack {
            WeekScheduleScreenContent(state: viewModel.state,
                onPrevious: { viewModel.showPreviousWeek(); AppHaptics.selected() },
                onNext: { viewModel.showNextWeek(); AppHaptics.selected() },
                onCurrent: { viewModel.showCurrentWeek(); AppHaptics.returnToToday() },
                onRetry: { viewModel.reload() },
                onPendingDay: { pendingDay = $0 })
                .navigationTitle("课表")
                .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            viewModel.reload()
            if scenePhase == .active { viewModel.startMinuteUpdates() }
        }
        .onDisappear { viewModel.stopMinuteUpdates() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                viewModel.reload()
                viewModel.startMinuteUpdates()
            } else {
                viewModel.stopMinuteUpdates()
            }
        }
        .onChange(of: environment.calendarRevision) { _, _ in viewModel.reload() }
        .onChange(of: environment.scheduleRevision) { _, _ in viewModel.reload() }
        .sheet(item: $pendingDay) { day in
            ReplacementWeekdaySheet(title: "\(day.date.month)月\(day.date.day)日的课表") { weekday in
                do {
                    try viewModel.selectReplacementWeekday(weekday, for: day)
                    environment.scheduleDataDidChange()
                    AppHaptics.selected()
                    return true
                } catch {
                    actionError = error.localizedDescription
                    return false
                }
            }
            .appSheet()
        }
        .alert("无法保存", isPresented: Binding(get: { actionError != nil },
            set: { if !$0 { actionError = nil } })) {
            Button("好", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "请稍后重试。")
        }
    }
}

struct WeekScheduleScreenContent: View {
    let state: WeekScheduleScreenState
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onCurrent: () -> Void
    let onRetry: () -> Void
    let onPendingDay: (DayScheduleSnapshot) -> Void

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView("正在准备周课表…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .noSemester(day):
                AppEmptyState(title: "尚未设置学期",
                    message: "\(day.month)月\(day.day)日 · 请先在“今日”设置学期。", symbol: "calendar.badge.plus")
            case let .loaded(page):
                WeekSchedulePageView(page: page, onPrevious: onPrevious, onNext: onNext,
                    onCurrent: onCurrent, onPendingDay: onPendingDay)
            case let .failed(message):
                AppEmptyState(title: "无法载入周课表", message: message,
                    symbol: "exclamationmark.triangle", actionTitle: "重新载入", action: onRetry)
            }
        }
        .background(AppColors.canvas)
    }
}
