import SwiftUI
import ClassFlowCore

struct WeekCourseCard: View {
    let item: CourseLayoutItem

    var body: some View {
        ViewThatFits(in: .vertical) {
            cardContent(details: true)
            cardContent(details: false)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(item.occurrence.color.swiftUIColor.opacity(AppColors.tintOpacity),
            in: RoundedRectangle(cornerRadius: AppRadius.small))
        .overlay(alignment: .leading) {
            Capsule().fill(item.occurrence.color.swiftUIColor)
                .frame(width: AppSpacing.accentWidth).padding(.vertical, AppSpacing.sm)
        }
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.occurrence.courseName)，\(TodayDisplayText.sections(item.occurrence))，\(item.occurrence.location)")
        .accessibilityHint("打开完整课程详情")
    }

    private func cardContent(details: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(item.occurrence.courseName)
                .font(AppTypography.gridTitle)
                .lineLimit(details ? 3 : 2)
            if details, !item.occurrence.location.isEmpty {
                Text(item.occurrence.location).font(AppTypography.micro)
                    .foregroundStyle(.secondary).lineLimit(1)
            }
            if details {
                Text(TodayDisplayText.sections(item.occurrence)).font(AppTypography.micro)
                    .foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }
}

struct CourseDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let course: CourseOccurrence
    let timeZoneID: String

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        AppTag(title: TodayDisplayText.sections(course), tint: course.color.swiftUIColor)
                        Text(course.courseName).font(AppTypography.pageTitle)
                            .fixedSize(horizontal: false, vertical: true)
                        if !course.teacher.isEmpty {
                            Label(course.teacher, systemImage: "person").font(AppTypography.secondary)
                        }
                        if !course.location.isEmpty {
                            Label(course.location, systemImage: "mappin.and.ellipse")
                                .font(AppTypography.secondary).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, AppSpacing.sm)
                }
                Section("时间") {
                    LabeledContent("时段", value: TodayDisplayText.timeRange(course, timeZoneID: timeZoneID))
                    LabeledContent("节次", value: TodayDisplayText.sections(course))
                    if !course.activeWeeks.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("教学周").font(AppTypography.caption).foregroundStyle(.secondary)
                            Text(ActiveWeeksFormatter.string(course.activeWeeks)).font(AppTypography.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if !course.note.isEmpty {
                    Section("备注") { Text(course.note) }
                }
            }
            .navigationTitle("课程详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
    }

}

struct DayScheduleDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let day: DayScheduleSnapshot

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("日期", value: "\(day.date.year)年\(day.date.month)月\(day.date.day)日")
                    LabeledContent("星期", value: day.realWeekday.chineseName)
                    LabeledContent("状态", value: WeekScheduleDisplayText.detailStatus(day))
                    if day.effectiveWeekday != day.realWeekday {
                        LabeledContent("执行课表", value: day.effectiveWeekday.chineseName)
                    }
                    if let week = day.academicWeek { LabeledContent("教学周", value: "第\(week)周") }
                }
                if let title = day.specialTitle, !title.isEmpty {
                    Section("安排说明") { Text(title) }
                }
            }
            .navigationTitle("当天安排")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
    }
}
