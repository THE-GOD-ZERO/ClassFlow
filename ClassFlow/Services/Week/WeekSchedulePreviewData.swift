import Foundation
import ClassFlowCore

#if DEBUG

enum WeekPreviewScenario: String {
    case ordinary, sparse, dense, oddWeek, evenWeek, customWeeks
    case twoConflicts, threeConflicts, longCourse, holiday
    case adjustedMonday, adjustedFriday, pending, longText
}

enum WeekSchedulePreviewData {
    static func page(_ scenario: WeekPreviewScenario) throws -> WeekSchedulePageModel {
        let start = try LocalDay(key: "2026-09-07")
        let semester = try SemesterDefinition(startDay: start, totalWeeks: 18)
        let slots = try (1...12).map { section in
            let startMinute = 8 * 60 + (section - 1) * 55
            return try TimeSlotDefinition(sectionNumber: section, startMinute: startMinute,
                endMinute: startMinute + 45)
        }
        let weekNumber = scenario == .evenWeek ? 4 : 3
        let monday = try AcademicCalendarService().firstMonday(of: semester)
            .adding(days: (weekNumber - 1) * 7)
        let previewCourses = try courses(for: scenario)
        let previewOverrides = try overrides(for: scenario, monday: monday)
        let resolver = ScheduleResolver()
        let resolved = try (0..<7).map { offset in
            try resolver.resolve(day: monday.adding(days: offset), semester: semester,
                courses: previewCourses, timeSlots: slots, overrides: previewOverrides)
        }
        let snapshot = try WeekScheduleSnapshotBuilder().make(weekNumber: weekNumber,
            resolvedDays: resolved, currentDate: try monday.adding(days: 1))
        let layout = try CourseLayoutEngine().layout(days: snapshot.days, timeSlots: slots)
        return WeekSchedulePageModel(semesterID: semester.id, semesterName: "2026-2027 第一学期",
            timeZoneID: semester.timeZone.identifier, totalWeeks: semester.totalWeeks,
            currentTeachingWeek: weekNumber, todayTargetWeek: weekNumber,
            snapshot: snapshot, timeSlots: slots,
            layoutItems: layout, currentTimeOffset: nil)
    }

    private static func courses(for scenario: WeekPreviewScenario) throws -> [CourseDefinition] {
        func item(_ name: String, _ weekday: Weekday, _ start: Int, _ end: Int,
                  _ weeks: [Int] = Array(1...18), color: CourseColor = .blue,
                  location: String = "A301") throws -> CourseDefinition {
            CourseDefinition(name: name, teacher: "任课教师", location: location, color: color,
                note: "预览课程，不会写入真实数据。", schedules: [
                    try ScheduleDefinition(weekday: weekday, startSection: start, endSection: end,
                        activeWeeks: ActiveWeeks(weeks))
                ])
        }
        switch scenario {
        case .longText:
            return [CourseDefinition(name: "跨学科研究方法与 Academic Communication Workshop",
                teacher: "王老师 / Professor Alexandra Montgomery",
                location: "南校区综合实验教学中心 A 座 1208 多媒体教室", color: .purple,
                note: "请携带教材；本场景只用于长文本视觉检查。", schedules: [
                    try ScheduleDefinition(weekday: .monday, startSection: 1, endSection: 2,
                        activeWeeks: ActiveWeeks(Array(1...18)))
                ])]
        case .sparse:
            return try [item("大学英语", .tuesday, 3, 4, color: .teal, location: "B205")]
        case .dense:
            return try Weekday.allCases.flatMap { weekday in
                [try item("高等数学", weekday, 1, 2, color: .blue),
                 try item("专业课程", weekday, 4, 6, color: .purple, location: "实验楼")]
            }
        case .oddWeek:
            return try [item("单周研讨", .monday, 1, 2,
                Array(stride(from: 1, through: 17, by: 2)), color: .green)]
        case .evenWeek:
            return try [item("双周实验", .wednesday, 3, 5,
                Array(stride(from: 2, through: 18, by: 2)), color: .orange)]
        case .customWeeks:
            return try [item("专题讲座", .friday, 7, 8, [1, 3, 5, 8, 12], color: .pink)]
        case .twoConflicts:
            return try [item("课程 A", .monday, 1, 2, color: .blue),
                        item("课程 B", .monday, 2, 3, color: .orange)]
        case .threeConflicts:
            return try [item("课程 A", .wednesday, 1, 3, color: .blue),
                        item("课程 B", .wednesday, 1, 2, color: .green),
                        item("课程 C", .wednesday, 2, 4, color: .pink)]
        case .longCourse:
            return try [item("建筑设计工作坊", .thursday, 3, 7, color: .purple, location: "设计教室")]
        default:
            return try [item("高等数学", .monday, 1, 2, color: .blue),
                        item("大学英语", .tuesday, 3, 4, color: .teal, location: "B205"),
                        item("程序设计", .friday, 5, 7, color: .purple, location: "机房 C")]
        }
    }

    private static func overrides(for scenario: WeekPreviewScenario, monday: LocalDay) throws
        -> [OverrideDefinition] {
        switch scenario {
        case .holiday:
            return [try OverrideDefinition(day: monday.adding(days: 3), type: .holiday,
                title: "国庆节", source: .systemCalendar, isConfirmed: true)]
        case .adjustedMonday:
            return [try OverrideDefinition(day: monday.adding(days: 6), type: .adjustedWorkday,
                replacementWeekday: .monday, title: "调休", source: .systemCalendar, isConfirmed: true)]
        case .adjustedFriday:
            return [try OverrideDefinition(day: monday.adding(days: 5), type: .schoolOverride,
                replacementWeekday: .friday, title: "学校调课", source: .schoolCalendar, isConfirmed: true)]
        case .pending:
            return [try OverrideDefinition(day: monday.adding(days: 6), type: .adjustedWorkday,
                title: "调休上班", source: .systemCalendar, isConfirmed: false)]
        default:
            return []
        }
    }
}
#endif
