import Foundation
import SwiftData
import ClassFlowCore

@MainActor
final class OverrideRepository {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func confirm(_ record: ScheduleOverride, weekday: Weekday) throws {
        guard record.overrideTypeRawValue != OverrideType.holiday.rawValue else { throw DomainError.invalidOverride }
        record.replacementWeekdayRawValue = weekday.rawValue
        record.isConfirmed = true
        record.updatedAt = Date()
        try context.save()
    }

    @discardableResult
    func saveManual(day: LocalDay, type: OverrideType, weekday: Weekday?, title: String,
                    note: String = "", semester: Semester) throws -> ScheduleOverride {
        let previous = semester.overrides.first {
            $0.dayKey == day.key && $0.sourceRawValue == OverrideSource.manual.rawValue
        }
        let rule = try OverrideDefinition(id: previous?.id ?? UUID(), day: day, type: type,
            replacementWeekday: weekday, title: title, note: note, source: .manual,
            isConfirmed: true, updatedAt: Date())
        if let previous {
            previous.overrideTypeRawValue = rule.type.rawValue
            previous.replacementWeekdayRawValue = rule.replacementWeekday?.rawValue
            previous.title = title
            previous.note = note
            previous.isConfirmed = true
            previous.updatedAt = rule.updatedAt
            try context.save()
            return previous
        }
        let record = ScheduleOverride(rule: rule, semester: semester)
        context.insert(record)
        try context.save()
        return record
    }
}
