import SwiftData

/// Every schema version the store has had, oldest first, and how to move between them.
enum BaselineMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [BaselineSchemaV1.self] }

    static var stages: [MigrationStage] { [] }
}
