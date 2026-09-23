import SwiftUI
import ClassFlowCore

#if DEBUG
enum TodayPreviewData {
    static let anchor = Date(timeIntervalSinceReferenceDate: 0) // 08:00 in Asia/Shanghai
    static let day = LocalDay(date: anchor, timeZone: LocalDay.schoolTimeZone)

    static func occurrence(_ name: String, startOffset: TimeInterval, duration: TimeInterval,
                           sections: ClosedRange<Int>, color: CourseColor = .blue) -> CourseOccurrence {
        CourseOccurrence(courseID: UUID(), scheduleID: UUID(), day: day, courseName: name,
            teacher: "王老师", location: "A301", color: color,
            startSection: sections.lowerBound, endSection: sections.upperBound,
            start: anchor.addingTimeInterval(startOffset),
            end: anchor.addingTimeInterval(startOffset + duration))
    }

    static func page(kind: TodayDayKind = .normal, items: [TodayCourseItem] = [],
                     current: TodayCourseItem? = nil, next: TodayCourseItem? = nil,
                     countdown: TodayCountdown? = nil, title: String? = nil) -> TodayPageModel {
        let snapshot = TodaySnapshot(day: day, academicPosition: .week(3), effectiveWeekday: .monday,
            dayKind: kind, specialDayTitle: title, appliedOverride: nil, courses: items,
            currentCourse: current, nextCourse: next, countdown: countdown, issues: [])
        return TodayPageModel(semesterID: UUID(), semesterName: "2026-2027 第一学期",
                              timeZoneID: "Asia/Shanghai", snapshot: snapshot)
    }

    static var ordinary: TodayPageModel {
        let finished = TodayCourseItem(occurrence: occurrence("大学英语", startOffset: 0,
            duration: 6_000, sections: 1...2, color: .teal), status: .finished)
        let next = TodayCourseItem(occurrence: occurrence("高等数学", startOffset: 7_200,
            duration: 6_000, sections: 3...4, color: .blue), status: .next)
        let upcoming = TodayCourseItem(occurrence: occurrence("程序设计", startOffset: 14_400,
            duration: 6_000, sections: 5...6, color: .purple), status: .upcoming)
        return page(items: [finished, next, upcoming], next: next, countdown: .startsIn(minutes: 26))
    }

    static var current: TodayPageModel {
        let item = TodayCourseItem(occurrence: occurrence("高等数学", startOffset: 0,
            duration: 6_000, sections: 1...2), status: .current)
        return page(items: [item], current: item, countdown: .endsIn(minutes: 32))
    }
}

#Preview("普通有课日") {
    TodayPageView(page: TodayPreviewData.ordinary, onChooseWeekday: {}, onReload: {})
}

#Preview("正在上课") {
    TodayPageView(page: TodayPreviewData.current, onChooseWeekday: {}, onReload: {})
}

#Preview("下一节课") {
    let item = TodayCourseItem(occurrence: TodayPreviewData.occurrence("线性代数", startOffset: 7_200,
        duration: 6_000, sections: 3...4, color: .green), status: .next)
    TodayPageView(page: TodayPreviewData.page(items: [item], next: item, countdown: .startsIn(minutes: 135)),
                  onChooseWeekday: {}, onReload: {})
}

#Preview("没有课程") {
    TodayPageView(page: TodayPreviewData.page(), onChooseWeekday: {}, onReload: {})
}

#Preview("节假日") {
    TodayPageView(page: TodayPreviewData.page(kind: .holiday, title: "国庆节"),
                  onChooseWeekday: {}, onReload: {})
}

#Preview("调休按星期一") {
    TodayPageView(page: TodayPreviewData.page(kind: .adjustedWorkday(.monday),
                  items: TodayPreviewData.ordinary.snapshot.courses,
                  next: TodayPreviewData.ordinary.snapshot.nextCourse,
                  countdown: .startsIn(minutes: 26), title: "调休"),
                  onChooseWeekday: {}, onReload: {})
}

#Preview("调休未确认") {
    TodayPageView(page: TodayPreviewData.page(kind: .needsConfirmation, title: "调休上班"),
                  onChooseWeekday: {}, onReload: {})
}

#Preview("没有学期") {
    TodayScreenContent(state: .noSemester(TodayPreviewData.day),
                       onSetUpSemester: {}, onChooseWeekday: {}, onRetry: {})
}
#endif
