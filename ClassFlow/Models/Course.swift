import Foundation
import SwiftData
import ClassFlowCore

@Model
final class Course {
    @Attribute(.unique) var id: UUID
    var name: String
    var teacher: String
    var location: String
    var colorRawValue: String
    var note: String
    var semester: Semester?

    @Relationship(deleteRule: .cascade, inverse: \CourseSchedule.course)
    var schedules: [CourseSchedule] = []

    init(name: String, teacher: String = "", location: String = "", color: CourseColor = .blue,
         note: String = "", semester: Semester) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw DomainError.invalidCourse }
        self.id = UUID()
        self.name = name
        self.teacher = teacher
        self.location = location
        self.colorRawValue = color.rawValue
        self.note = note
        self.semester = semester
    }

    func definition() throws -> CourseDefinition {
        CourseDefinition(id: id, name: name, teacher: teacher, location: location,
            note: note, schedules: try schedules.map { try $0.definition() }, colorKey: colorRawValue)
    }
}
