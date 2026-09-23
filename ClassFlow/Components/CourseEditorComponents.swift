import SwiftUI
import ClassFlowCore

enum CourseDisplayText {
    static func schedule(_ schedule: CourseScheduleDraft) -> String {
        "\(Weekday(rawValue: schedule.weekday)?.chineseName ?? "请选择星期") · 第\(schedule.startSection)–\(schedule.endSection)节"
    }
    static func time(_ schedule: CourseScheduleDraft, slots: [TimeSlotDefinition]) -> String {
        guard let first = slots.first(where: { $0.sectionNumber == schedule.startSection }),
              let last = slots.first(where: { $0.sectionNumber == schedule.endSection }) else {
            return "请配置对应节次时间"
        }
        return "\(WeekScheduleDisplayText.minute(first.startMinute))–\(WeekScheduleDisplayText.minute(last.endMinute))"
    }
}

@MainActor
struct EditorGroup<Content: View>: View {
    let title: String
    let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(title).font(AppTypography.sectionTitle).accessibilityAddTraits(.isHeader)
            content
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

@MainActor
struct ScheduleSummary: View {
    let schedule: CourseScheduleDraft
    let defaultLocation: String
    let slots: [TimeSlotDefinition]
    let totalWeeks: Int
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(CourseDisplayText.schedule(schedule)).font(AppTypography.courseTitle)
            Text(CourseDisplayText.time(schedule, slots: slots)).font(AppTypography.secondary)
            Text(schedule.location.isEmpty ? defaultLocation : schedule.location)
                .font(AppTypography.secondary).foregroundStyle(.secondary)
            Text(ActiveWeeksFormatter.string(Array(schedule.activeWeeks), totalWeeks: totalWeeks))
                .font(AppTypography.caption).foregroundStyle(.secondary)
        }.fixedSize(horizontal: false, vertical: true)
    }
}

@MainActor
struct EditorValidation: View {
    let messages: [String]
    var body: some View {
        if !messages.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                    Label(message, systemImage: "exclamationmark.circle")
                        .font(AppTypography.secondary).foregroundStyle(AppColors.warning)
                }
            }
        }
    }
}
