import Foundation
import EventKit
import ClassFlowCore

enum CalendarAccess: String, Sendable {
    case notDetermined, fullAccess, denied, restricted, writeOnly
}

struct CalendarDescriptor: Identifiable, Sendable {
    let id: String
    let title: String
    let accountTitle: String
    var mayBeSchoolCalendar: Bool {
        ["学校校历", "大学校历", "教务处", "课程安排", "教学安排"].contains { title.contains($0) }
    }
}

enum CalendarReadError: Error { case accessUnavailable, invalidRange, inconsistentEvents }

@MainActor
protocol CalendarProviding: AnyObject {
    var access: CalendarAccess { get }
    func requestAccess() async throws -> CalendarAccess
    func calendars() throws -> [CalendarDescriptor]
    func events(in range: DayRange, timeZone: TimeZone,
                selections: [String: CalendarRole]) throws -> [CalendarEventSnapshot]
}

/// Read-only EventKit adapter. Only this file creates and queries EKEventStore.
@MainActor
final class CalendarService: CalendarProviding {
    private let store = EKEventStore()

    var access: CalendarAccess {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .fullAccess: return .fullAccess
        case .writeOnly: return .writeOnly
        @unknown default: return .denied
        }
    }

    func requestAccess() async throws -> CalendarAccess {
        if access == .notDetermined || access == .writeOnly {
            _ = try await store.requestFullAccessToEvents()
        }
        return access
    }

    func calendars() throws -> [CalendarDescriptor] {
        guard access == .fullAccess else { throw CalendarReadError.accessUnavailable }
        return store.calendars(for: .event).map {
            CalendarDescriptor(id: $0.calendarIdentifier, title: $0.title, accountTitle: $0.source.title)
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func events(in range: DayRange, timeZone: TimeZone,
                selections: [String: CalendarRole]) throws -> [CalendarEventSnapshot] {
        guard access == .fullAccess else { throw CalendarReadError.accessUnavailable }
        // EventKit treats nil as all calendars. Never pass nil or query an empty selection.
        let selected = store.calendars(for: .event).filter { selections[$0.calendarIdentifier] != nil }
        guard !selected.isEmpty else { return [] }
        guard try range.start.distance(to: range.endExclusive) <= 740 else { throw CalendarReadError.invalidRange }
        // Pad absolute query boundaries, then let the parser clip civil dates in each event's zone.
        let predicate = store.predicateForEvents(withStart: try range.start.adding(days: -1).start(in: timeZone),
            end: try range.endExclusive.adding(days: 1).start(in: timeZone), calendars: selected)
        let events = store.events(matching: predicate)
        guard access == .fullAccess else { throw CalendarReadError.accessUnavailable }
        return events.compactMap { event in
            guard let calendar = event.calendar, let role = selections[calendar.calendarIdentifier],
                  let start = event.startDate, let end = event.endDate else { return nil }
            // Local calendar item identifier stays stable across edits; dates distinguish recurrences.
            // EventKit returns floating dates in NSTimeZone.default, which may differ from the school zone.
            let dateTimeZone = event.timeZone ?? NSTimeZone.default
            return CalendarEventSnapshot(calendarID: calendar.calendarIdentifier,
                eventID: event.calendarItemIdentifier, title: event.title ?? "", notes: event.notes ?? "",
                start: start, end: end, isAllDay: event.isAllDay, timeZoneID: dateTimeZone.identifier, role: role)
        }
    }
}
