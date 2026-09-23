import SwiftUI
import ClassFlowCore

struct TodayPageView: View {
    let page: TodayPageModel
    let onChooseWeekday: () -> Void
    let onReload: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var snapshot: TodaySnapshot { page.snapshot }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.page) {
                TodayHeaderView(page: page)

                if let primary = snapshot.currentCourse ?? snapshot.nextCourse {
                    PrimaryCourseCard(item: primary, countdown: snapshot.countdown,
                                      timeZoneID: page.timeZoneID)
                        .id(primary.id + primary.status.rawValue)
                        .transition(.opacity)
                }

                if snapshot.dayKind == .holiday {
                    HolidayEmptyCard(title: snapshot.specialDayTitle)
                } else if snapshot.dayKind == .needsConfirmation {
                    EmptyView()
                } else if snapshot.courses.isEmpty {
                    TodayEmptyCard(position: snapshot.academicPosition)
                } else {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("今日课程")
                            .font(AppTypography.sectionTitle)
                        ForEach(snapshot.courses) { item in
                            TodayCourseRow(item: item, timeZoneID: page.timeZoneID)
                            if item.id != snapshot.courses.last?.id { Divider() }
                        }
                    }
                }

                switch snapshot.dayKind {
                case .needsConfirmation:
                    PendingOverrideCard(title: snapshot.specialDayTitle, action: onChooseWeekday)
                case .adjustedWorkday, .schoolOverride:
                    SpecialDayCard(snapshot: snapshot)
                default: EmptyView()
                }
            }
            .padding(.horizontal, AppSpacing.page)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.xxl)
        }
        .animation(reduceMotion ? nil : AppMotion.content(reduceMotion: false),
                   value: (snapshot.currentCourse ?? snapshot.nextCourse).map { $0.id + $0.status.rawValue })
        .refreshable { onReload() }
    }
}

private struct TodayHeaderView: View {
    let page: TodayPageModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
                    dateText
                    weekdayText
                }
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    dateText
                    weekdayText
                }
            }
            Text(TodayDisplayText.academic(page.snapshot.academicPosition))
                .font(AppTypography.courseTitle)
            if let title = page.snapshot.specialDayTitle {
                AppTag(title: title, tint: AppColors.accent)
            }
            Text(page.semesterName)
                .font(AppTypography.secondary)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var dateText: some View {
        Text("\(page.snapshot.day.month)月\(page.snapshot.day.day)日")
            .font(AppTypography.largeTitle)
    }

    private var weekdayText: some View {
        Text(page.snapshot.day.weekday.chineseName)
            .font(AppTypography.sectionTitle.weight(.medium))
            .foregroundStyle(.secondary)
    }
}

private struct SpecialDayCard: View {
    let snapshot: TodaySnapshot

    private var content: (icon: String, title: String, detail: String) {
        switch snapshot.dayKind {
        case .holiday:
            ("sparkles", snapshot.specialDayTitle ?? "节假日", "今日放假")
        case let .adjustedWorkday(weekday):
            ("arrow.triangle.2.circlepath", "调休", "今日按\(weekday.chineseName)课表")
        case let .schoolOverride(weekday):
            ("building.columns", "学校特殊安排",
             weekday.map { "今日按\($0.chineseName)课表" } ?? "今日按原课表上课")
        default:
            ("calendar", "今日安排", "")
        }
    }

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(content.title).font(AppTypography.courseTitle)
                Text(content.detail).font(AppTypography.secondary).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: content.icon)
                .font(AppTypography.sectionTitle)
                .foregroundStyle(Color.accentColor)
        }
        .padding(.vertical, AppSpacing.sm)
        .accessibilityElement(children: .combine)
    }
}

private struct PendingOverrideCard: View {
    let title: String?
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label("检测到调休", systemImage: "calendar.badge.exclamationmark")
                .font(AppTypography.courseTitle)
            if let title, !title.isEmpty {
                Text(title).font(AppTypography.secondary).foregroundStyle(.secondary)
            }
            Text("尚未确定今天执行哪一天课表。确认前不会显示推测的课程。")
                .font(AppTypography.secondary)
                .foregroundStyle(.secondary)
            Button("选择今天的课表", action: action)
                .buttonStyle(AppButtonStyle(.primary))
        }
        .todayCard()
    }
}

private struct HolidayEmptyCard: View {
    let title: String?

    var body: some View {
        AppEmptyState(title: title ?? "今日放假",
            message: "普通课程今日不显示，祝你度过轻松的一天。", symbol: "sun.max")
    }
}

private struct TodayEmptyCard: View {
    let position: AcademicPosition

    var body: some View {
        let content: (String, String, String) = switch position {
        case .beforeSemester:
            ("calendar.badge.clock", "学期尚未开始", "开学后，这里会显示当天的课程。")
        case .afterSemester:
            ("checkmark.circle", "本学期已结束", "今天没有需要显示的课程。")
        default:
            ("leaf", "今天没有课程", "可以安心安排自己的时间。")
        }
        AppEmptyState(title: content.1, message: content.2, symbol: content.0)
    }
}
