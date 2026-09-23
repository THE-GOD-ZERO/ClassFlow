import Foundation
import SwiftData
import ClassFlowCore

@Model
final class ScheduleOverride {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var syncKey: String
    var dayKey: String
    var overrideTypeRawValue: String
    var replacementWeekdayRawValue: Int?
    var title: String
    var note: String
    var sourceRawValue: String
    var isConfirmed: Bool
    var updatedAt: Date
    var sourceCalendarID: String?
    var sourceEventID: String?
    var sourceFingerprint: String?
    var semester: Semester?

    init(rule: OverrideDefinition, semester: Semester, syncKey: String? = nil) {
        self.id = rule.id
        self.syncKey = syncKey ?? "manual:\(rule.id.uuidString)"
        self.dayKey = rule.day.key
        self.overrideTypeRawValue = rule.type.rawValue
        self.replacementWeekdayRawValue = rule.replacementWeekday?.rawValue
        self.title = rule.title
        self.note = rule.note
        self.sourceRawValue = rule.source.rawValue
        self.isConfirmed = rule.isConfirmed
        self.updatedAt = rule.updatedAt
        self.semester = semester
    }

    func definition() throws -> OverrideDefinition {
        guard let type = OverrideType(rawValue: overrideTypeRawValue),
              let source = OverrideSource(rawValue: sourceRawValue) else { throw DomainError.invalidOverride }
        let weekday = replacementWeekdayRawValue.flatMap(Weekday.init(rawValue:))
        guard replacementWeekdayRawValue == nil || weekday != nil else { throw DomainError.invalidOverride }
        return try OverrideDefinition(id: id, day: LocalDay(key: dayKey), type: type,
            replacementWeekday: weekday, title: title, note: note, source: source,
            isConfirmed: isConfirmed, updatedAt: updatedAt)
    }
}
