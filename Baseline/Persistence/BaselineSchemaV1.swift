import SwiftData

/// The SwiftData schema as first shipped. Frozen: a model change adds `BaselineSchemaV2`
/// and points the top-level typealiases at it, leaving these types untouched.
/// Each model is declared inside this namespace in its own file under `Baseline/Models`.
enum BaselineSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [WeightEntry.self, Scan.self, Measurement.self, Goal.self, SyncState.self]
    }
}
