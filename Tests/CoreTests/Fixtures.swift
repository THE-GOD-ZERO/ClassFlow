import Foundation
import ClassFlowCore

func day(_ key: String) throws -> LocalDay { try LocalDay(key: key) }

func semester(start: String = "2026-09-07", weeks: Int = 18,
              zone: String = "Asia/Shanghai") throws -> SemesterDefinition {
    try SemesterDefinition(startDay: day(start), totalWeeks: weeks, timeZoneID: zone)
}

func slots() throws -> [TimeSlotDefinition] {
    try [TimeSlotDefinition(sectionNumber: 1, startMinute: 480, endMinute: 525),
         TimeSlotDefinition(sectionNumber: 2, startMinute: 535, endMinute: 580),
         TimeSlotDefinition(sectionNumber: 3, startMinute: 600, endMinute: 645)]
}

func course(_ weekday: Weekday = .monday, weeks: [Int] = Array(1...18),
            start: Int = 1, end: Int = 2, name: String = "高等数学",
            teacher: String = "") throws -> CourseDefinition {
    CourseDefinition(name: name, teacher: teacher, location: "A301", schedules: [
        try ScheduleDefinition(weekday: weekday, startSection: start, endSection: end,
                               activeWeeks: ActiveWeeks(weeks))
    ])
}

func rule(_ date: String, type: OverrideType = .adjustedWorkday, weekday: Weekday? = nil,
          source: OverrideSource = .systemCalendar, confirmed: Bool = true,
          updatedAt: Date = .distantPast) throws -> OverrideDefinition {
    try OverrideDefinition(day: day(date), type: type, replacementWeekday: weekday,
                           title: "特殊安排", source: source, isConfirmed: confirmed, updatedAt: updatedAt)
}
