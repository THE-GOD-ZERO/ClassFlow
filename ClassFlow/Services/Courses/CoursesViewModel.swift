import Foundation
import Combine
import SwiftData
import ClassFlowCore

struct CoursesPageModel: Equatable {
    let semesterID: UUID
    let semesterName: String
    let totalWeeks: Int
    let slots: [TimeSlotDefinition]
    let courses: [CourseDraft]
}

@MainActor
final class CoursesViewModel: ObservableObject {
    @Published private(set) var page: CoursesPageModel?
    @Published private(set) var error: String?
    @Published var search = ""
    let container: ModelContainer

    init(container: ModelContainer) { self.container = container }

    var filteredCourses: [CourseDraft] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return page?.courses ?? [] }
        return (page?.courses ?? []).filter { course in
            ([course.name, course.teacher, course.location] + course.schedules.map(\.location))
                .contains { $0.localizedStandardContains(query) }
        }
    }

    func reload() {
        do {
            let context = ModelContext(container)
            guard let semester = try SemesterRepository(context: context).current() else {
                page = nil; error = nil; return
            }
            page = try CoursesPageModel(semesterID: semester.id, semesterName: semester.name,
                totalWeeks: semester.totalWeeks,
                slots: semester.timeSlots.map { try $0.definition() }.sorted { $0.sectionNumber < $1.sectionNumber },
                courses: semester.courses.map { try CourseDraft($0.definition()) }
                    .sorted { $0.name == $1.name ? $0.id.uuidString < $1.id.uuidString :
                        $0.name.localizedStandardCompare($1.name) == .orderedAscending })
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}
