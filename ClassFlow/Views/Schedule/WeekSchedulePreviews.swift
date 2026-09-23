import SwiftUI
import ClassFlowCore

#if DEBUG

private struct WeekSchedulePreviewHost: View {
    let scenario: WeekPreviewScenario

    var body: some View {
        if let page = try? WeekSchedulePreviewData.page(scenario) {
            NavigationStack {
                WeekSchedulePageView(page: page, onPrevious: {}, onNext: {}, onCurrent: {},
                    onPendingDay: { _ in })
                    .navigationTitle("课表")
                    .navigationBarTitleDisplayMode(.inline)
            }
        } else {
            ContentUnavailableView("预览数据无效", systemImage: "exclamationmark.triangle")
        }
    }
}

#Preview("普通完整一周") { WeekSchedulePreviewHost(scenario: .ordinary) }
#Preview("课程较少") { WeekSchedulePreviewHost(scenario: .sparse) }
#Preview("课程较多") { WeekSchedulePreviewHost(scenario: .dense) }
#Preview("单周") { WeekSchedulePreviewHost(scenario: .oddWeek) }
#Preview("双周") { WeekSchedulePreviewHost(scenario: .evenWeek) }
#Preview("自定义教学周") { WeekSchedulePreviewHost(scenario: .customWeeks) }
#Preview("两门冲突") { WeekSchedulePreviewHost(scenario: .twoConflicts) }
#Preview("三门冲突") { WeekSchedulePreviewHost(scenario: .threeConflicts) }
#Preview("连续多节课程") { WeekSchedulePreviewHost(scenario: .longCourse) }
#Preview("节假日") { WeekSchedulePreviewHost(scenario: .holiday) }
#Preview("调休按周一") { WeekSchedulePreviewHost(scenario: .adjustedMonday) }
#Preview("调休按周五") { WeekSchedulePreviewHost(scenario: .adjustedFriday) }
#Preview("未确认调休") { WeekSchedulePreviewHost(scenario: .pending) }
#Preview("深色模式") {
    WeekSchedulePreviewHost(scenario: .ordinary).preferredColorScheme(.dark)
}
#Preview("小尺寸 iPhone", traits: .fixedLayout(width: 320, height: 568)) {
    WeekSchedulePreviewHost(scenario: .dense)
}
#Preview("大字体") {
    WeekSchedulePreviewHost(scenario: .ordinary).environment(\.dynamicTypeSize, .accessibility2)
}
#Preview("长中英文 · 深色 · 大字体") {
    WeekSchedulePreviewHost(scenario: .longText)
        .environment(\.dynamicTypeSize, .accessibility3).preferredColorScheme(.dark)
}
#Preview("长文字 · 大屏", traits: .fixedLayout(width: 430, height: 932)) {
    WeekSchedulePreviewHost(scenario: .longText)
}
#Preview("辅助功能 · 跟随系统设置") {
    // Read-only accessibility environment values come from the system. Review
    // with Reduce Motion and Increase Contrast enabled on the preview device / Simulator.
    WeekSchedulePreviewHost(scenario: .threeConflicts)
}
#endif
