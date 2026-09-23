import SwiftUI
import ClassFlowCore

/// Reuses the same resolved week: large type never has to fit inside a fixed-height grid.
struct WeekAccessibleAgenda: View {
    let page: WeekSchedulePageModel
    let onCourse: (CourseOccurrence) -> Void
    let onDay: (DayScheduleSnapshot) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.xl) {
                ForEach(page.snapshot.days) { day in
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Button { onDay(day) } label: {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("\(day.date.month)/\(day.date.day) · \(day.realWeekday.chineseName)")
                                    .font(AppTypography.sectionTitle)
                                Text(WeekScheduleDisplayText.detailStatus(day))
                                    .font(AppTypography.secondary).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: AppSpacing.touchTarget, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(AppPressStyle())
                        if day.courses.isEmpty {
                            Text(day.dayStatus == .needsConfirmation ? "点按日期确认课表" : "没有课程")
                                .font(AppTypography.secondary).foregroundStyle(.secondary)
                        }
                        ForEach(day.courses) { course in
                            Button { onCourse(course) } label: {
                                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                    Text(course.courseName).font(AppTypography.courseTitle)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(TodayDisplayText.timeRange(course, timeZoneID: page.timeZoneID))
                                        .font(AppTypography.secondary)
                                    if !course.location.isEmpty {
                                        Text(course.location).font(AppTypography.secondary)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .appSurface(accent: course.color.swiftUIColor)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(AppPressStyle())
                        }
                    }
                }
            }
            .padding(AppSpacing.page)
        }
    }
}
