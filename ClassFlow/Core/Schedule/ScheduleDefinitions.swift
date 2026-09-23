import Foundation

public struct SemesterDefinition: Sendable {
    public let id: UUID
    public let startDay: LocalDay
    public let totalWeeks: Int
    public let timeZone: TimeZone

    public init(id: UUID = UUID(), startDay: LocalDay, totalWeeks: Int,
                timeZoneID: String = "Asia/Shanghai") throws {
        guard (1...104).contains(totalWeeks) else { throw DomainError.invalidSemester }
        guard let timeZone = TimeZone(identifier: timeZoneID) else { throw DomainError.invalidTimeZone }
        self.id = id
        self.startDay = startDay
        self.totalWeeks = totalWeeks
        self.timeZone = timeZone
    }
}

public struct TimeSlotDefinition: Equatable, Sendable {
    public let sectionNumber: Int
    public let startMinute: Int
    public let endMinute: Int

    public init(sectionNumber: Int, startMinute: Int, endMinute: Int) throws {
        guard (1...30).contains(sectionNumber), (0..<1440).contains(startMinute),
              (1..<1440).contains(endMinute), startMinute < endMinute else {
            throw DomainError.invalidTimeSlot
        }
        self.sectionNumber = sectionNumber
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    public static func validate(_ slots: [Self]) throws {
        let sorted = slots.sorted { $0.sectionNumber < $1.sectionNumber }
        for (first, second) in zip(sorted, sorted.dropFirst()) {
            guard first.sectionNumber < second.sectionNumber, first.endMinute <= second.startMinute else {
                throw DomainError.invalidTimeSlot
            }
        }
    }
}

public struct ScheduleDefinition: Sendable {
    public let id: UUID
    public let weekday: Weekday
    public let startSection: Int
    public let endSection: Int
    public let activeWeeks: ActiveWeeks
    public let location: String?

    public init(id: UUID = UUID(), weekday: Weekday, startSection: Int, endSection: Int,
                activeWeeks: ActiveWeeks, location: String? = nil) throws {
        guard (1...30).contains(startSection), (startSection...30).contains(endSection) else {
            throw DomainError.invalidSchedule
        }
        self.id = id
        self.weekday = weekday
        self.startSection = startSection
        self.endSection = endSection
        self.activeWeeks = activeWeeks
        self.location = location
    }
}

public enum CourseColor: String, CaseIterable, Equatable, Hashable, Sendable {
    case blue, teal, green, orange, pink, purple, plum, clay, olive, denim

    /// Display-only fallback. Callers must retain the original stored key when editing other fields.
    public static func resolve(_ key: String) -> Self { Self(rawValue: key) ?? .blue }
}

public struct CourseDefinition: Sendable {
    public let id: UUID
    public let name: String
    public let teacher: String
    public let location: String
    public let colorKey: String
    public var color: CourseColor { CourseColor.resolve(colorKey) }
    public let note: String
    public let schedules: [ScheduleDefinition]

    public init(id: UUID = UUID(), name: String, teacher: String = "", location: String = "",
                color: CourseColor = .blue, note: String = "", schedules: [ScheduleDefinition], colorKey: String? = nil) {
        self.id = id
        self.name = name
        self.teacher = teacher
        self.location = location
        self.colorKey = colorKey ?? color.rawValue
        self.note = note
        self.schedules = schedules
    }
}
