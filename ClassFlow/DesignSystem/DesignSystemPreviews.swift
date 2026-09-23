import SwiftUI
import ClassFlowCore

#if DEBUG
private struct DesignSystemGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                Text("ClassFlow").font(AppTypography.largeTitle)
                Text("安静、清晰的时间秩序").font(AppTypography.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: AppSpacing.md) {
                    ForEach(CourseAccent.allCases, id: \.rawValue) { accent in
                        AppTag(title: accent.rawValue, symbol: "circle.fill", tint: accent.color)
                    }
                }
                AppTag(title: "调休 · 按周一", symbol: "arrow.triangle.2.circlepath", tint: AppColors.accent)
                Button("主要操作") {}.buttonStyle(AppButtonStyle(.primary))
                Button("次要操作") {}.buttonStyle(AppButtonStyle(.secondary))
                AppEmptyState(title: "今天没有课程", message: "可以安心安排自己的时间。", symbol: "leaf")
            }
            .padding(AppSpacing.page)
        }
        .background(AppColors.canvas)
    }
}

#Preview("Design System · Light") { DesignSystemGallery().preferredColorScheme(.light) }
#Preview("Design System · Dark") { DesignSystemGallery().preferredColorScheme(.dark) }
#Preview("Today · 小屏长文字", traits: .fixedLayout(width: 320, height: 568)) {
    let course = TodayPreviewData.occurrence("现代大学英语与跨文化交流 Academic Communication",
        startOffset: 0, duration: 6000, sections: 1...2)
    PrimaryCourseCard(item: TodayCourseItem(occurrence: course, status: .current),
        countdown: .endsIn(minutes: 32), timeZoneID: "Asia/Shanghai")
        .padding(AppSpacing.page).background(AppColors.canvas)
}
#Preview("Today · Dark · 最大字体") {
    TodayPageView(page: TodayPreviewData.ordinary, onChooseWeekday: {}, onReload: {})
        .environment(\.dynamicTypeSize, .accessibility5).preferredColorScheme(.dark)
}
#Preview("详情 · 长教师地点") {
    if let page = try? WeekSchedulePreviewData.page(.longText),
       let course = page.layoutItems.first?.occurrence {
        CourseDetailSheet(course: course, timeZoneID: page.timeZoneID)
            .environment(\.dynamicTypeSize, .accessibility2)
    }
}
#Preview("调休选择 · 大字体") {
    ReplacementWeekdaySheet { _ in false }.environment(\.dynamicTypeSize, .accessibility3)
}
#endif
