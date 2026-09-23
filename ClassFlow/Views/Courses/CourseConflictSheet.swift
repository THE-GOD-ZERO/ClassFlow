import SwiftUI
import ClassFlowCore

@MainActor
struct CourseConflictSheet: View {
    let courseName: String
    let conflicts: [DraftConflict]
    let returnToEditing: () -> Void
    let accept: () -> Void
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    Text("请检查重叠安排。你仍然可以保存这门课程。")
                        .font(AppTypography.body).foregroundStyle(.secondary)
                    ForEach(conflicts) { conflict in
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("\(courseName) 与 \(conflict.otherCourseName)").font(AppTypography.courseTitle)
                            Text("\(Weekday(rawValue: conflict.weekday)?.chineseName ?? "") · 第\(conflict.startSection)–\(conflict.endSection)节")
                                .font(AppTypography.secondary)
                            Text(ActiveWeeksFormatter.string(conflict.weeks)).font(AppTypography.secondary).foregroundStyle(.secondary)
                        }.appSurface()
                    }
                    Button("仍然保存", action: accept).buttonStyle(AppButtonStyle(.secondary))
                }.padding(AppSpacing.page)
            }.background(AppColors.canvas)
                .navigationTitle("发现课程冲突").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("返回修改", action: returnToEditing) } }
        }.appSheet()
    }
}
