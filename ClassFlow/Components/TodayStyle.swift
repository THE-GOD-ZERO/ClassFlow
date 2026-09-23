import SwiftUI
import ClassFlowCore

extension Weekday {
    var chineseName: String {
        switch self {
        case .monday: "星期一"
        case .tuesday: "星期二"
        case .wednesday: "星期三"
        case .thursday: "星期四"
        case .friday: "星期五"
        case .saturday: "星期六"
        case .sunday: "星期日"
        }
    }
}


enum TodayDisplayText {
    static func academic(_ position: AcademicPosition) -> String {
        switch position {
        case .noSemester: "未设置学期"
        case .beforeSemester: "学期尚未开始"
        case let .week(number): "第\(number)教学周"
        case .afterSemester: "本学期已结束"
        }
    }

    static func timeRange(_ course: CourseOccurrence, timeZoneID: String) -> String {
        "\(time(course.start, timeZoneID: timeZoneID)) – \(time(course.end, timeZoneID: timeZoneID))"
    }

    static func time(_ date: Date, timeZoneID: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: timeZoneID) ?? .autoupdatingCurrent
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    static func sections(_ course: CourseOccurrence) -> String {
        course.startSection == course.endSection
            ? "第\(course.startSection)节"
            : "第\(course.startSection)–\(course.endSection)节"
    }

    static func duration(minutes: Int) -> String {
        let safeMinutes = max(0, minutes)
        let hours = safeMinutes / 60
        let minutesPart = safeMinutes % 60
        if hours == 0 { return "\(minutesPart)分钟" }
        if minutesPart == 0 { return "\(hours)小时" }
        return "\(hours)小时\(minutesPart)分钟"
    }
}

struct TodayCardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content.appSurface()
    }
}

extension View {
    func todayCard() -> some View { modifier(TodayCardSurface()) }
}
