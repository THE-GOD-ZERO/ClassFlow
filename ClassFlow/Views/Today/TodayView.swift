import SwiftUI
import SwiftData
import ClassFlowCore

@MainActor
struct TodayView: View {
    @StateObject private var viewModel: TodayViewModel
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsWeekdayPicker = false
    @State private var showsSemesterSetup = false
    @State private var actionError: String?

    init(container: ModelContainer) {
        _viewModel = StateObject(wrappedValue: TodayViewModel(container: container))
    }

    var body: some View {
        NavigationStack {
            TodayScreenContent(state: viewModel.state,
                onSetUpSemester: { showsSemesterSetup = true },
                onChooseWeekday: { showsWeekdayPicker = true },
                onRetry: { viewModel.reload() })
                .navigationTitle("今日")
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
        .sheet(isPresented: $showsWeekdayPicker) {
            ReplacementWeekdaySheet { weekday in
                do {
                    try viewModel.selectReplacementWeekday(weekday)
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
        .sheet(isPresented: $showsSemesterSetup) {
            SemesterSetupSheet { name, startDate, weeks in
                do {
                    try viewModel.createSemester(name: name, startDate: startDate, totalWeeks: weeks)
                    AppHaptics.success()
                    return true
                } catch {
                    actionError = error.localizedDescription
                    return false
                }
            }
            .appSheet()
        }
        .alert("无法保存", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
            Button("好", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "请稍后重试。")
        }
    }
}

struct TodayScreenContent: View {
    let state: TodayScreenState
    let onSetUpSemester: () -> Void
    let onChooseWeekday: () -> Void
    let onRetry: () -> Void

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView("正在准备今日课表…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .noSemester(day):
                noSemester(day)
            case let .loaded(page):
                TodayPageView(page: page, onChooseWeekday: onChooseWeekday, onReload: onRetry)
            case let .failed(_, message):
                AppEmptyState(title: "无法载入今日课表", message: message,
                    symbol: "exclamationmark.triangle", actionTitle: "重新载入", action: onRetry)
            }
        }
        .background(AppColors.canvas)
    }

    private func noSemester(_ day: LocalDay) -> some View {
        AppEmptyState(title: "欢迎使用 ClassFlow",
            message: "\(day.month)月\(day.day)日 · \(day.weekday.chineseName)\n请先设置学期和课程。",
            symbol: "calendar.badge.plus", actionTitle: "设置学期", action: onSetUpSemester)
    }
}

private struct SemesterSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var startDate = Date()
    @State private var totalWeeks = 18
    @State private var validationMessage: String?
    let onSave: (String, Date, Int) -> Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("学期") {
                    TextField("例如：2026-2027 第一学期", text: $name)
                    DatePicker("开学日期", selection: $startDate, displayedComponents: .date)
                    Stepper("总教学周：\(totalWeeks) 周", value: $totalWeeks, in: 1...104)
                }
                Section {
                    Text("课程与作息时间可在后续课程管理页面中添加。")
                        .foregroundStyle(.secondary)
                }
                if let validationMessage {
                    Section { Text(validationMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("设置学期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            validationMessage = "请输入学期名称。"
                            return
                        }
                        if onSave(name, startDate, totalWeeks) { dismiss() }
                    }
                }
            }
        }
    }
}
