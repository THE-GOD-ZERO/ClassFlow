import Foundation

public struct CourseScheduleDraft: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var weekday: Int
    public var startSection: Int
    public var endSection: Int
    public var activeWeeks: Set<Int>
    public var location: String

    public init(id: UUID = UUID(), weekday: Int = 1, startSection: Int = 1,
                endSection: Int = 1, activeWeeks: Set<Int> = [], location: String = "") {
        self.id = id; self.weekday = weekday; self.startSection = startSection
        self.endSection = endSection; self.activeWeeks = activeWeeks; self.location = location
    }

    public init(_ schedule: ScheduleDefinition) {
        self.init(id: schedule.id, weekday: schedule.weekday.rawValue,
            startSection: schedule.startSection, endSection: schedule.endSection,
            activeWeeks: schedule.activeWeeks.values, location: schedule.location ?? "")
    }

    public func issues(totalWeeks: Int, slots: [TimeSlotDefinition]) -> [String] {
        var result = [String]()
        if Weekday(rawValue: weekday) == nil { result.append("请选择有效星期。") }
        if startSection < 1 || endSection > 30 || startSection > endSection {
            result.append("结束节次不能早于开始节次。")
        } else {
            let numbers = Set(slots.map(\.sectionNumber))
            if !(startSection...endSection).allSatisfy({ numbers.contains($0) }) {
                result.append("所选节次尚未配置作息时间。")
            }
        }
        if activeWeeks.isEmpty { result.append("请至少选择一个教学周。") }
        if activeWeeks.contains(where: { $0 < 1 || $0 > totalWeeks }) {
            result.append("所选教学周超出当前学期，请重新选择。")
        }
        return result
    }
}

public struct CourseDraft: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var teacher: String
    public var location: String
    public private(set) var colorKey: String
    public var color: CourseColor {
        get { CourseColor.resolve(colorKey) }
        set { colorKey = newValue.rawValue }
    }
    public var note: String
    public var schedules: [CourseScheduleDraft]

    public init(id: UUID = UUID(), name: String = "", teacher: String = "", location: String = "",
                color: CourseColor = .blue, note: String = "", schedules: [CourseScheduleDraft] = []) {
        self.id = id; self.name = name; self.teacher = teacher; self.location = location
        self.colorKey = color.rawValue; self.note = note; self.schedules = schedules
    }

    public init(_ definition: CourseDefinition) {
        self.init(id: definition.id, name: definition.name, teacher: definition.teacher,
            location: definition.location, color: definition.color, note: definition.note,
            schedules: definition.schedules.map(CourseScheduleDraft.init))
        schedules = sortedSchedules
        colorKey = definition.colorKey
    }

    public var sortedSchedules: [CourseScheduleDraft] {
        schedules.sorted {
            if $0.weekday != $1.weekday { return $0.weekday < $1.weekday }
            if $0.startSection != $1.startSection { return $0.startSection < $1.startSection }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    public func issues(totalWeeks: Int, slots: [TimeSlotDefinition]) -> [String] {
        var result = [String]()
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result.append("请输入课程名称。") }
        if schedules.isEmpty { result.append("请至少添加一个上课安排。") }
        if Set(schedules.map(\.id)).count != schedules.count { result.append("上课安排标识重复。") }
        for (index, schedule) in schedules.enumerated() {
            result += schedule.issues(totalWeeks: totalWeeks, slots: slots).map { "安排 \(index + 1)：\($0)" }
            if schedules.dropFirst(index + 1).contains(where: {
                $0.weekday == schedule.weekday && $0.startSection == schedule.startSection &&
                $0.endSection == schedule.endSection && $0.activeWeeks == schedule.activeWeeks
            }) { result.append("存在相同星期、节次和教学周的重复安排。") }
        }
        do { try TimeSlotDefinition.validate(slots) }
        catch { result.append("作息时间存在重复或重叠，请先修正。") }
        return result
    }

    public func definition() throws -> CourseDefinition {
        let definitions = try sortedSchedules.map { item -> ScheduleDefinition in
            guard let weekday = Weekday(rawValue: item.weekday) else { throw DomainError.invalidSchedule }
            let location = item.location.trimmingCharacters(in: .whitespacesAndNewlines)
            return try ScheduleDefinition(id: item.id, weekday: weekday,
                startSection: item.startSection, endSection: item.endSection,
                activeWeeks: ActiveWeeks(Array(item.activeWeeks)), location: location.isEmpty ? nil : location)
        }
        return CourseDefinition(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            teacher: teacher.trimmingCharacters(in: .whitespacesAndNewlines),
            location: location.trimmingCharacters(in: .whitespacesAndNewlines),
            color: color, note: note, schedules: definitions, colorKey: colorKey)
    }
}

public enum CourseColorAllocator {
    public static func next(used: [CourseColor]) -> CourseColor {
        CourseColor.allCases.enumerated().min { a, b in
            let ac = used.filter { $0 == a.element }.count
            let bc = used.filter { $0 == b.element }.count
            return ac == bc ? a.offset < b.offset : ac < bc
        }?.element ?? .blue
    }
}
