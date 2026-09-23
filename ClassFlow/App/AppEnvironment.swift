import Foundation
import SwiftData
import Combine
import EventKit

@MainActor
final class AppEnvironment: ObservableObject {
    let container: ModelContainer?
    let calendar = CalendarService()
    let calendarSelections = CalendarSelectionStore()
    @Published private(set) var startupError: String?
    @Published private(set) var syncError: String?
    @Published private(set) var syncReport: CalendarSyncReport?
    @Published private(set) var calendarRevision = 0
    @Published private(set) var scheduleRevision = 0
    private var changeObserver: NSObjectProtocol?
    private var scheduledRefresh: Task<Void, Never>?

    init() {
        do { container = try PersistenceController.makeContainer() }
        catch {
            container = nil
            startupError = error.localizedDescription
        }
        // Observe changes without requesting access. EventKit objects are fetched afresh each time.
        changeObserver = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged,
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refreshCalendars() }
            }
    }

    deinit {
        if let changeObserver { NotificationCenter.default.removeObserver(changeObserver) }
        scheduledRefresh?.cancel()
    }

    func refreshCalendars() {
        scheduledRefresh?.cancel()
        scheduledRefresh = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
            guard let self, let container = self.container else { return }
            do {
                let context = ModelContext(container)
                guard let semester = try SemesterRepository(context: context).current() else { return }
                self.syncReport = try CalendarSyncService(container: container, calendar: self.calendar)
                    .sync(semesterID: semester.id, selections: self.calendarSelections.selections(for: semester.id))
                self.calendarRevision &+= 1
                self.syncError = nil
            } catch { self.syncError = error.localizedDescription }
        }
    }

    func scheduleDataDidChange() { scheduleRevision &+= 1 }
}
