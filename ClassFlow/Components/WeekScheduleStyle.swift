import SwiftUI
import ClassFlowCore

enum WeekScheduleStyle {
    static let metrics = ScheduleLayoutMetrics.standard
    static let timeColumnWidth: CGFloat = 58
    static let headerHeight: CGFloat = 78
    static let gridCornerRadius: CGFloat = AppRadius.medium
    static let courseCornerRadius: CGFloat = AppRadius.small
}

extension Weekday {
    var shortChineseName: String {
        switch self {
        case .monday: "一"
        case .tuesday: "二"
        case .wednesday: "三"
        case .thursday: "四"
        case .friday: "五"
        case .saturday: "六"
        case .sunday: "日"
        }
    }
}

enum WeekScheduleDisplayText {
    static func dateRange(_ snapshot: WeekScheduleSnapshot) -> String {
        let start = snapshot.startDate
        let end = snapshot.endDate
        if start.year != end.year {
            return "\(start.year)年\(start.month)月\(start.day)日 – \(end.year)年\(end.month)月\(end.day)日"
        }
        if start.month != end.month {
            return "\(start.month)月\(start.day)日 – \(end.month)月\(end.day)日"
        }
        return "\(start.month)月\(start.day)日 – \(end.day)日"
    }

    static func minute(_ value: Int) -> String {
        String(format: "%02d:%02d", value / 60, value % 60)
    }

    static func compactStatus(_ day: DayScheduleSnapshot) -> String? {
        switch day.dayStatus {
        case .normal: return nil
        case .holiday: return compact(day.specialTitle ?? "放假", fallback: "放假")
        case let .adjustedWorkday(weekday): return "调休·按\(weekday.shortChineseName)"
        case let .schoolOverride(weekday):
            return weekday.map { "调课·按\($0.shortChineseName)" } ?? "调课"
        case .needsConfirmation: return "调休 ?"
        }
    }

    static func detailStatus(_ day: DayScheduleSnapshot) -> String {
        switch day.dayStatus {
        case .normal: return "普通教学日"
        case .holiday: return day.specialTitle ?? "今日放假"
        case let .adjustedWorkday(weekday): return "调休 · 按\(weekday.chineseName)课表"
        case let .schoolOverride(weekday):
            return weekday.map { "学校特殊安排 · 按\($0.chineseName)课表" } ?? "学校特殊安排"
        case .needsConfirmation: return "调休 · 尚未确认执行课表"
        }
    }

    private static func compact(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        return String(trimmed.prefix(4))
    }
}
