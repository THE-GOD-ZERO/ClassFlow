import SwiftUI
import ClassFlowCore

struct PrimaryCourseCard: View {
    let item: TodayCourseItem
    let countdown: TodayCountdown?
    let timeZoneID: String

    private var isCurrent: Bool { item.status == .current }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    statusHeading
                    Spacer()
                    countdownLabel
                }
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    statusHeading
                    countdownLabel
                }
            }
            Text(item.occurrence.courseName)
                .font(AppTypography.pageTitle)
                .fixedSize(horizontal: false, vertical: true)
            Label(TodayDisplayText.timeRange(item.occurrence, timeZoneID: timeZoneID), systemImage: "clock")
            if !item.occurrence.location.isEmpty {
                Label(item.occurrence.location, systemImage: "mappin.and.ellipse")
            }
            if !item.occurrence.teacher.isEmpty {
                Label(item.occurrence.teacher, systemImage: "person")
                    .foregroundStyle(.secondary)
            }
        }
        .appSurface(accent: item.occurrence.color.swiftUIColor)
        .accessibilityElement(children: .combine)
    }

    private var statusHeading: some View {
        Label(isCurrent ? "正在上课" : "下一节",
              systemImage: isCurrent ? "play.circle.fill" : "arrow.right.circle.fill")
            .font(AppTypography.courseTitle)
            .foregroundStyle(item.occurrence.color.swiftUIColor)
    }

    @ViewBuilder
    private var countdownLabel: some View {
        if let countdown {
            Text(countdownText(countdown))
                .font(AppTypography.secondary.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
    }

    private func countdownText(_ countdown: TodayCountdown) -> String {
        switch countdown {
        case let .startsIn(minutes): "还有\(TodayDisplayText.duration(minutes: minutes))开始"
        case let .endsIn(minutes): "还有\(TodayDisplayText.duration(minutes: minutes))结束"
        }
    }
}

struct TodayCourseRow: View {
    let item: TodayCourseItem
    let timeZoneID: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        courseName
                        Spacer(minLength: AppSpacing.sm)
                        statusLabel
                    }
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        courseName
                        statusLabel
                    }
                }
                Text(TodayDisplayText.timeRange(item.occurrence, timeZoneID: timeZoneID))
                    .font(AppTypography.secondary.weight(.medium))
                HStack(spacing: AppSpacing.sm) {
                    Text(TodayDisplayText.sections(item.occurrence))
                    if !item.occurrence.location.isEmpty {
                        Text("·")
                        Text(item.occurrence.location)
                    }
                }
                .font(AppTypography.secondary)
                .foregroundStyle(.secondary)
                if !item.occurrence.teacher.isEmpty {
                    Label(item.occurrence.teacher, systemImage: "person")
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, AppSpacing.md)
        .padding(.leading, AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            Capsule().fill(item.occurrence.color.swiftUIColor)
                .frame(width: AppSpacing.accentWidth).padding(.vertical, AppSpacing.lg)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private var courseName: some View {
        Text(item.occurrence.courseName)
            .font(AppTypography.courseTitle)
            .foregroundStyle(item.status == .finished ? Color.secondary : Color.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var statusLabel: some View {
        let value: (String, String) = switch item.status {
        case .finished: ("checkmark.circle", "已结束")
        case .current: ("play.circle.fill", "进行中")
        case .next: ("arrow.right.circle.fill", "下一节")
        case .upcoming: ("clock", "稍后")
        }
        AppTag(title: value.1, symbol: value.0,
            tint: item.status == .finished ? .secondary : item.occurrence.color.swiftUIColor)
    }
}
