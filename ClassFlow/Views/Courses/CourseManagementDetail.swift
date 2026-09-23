import SwiftUI
import ClassFlowCore

@MainActor
struct CourseManagementDetail: View {
    @State var course: CourseDraft
    let page: CoursesPageModel
    let save: (CourseDraft, CourseDraft, [DraftConflict]) throws -> CourseDraft
    let delete: (CourseDraft) throws -> Void
    @State private var editing = false
    @State private var deleting = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        AppTag(title: course.color.displayName, symbol: "circle.fill", tint: course.color.swiftUIColor)
                        Text(course.name).font(AppTypography.pageTitle).fixedSize(horizontal: false, vertical: true)
                        if !course.teacher.isEmpty { Label(course.teacher, systemImage: "person").font(AppTypography.secondary) }
                        if !course.location.isEmpty { Label(course.location, systemImage: "mappin").font(AppTypography.secondary) }
                    }
                    EditorGroup("上课安排 · \(course.schedules.count)") {
                        ForEach(course.sortedSchedules) { schedule in
                            ScheduleSummary(schedule: schedule, defaultLocation: course.location, slots: page.slots, totalWeeks: page.totalWeeks)
                            Divider()
                        }
                    }
                    if !course.note.isEmpty { EditorGroup("备注") { Text(course.note).font(AppTypography.body).textSelection(.enabled) } }
                    EditorValidation(messages: error.map { [$0] } ?? [])
                    Button("删除课程", role: .destructive) { deleting = true }.buttonStyle(AppButtonStyle(.destructive))
                }.padding(AppSpacing.page)
            }.background(AppColors.canvas)
                .navigationTitle("课程详情").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
                    ToolbarItem(placement: .primaryAction) { Button("编辑") { editing = true } }
                }
        }.appSheet()
            .sheet(isPresented: $editing) {
                CourseEditor(draft: course, original: course, page: page) { draft, conflicts in
                    course = try save(draft, course, conflicts)
                }
            }
            .confirmationDialog("删除“\(course.name)”？", isPresented: $deleting, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    do { try delete(course); AppHaptics.warning(); dismiss() } catch { self.error = error.localizedDescription }
                }
                Button("取消", role: .cancel) {}
            } message: { Text("将同时删除这门课程的 \(course.schedules.count) 个上课安排。此操作无法撤销。") }
    }
}
