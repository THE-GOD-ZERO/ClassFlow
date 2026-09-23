import Foundation
import ClassFlowCore

@MainActor
final class CalendarSelectionStore {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func selections(for semesterID: UUID) -> [String: CalendarRole] {
        guard let data = defaults.data(forKey: key(semesterID)),
              let selections = try? JSONDecoder().decode([String: CalendarRole].self, from: data) else { return [:] }
        return selections
    }

    func save(_ selections: [String: CalendarRole], for semesterID: UUID) throws {
        defaults.set(try JSONEncoder().encode(selections), forKey: key(semesterID))
    }

    func remove(for semesterID: UUID) { defaults.removeObject(forKey: key(semesterID)) }
    private func key(_ id: UUID) -> String { "calendarSelections.\(id.uuidString)" }
}
