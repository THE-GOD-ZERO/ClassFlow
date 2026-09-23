import Foundation
import SwiftData

enum ClassFlowSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Semester.self, Course.self, CourseSchedule.self, ClassTimeSlot.self, ScheduleOverride.self]
    }
}

enum ClassFlowMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [ClassFlowSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

@MainActor
enum PersistenceController {
    static func makeContainer(inMemory: Bool = false, storeURL: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: ClassFlowSchemaV1.self)
        let configuration: ModelConfiguration
        if let storeURL {
            configuration = ModelConfiguration("ClassFlow", schema: schema, url: storeURL, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration("ClassFlow", schema: schema,
                isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, migrationPlan: ClassFlowMigrationPlan.self,
                                  configurations: [configuration])
    }
}
