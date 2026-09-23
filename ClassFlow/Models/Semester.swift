import Foundation
import SwiftData
import ClassFlowCore

@Model
final class Semester {
    @Attribute(.unique) var id: UUID
    var name: String
    var startDayKey: String
    var totalWeeks: Int
    var timeZoneID: String
    var isCurrent: Bool
    var note: String

    @Relationship(deleteRule: .cascade, inverse: \Course.semester)
    var courses: [Course] = []
    @Relationship(deleteRule: .cascade, inverse: \ClassTimeSlot.semester)
    var timeSlots: [ClassTimeSlot] = []
    @Relationship(deleteRule: .cascade, inverse: \ScheduleOverride.semester)
    var overrides: [ScheduleOverride] = []

    init(name: String, startDay: LocalDay, totalWeeks: Int, timeZoneID: String = "Asia/Shanghai",
         isCurrent: Bool = false, note: String = "") throws {
        _ = try SemesterDefinition(startDay: startDay, totalWeeks: totalWeeks, timeZoneID: timeZoneID)
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw DomainError.invalidSemester }
        self.id = UUID()
        self.name = name
        self.startDayKey = startDay.key
        self.totalWeeks = totalWeeks
        self.timeZoneID = timeZoneID
        self.isCurrent = isCurrent
        self.note = note
    }

    /// A derived instant for DatePicker interoperability. Civil `startDayKey` remains authoritative.
    var startDate: Date {
        get throws {
            let value = try definition()
            return try value.startDay.start(in: value.timeZone)
        }
    }

    func definition() throws -> SemesterDefinition {
        try SemesterDefinition(id: id, startDay: LocalDay(key: startDayKey),
                               totalWeeks: totalWeeks, timeZoneID: timeZoneID)
    }
}
