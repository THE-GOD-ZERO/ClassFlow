import SwiftUI
import SwiftData
import ClassFlowCore

@MainActor
struct CoursesView: View {
    @StateObject private var model: CoursesViewModel
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase
    @State private var detail: CourseDraft?
    @State private var editor: EditorRequest?
    @State private var deleting: CourseDraft?
    @State private var showingDelete = false
    @State private var showingTimes = false
    @State private var error: String?
    let setupSemester: () -> Void
    init(container: ModelContainer, setupSemester: @escaping () -> Void) {
        _model = StateObject(wrappedValue: CoursesViewModel(container: container)); self.setupSemester = setupSemester
    }
    private struct EditorRequest: Identifiable { let draft: CourseDraft; let original: CourseDraft?; var id: UUID { draft.id } }
    private var repository: CourseRepository { CourseRepository(container: model.container) }
    var body: some View {
        NavigationStack {
            CoursesPageView(page: model.page, courses: model.filteredCourses,
                searching: !model.search.isEmpty, error: error ?? model.error,
                add: newCourse, configureTimes: { showingTimes = true }, setupSemester: setupSemester,
                open: { detail = $0 }, edit: { editor = EditorRequest(draft: $0, original: $0) },
                delete: { deleting = $0; showingDelete = true })
                .navigationTitle("课程")
                .searchable(text: $model.search, prompt: "搜索课程、教师或地点")
                .toolbar {
                    if model.page != nil {
                        ToolbarItem(placement: .primaryAction) {
                            Button("添加课程", systemImage: "plus", action: newCourse).frame(minWidth: AppSpacing.touchTarget, minHeight: AppSpacing.touchTarget)
                        }
                        ToolbarItem(placement: .secondaryAction) {
                            Button("作息时间", systemImage: "clock") { showingTimes = true }
                        }
                    }
                }
        }
        .onAppear { model.reload() }
        .onChange(of: environment.scheduleRevision) { _, _ in model.reload() }
        .onChange(of: scenePhase) { _, value in if value == .active { model.reload() } }
        .sheet(item: $editor) { request in
            if let page = model.page {
                CourseEditor(draft: request.draft, original: request.original, page: page) { draft, conflicts in
                    try repository.save(draft, semesterID: page.semesterID, original: request.original, acceptedConflicts: conflicts)
                    changed()
                }
            }
        }
        .sheet(item: $detail) { course in
            if let page = model.page {
                CourseManagementDetail(course: course, page: page, save: { draft, original, conflicts in
                    try repository.save(draft, semesterID: page.semesterID, original: original, acceptedConflicts: conflicts)
                    changed(); return try CourseDraft(draft.definition())
                }, delete: { value in try repository.delete(value, semesterID: page.semesterID); changed() })
            }
        }
        .sheet(isPresented: $showingTimes) {
            if let page = model.page {
                TimeSlotEditor(slots: page.slots) { slots in
                    try repository.saveTimeSlots(slots, semesterID: page.semesterID); changed()
                }
            }
        }
        .confirmationDialog("删除“\(deleting?.name ?? "课程")”？", isPresented: $showingDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                guard let course = deleting, let page = model.page else { return }
                do { try repository.delete(course, semesterID: page.semesterID); changed(); AppHaptics.warning() }
                catch { self.error = error.localizedDescription }
                deleting = nil
            }
            Button("取消", role: .cancel) { deleting = nil }
        } message: { Text("将同时删除这门课程的 \(deleting?.schedules.count ?? 0) 个上课安排。此操作无法撤销。") }
    }
    private func newCourse() {
        guard let page = model.page else { return }
        if page.slots.isEmpty { showingTimes = true; return }
        editor = EditorRequest(draft: CourseDraft(color: CourseColorAllocator.next(used: page.courses.map(\.color))), original: nil)
    }
    private func changed() { error = nil; environment.scheduleDataDidChange() }
}

@MainActor
struct CoursesPageView: View {
    let page: CoursesPageModel?
    let courses: [CourseDraft]
    let searching: Bool
    let error: String?
    let add: () -> Void
    let configureTimes: () -> Void
    let setupSemester: () -> Void
    let open: (CourseDraft) -> Void
    let edit: (CourseDraft) -> Void
    let delete: (CourseDraft) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                if let error { EditorValidation(messages: [error]) }
                if let page {
                    Text(page.semesterName).font(AppTypography.secondary).foregroundStyle(.secondary)
                    if page.slots.isEmpty {
                        AppEmptyState(title: "设置学校作息", message: "先配置节次时间，再添加课程。", symbol: "clock",
                            actionTitle: "设置作息时间", action: configureTimes)
                    } else if courses.isEmpty {
                        AppEmptyState(title: searching ? "没有找到课程" : "还没有课程",
                            message: searching ? "试试其他课程名、教师或地点。" : "添加第一门课程后，ClassFlow 会自动生成 Today 和周课表。",
                            symbol: "books.vertical", actionTitle: searching ? nil : "添加课程", action: searching ? nil : add)
                    } else {
                        ForEach(courses) { course in
                            Button { open(course) } label: { CourseRow(course: course) }
                                .buttonStyle(AppPressStyle()).foregroundStyle(.primary)
                                .contextMenu {
                                    Button("编辑", systemImage: "pencil") { edit(course) }
                                    Button("删除", systemImage: "trash", role: .destructive) { delete(course) }
                                }
                                .transition(.opacity)
                        }
                    }
                } else if error == nil {
                    AppEmptyState(title: "先创建一个学期", message: "设置开学日期和总教学周后，即可录入课程。",
                        symbol: "calendar.badge.plus", actionTitle: "前往设置学期", action: setupSemester)
                }
            }.padding(AppSpacing.page)
                .animation(AppMotion.content(reduceMotion: reduceMotion), value: courses.map(\.id))
        }.background(AppColors.canvas)
    }
}

@MainActor
struct CourseRow: View {
    let course: CourseDraft
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(course.name).font(AppTypography.courseTitle).fixedSize(horizontal: false, vertical: true)
            Text([course.teacher, "\(course.schedules.count) 个上课安排"].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(AppTypography.secondary).foregroundStyle(.secondary)
            if !course.location.isEmpty { Text(course.location).font(AppTypography.caption).foregroundStyle(.secondary) }
            ForEach(course.sortedSchedules.prefix(2)) { schedule in
                Text(CourseDisplayText.schedule(schedule)).font(AppTypography.caption).foregroundStyle(.secondary)
            }
            if course.schedules.count > 2 { Text("+\(course.schedules.count - 2) 个安排").font(AppTypography.caption).foregroundStyle(.secondary) }
        }.appSurface(accent: course.color.swiftUIColor).contentShape(Rectangle())
            .accessibilityElement(children: .combine)
    }
}
