import SwiftUI
import ClassFlowCore

@MainActor
struct CourseScheduleEditor: View {
    let original: CourseScheduleDraft
    let parent: CourseDraft
    let page: CoursesPageModel
    let save: (CourseScheduleDraft, [DraftConflict]) -> Void
    @State private var draft: CourseScheduleDraft
    @State private var exit = false
    @State private var conflicts: [DraftConflict] = []
    @State private var showConflicts = false
    @State private var pendingSave = false
    @FocusState private var locationFocused: Bool
    @Environment(\.dismiss) private var dismiss
    init(schedule: CourseScheduleDraft, parent: CourseDraft, page: CoursesPageModel,
         save: @escaping (CourseScheduleDraft, [DraftConflict]) -> Void) {
        self.original = schedule; self.parent = parent; self.page = page; self.save = save
        _draft = State(initialValue: schedule)
    }
    private var issues: [String] {
        var values = draft.issues(totalWeeks: page.totalWeeks, slots: page.slots)
        if parent.schedules.contains(where: {
            $0.id != draft.id && $0.weekday == draft.weekday && $0.startSection == draft.startSection &&
                $0.endSection == draft.endSection && $0.activeWeeks == draft.activeWeeks
        }) { values.append("已有完全相同的星期、节次和教学周，请修改此安排。") }
        return values
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    EditorGroup("星期与节次") {
                        LabeledContent("星期") {
                            Picker("星期", selection: $draft.weekday) {
                                ForEach(Weekday.allCases, id: \.rawValue) { Text($0.chineseName).tag($0.rawValue) }
                            }.pickerStyle(.menu).labelsHidden().accessibilityLabel("星期").frame(minHeight: AppSpacing.touchTarget)
                        }
                        LabeledContent("开始节次") {
                            Picker("开始节次", selection: $draft.startSection) {
                                ForEach(page.slots, id: \.sectionNumber) { Text("第\($0.sectionNumber)节").tag($0.sectionNumber) }
                            }.pickerStyle(.menu).labelsHidden().accessibilityLabel("开始节次").frame(minHeight: AppSpacing.touchTarget)
                        }
                        LabeledContent("结束节次") {
                            Picker("结束节次", selection: $draft.endSection) {
                                ForEach(page.slots.filter { $0.sectionNumber >= draft.startSection }, id: \.sectionNumber) {
                                    Text("第\($0.sectionNumber)节").tag($0.sectionNumber)
                                }
                            }.pickerStyle(.menu).labelsHidden().accessibilityLabel("结束节次").frame(minHeight: AppSpacing.touchTarget)
                        }
                        Text(CourseDisplayText.time(draft, slots: page.slots))
                            .font(AppTypography.courseTitle).monospacedDigit()
                    }.appSurface()
                    EditorGroup("上课地点") {
                        TextField(parent.location.isEmpty ? "可选，留空使用课程默认地点" : "默认：\(parent.location)", text: $draft.location, axis: .vertical)
                            .font(AppTypography.body).focused($locationFocused).accessibilityLabel("此安排的上课地点，留空使用默认地点")
                            .frame(minHeight: AppSpacing.touchTarget)
                    }.appSurface()
                    EditorGroup("教学周") { WeekSelector(selection: $draft.activeWeeks, totalWeeks: page.totalWeeks) }.appSurface()
                    EditorValidation(messages: issues)
                }.padding(AppSpacing.page)
            }.scrollDismissesKeyboard(.interactively).background(AppColors.canvas)
                .navigationTitle("上课安排").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { cancel() } }
                    ToolbarItem(placement: .confirmationAction) { Button("完成") { validateAndSave() }.disabled(!issues.isEmpty) }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成输入") { locationFocused = false } }
                }
        }.appSheet(expanded: true)
            .modifier(DraftExitModifier(dirty: draft != original, confirming: $exit) { dismiss() })
            .onChange(of: draft.weekday) { _, _ in AppHaptics.selected() }
            .onChange(of: draft.startSection) { _, start in draft.endSection = max(start, draft.endSection) }
            .sheet(isPresented: $showConflicts, onDismiss: {
                if pendingSave { pendingSave = false; save(draft, conflicts); dismiss() }
            }) {
                CourseConflictSheet(courseName: parent.name, conflicts: conflicts,
                    returnToEditing: { showConflicts = false }, accept: {
                        pendingSave = true; showConflicts = false
                    })
            }
    }
    private func cancel() { if draft != original { exit = true } else { dismiss() } }
    private func validateAndSave() {
        var candidate = parent
        candidate.schedules.removeAll { $0.id == draft.id }; candidate.schedules.append(draft)
        conflicts = CourseConflictChecker.conflicts(for: candidate, among: page.courses)
            .filter { $0.firstID == draft.id || $0.secondID == draft.id }
        if conflicts.isEmpty { save(draft, []); dismiss() } else { showConflicts = true }
    }
}
