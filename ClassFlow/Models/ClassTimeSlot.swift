import Foundation
import SwiftData
import ClassFlowCore

@Model
final class ClassTimeSlot {
    @Attribute(.unique) var id: UUID
    var sectionNumber: Int
    /// Local wall-clock minutes, never a Date with an arbitrary reference date.
    var startMinute: Int
    var endMinute: Int
    var semester: Semester?

    init(sectionNumber: Int, startMinute: Int, endMinute: Int, semester: Semester) throws {
        _ = try TimeSlotDefinition(sectionNumber: sectionNumber, startMinute: startMinute, endMinute: endMinute)
        self.id = UUID()
        self.sectionNumber = sectionNumber
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.semester = semester
    }

    func definition() throws -> TimeSlotDefinition {
        try TimeSlotDefinition(sectionNumber: sectionNumber, startMinute: startMinute, endMinute: endMinute)
    }
}
