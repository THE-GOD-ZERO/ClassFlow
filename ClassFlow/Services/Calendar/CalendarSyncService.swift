import Foundation
import SwiftData
import ClassFlowCore

struct CalendarSyncReport: Equatable {
    let access: CalendarAccess
    let inserted: Int
    let updated: Int
    let deleted: Int
    let pendingConfirmation: Int
}

/// A full-semester snapshot reconciliation, serialized on MainActor in a dedicated context.
/// It never requests permission itself; a future explicit Settings action owns that interaction.
@MainActor
final class CalendarSyncService {
    private let container: ModelContainer
    private let calendar: any CalendarProviding
    private let parser = CalendarEventParser()

    init(container: ModelContainer, calendar: any CalendarProviding) {
        self.container = container
        self.calendar = calendar
    }

    func sync(semesterID: UUID, selections: [String: CalendarRole]) throws -> CalendarSyncReport {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        guard let semester = try context.fetch(FetchDescriptor<Semester>()).first(where: { $0.id == semesterID }) else {
            throw DomainError.invalidSemester
        }
        let definition = try semester.definition()
        let range = try DayRange(start: definition.startDay,
                                endExclusive: AcademicCalendarService().endExclusive(of: definition))
        var access = calendar.access // Always refresh: permission may change while the app is backgrounded.
        var events = [CalendarEventSnapshot]()
        if access == .fullAccess {
            do {
                events = try calendar.events(in: range, timeZone: definition.timeZone, selections: selections)
            } catch {
                guard calendar.access != .fullAccess else { throw error }
            }
            access = calendar.access
            if access != .fullAccess { events = [] }
        }
        var incoming = [String: ImportedOverride]()
        for event in events where selections[event.calendarID] == event.role {
            for item in try parser.parse(event, in: range, schoolTimeZone: definition.timeZone) {
                let key = semesterID.uuidString + ":" + item.syncKey
                if let previous = incoming[key], previous.fingerprint != item.fingerprint {
                    // A contradictory provider snapshot must not partly overwrite persisted rules.
                    throw CalendarReadError.inconsistentEvents
                }
                incoming[key] = item
            }
        }
        // Read/parse must succeed in full before any deletes. Errors leave the prior store untouched.
        let existing = semester.overrides.filter { $0.sourceRawValue != OverrideSource.manual.rawValue }
        var byKey = [String: ScheduleOverride]()
        for item in existing { byKey[item.syncKey] = item }
        var inserted = 0
        var updated = 0
        var deleted = 0
        do {
            for key in incoming.keys.sorted() {
                guard let item = incoming[key] else { continue }
                if let record = byKey[key] {
                    // Preserve user confirmation only while the exact source content remains unchanged.
                    if record.sourceFingerprint != item.fingerprint {
                        apply(item, to: record)
                        updated += 1
                    }
                } else {
                    let record = ScheduleOverride(rule: item.rule, semester: semester, syncKey: key)
                    apply(item, to: record)
                    context.insert(record)
                    inserted += 1
                }
            }
            // Whole-semester sync prunes moved/deleted events, deselected calendars, and stale old ranges.
            // Revoked permission removes automatic imports; manual rules and ordinary courses survive.
            for record in existing where incoming[record.syncKey] == nil {
                context.delete(record)
                deleted += 1
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        let pending = semester.overrides.filter {
            $0.sourceRawValue != OverrideSource.manual.rawValue && !$0.isConfirmed
        }.count
        return CalendarSyncReport(access: access, inserted: inserted, updated: updated,
                                  deleted: deleted, pendingConfirmation: pending)
    }

    private func apply(_ item: ImportedOverride, to record: ScheduleOverride) {
        record.dayKey = item.rule.day.key
        record.overrideTypeRawValue = item.rule.type.rawValue
        record.replacementWeekdayRawValue = item.rule.replacementWeekday?.rawValue
        record.title = item.rule.title
        record.note = item.rule.note
        record.sourceRawValue = item.rule.source.rawValue
        record.isConfirmed = item.rule.isConfirmed
        record.updatedAt = Date()
        record.sourceCalendarID = item.calendarID
        record.sourceEventID = item.eventID
        record.sourceFingerprint = item.fingerprint
    }
}
