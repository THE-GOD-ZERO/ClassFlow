import SwiftUI
import ClassFlowCore

@MainActor
struct CourseEditor: View {
    let original: CourseDraft?
    let initial: CourseDraft
    let page: CoursesPageModel
    let save: (CourseDraft, [DraftConflict]) throws -> Void
    @State private var draft: CourseDraft
    @State private var editingSchedule: CourseScheduleDraft?
    @State private var exit = false
    @State private var error: String?
    @State private var conflicts: [DraftConflict] = []
    @State private var accepted: [DraftConflict] = []
    @State private var showConflicts = false
    @FocusState private var focused: Field?
    @ScaledMetric(relativeTo: .title2) private var swatchWidth = AppSpacing.touchTarget
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private enum Field: Hashable { case name, teacher, location, note }
    init(draft: CourseDraft, original: CourseDraft?, page: CoursesPageModel,
         save: @escaping (CourseDraft, [DraftConflict]) throws -> Void) {
        self.initial = draft; self.original = original; self.page = page; self.save = save
        _draft = State(initialValue: draft)
    }
    private var issues: [String] { draft.issues(totalWeeks: page.totalWeeks, slots: page.slots) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    basicInformation
                    arrangements
                    appearance
                    DisclosureGroup("备注") {
                        TextField("教材、上课提醒或其他记录", text: $draft.note, axis: .vertical)
                            .font(AppTypography.body).focused($focused, equals: .note)
                            .frame(minHeight: AppSpacing.touchTarget).accessibilityLabel("课程备注，可选")
                            .padding(.top, AppSpacing.md)
                    }.font(AppTypography.sectionTitle).appSurface()
                    EditorValidation(messages: issues + (error.map { [$0] } ?? []))
                }.padding(AppSpacing.page)
            }.scrollDismissesKeyboard(.interactively).background(AppColors.canvas)
                .navigationTitle(original == nil ? "新建课程" : "编辑课程").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { if draft != initial { exit = true } else { dismiss() } }
                    }
                    ToolbarItem(placement: .confirmationAction) { Button("保存") { commit() }.disabled(!issues.isEmpty) }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成输入") { focused = nil } }
                }
        }.appSheet(expanded: true)
            .modifier(DraftExitModifier(dirty: draft != initial, confirming: $exit) { dismiss() })
            .sheet(item: $editingSchedule) { schedule in
                CourseScheduleEditor(schedule: schedule, parent: draft, page: page) { value, acknowledged in
                    withAnimation(AppMotion.content(reduceMotion: reduceMotion)) {
                        draft.schedules.removeAll { $0.id == value.id }
                        draft.schedules.append(value)
                    }
                    accepted.append(contentsOf: acknowledged)
                    AppHaptics.selected()
                }
            }
            .sheet(isPresented: $showConflicts, onDismiss: {
                if pendingCommit { pendingCommit = false; commit() }
            }) {
                CourseConflictSheet(courseName: draft.name, conflicts: conflicts,
                    returnToEditing: { showConflicts = false }, accept: {
                        accepted = conflicts; showConflicts = false
                        // Defer outer dismissal until this confirmation sheet has closed.
                        pendingCommit = true
                    })
            }
    }
    @State private var pendingCommit = false
    private var basicInformation: some View {
        EditorGroup("课程信息") {
            TextField("课程名称（必填）", text: $draft.name, axis: .vertical)
                .font(AppTypography.pageTitle).focused($focused, equals: .name)
                .frame(minHeight: AppSpacing.touchTarget)
                .accessibilityLabel("课程名称，必填")
            Divider()
            TextField("教师（可选）", text: $draft.teacher, axis: .vertical)
                .font(AppTypography.body).focused($focused, equals: .teacher).accessibilityLabel("教师，可选")
                .frame(minHeight: AppSpacing.touchTarget)
            TextField("默认地点（可选）", text: $draft.location, axis: .vertical)
                .font(AppTypography.body).focused($focused, equals: .location).accessibilityLabel("默认地点，可选")
                .frame(minHeight: AppSpacing.touchTarget)
            Text("每个上课安排可以单独设置地点。")
                .font(AppTypography.caption).foregroundStyle(.secondary)
        }.appSurface(accent: draft.color.swiftUIColor)
    }
    private var arrangements: some View {
        EditorGroup("上课安排") {
            ForEach(draft.sortedSchedules) { schedule in
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Button { focused = nil; editingSchedule = schedule } label: {
                        ScheduleSummary(schedule: schedule, defaultLocation: draft.location,
                            slots: page.slots, totalWeeks: page.totalWeeks)
                            .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(AppPressStyle()).foregroundStyle(.primary)
                    Button("移除此安排", role: .destructive) {
                        withAnimation(AppMotion.content(reduceMotion: reduceMotion)) { draft.schedules.removeAll { $0.id == schedule.id } }
                        AppHaptics.selected()
                    }.buttonStyle(AppButtonStyle(.destructive))
                    Divider()
                }
            }
            Button {
                focused = nil
                let section = page.slots.first?.sectionNumber ?? 1
                editingSchedule = CourseScheduleDraft(startSection: section, endSection: section,
                    activeWeeks: Set(1...page.totalWeeks))
            } label: { Label("添加上课安排", systemImage: "plus") }
                .buttonStyle(AppButtonStyle(.secondary)).disabled(page.slots.isEmpty)
            if page.slots.isEmpty {
                Text("请先在课程页面的作息时间中配置节次。")
                    .font(AppTypography.secondary).foregroundStyle(.secondary)
            }
        }.appSurface()
    }
    private var appearance: some View {
        DisclosureGroup {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: swatchWidth))], spacing: AppSpacing.md) {
                ForEach(CourseColor.allCases, id: \.self) { color in
                    Button { draft.color = color; AppHaptics.selected() } label: {
                        Image(systemName: draft.color == color ? "checkmark.circle.fill" : "circle.fill")
                            .font(AppTypography.pageTitle).foregroundStyle(color.swiftUIColor)
                            .frame(minWidth: AppSpacing.touchTarget, minHeight: AppSpacing.touchTarget)
                            .contentShape(Rectangle())
                    }.buttonStyle(AppPressStyle())
                        .accessibilityLabel(color.displayName)
                        .accessibilityValue(draft.color == color ? "已选择" : "未选择")
                }
            }.padding(.top, AppSpacing.md)
        } label: {
            HStack { Text("课程颜色"); Spacer(); AppTag(title: draft.color.displayName, symbol: "circle.fill", tint: draft.color.swiftUIColor) }
        }.font(AppTypography.sectionTitle).appSurface()
    }
    private func commit() {
        error = nil; focused = nil
        do { try save(draft, accepted); AppHaptics.success(); dismiss() }
        catch CourseWriteError.conflicts(let found) { conflicts = found; showConflicts = true }
        catch { self.error = error.localizedDescription }
    }
}
