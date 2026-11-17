import Foundation
import SwiftData
@testable import Baseline

/// Test-only stand-in for a future production schema. Exercises the three common change kinds:
/// a new optional attribute (WeightEntry), a renamed attribute (Measurement), a new model (ProgressPhoto).
/// Scan, Goal and SyncState are unchanged and reuse BaselineSchemaV1's types.
enum TestSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            WeightEntry.self, BaselineSchemaV1.Scan.self, Measurement.self,
            BaselineSchemaV1.Goal.self, BaselineSchemaV1.SyncState.self, ProgressPhoto.self
        ]
    }

    @Model
    class WeightEntry {
        var id = UUID()
        @Attribute(.allowsCloudEncryption) var weight: Double = 0
        var unit: String = "lb"
        var date = Date()
        @Attribute(.allowsCloudEncryption) var notes: String?
        @Attribute(.externalStorage, .allowsCloudEncryption) var photoData: Data?
        var createdAt = Date()
        var updatedAt = Date()
        var bodyFatPercent: Double?

        init(weight: Double) {
            self.weight = weight
        }
    }

    @Model
    final class Measurement {
        var id = UUID()
        var date = Date()
        var type: String = ""
        @Attribute(.allowsCloudEncryption, originalName: "valueCm") var valueInCm: Double = 0
        @Attribute(.allowsCloudEncryption) var notes: String?
        var createdAt = Date()
        var updatedAt = Date()

        init(valueInCm: Double) {
            self.valueInCm = valueInCm
        }
    }

    @Model
    final class ProgressPhoto {
        var id = UUID()
        var date = Date()
        @Attribute(.externalStorage) var imageData: Data?

        init(imageData: Data?) {
            self.imageData = imageData
        }
    }
}

enum TestMigrationPlanV1toV2: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [BaselineSchemaV1.self, TestSchemaV2.self] }

    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: BaselineSchemaV1.self, toVersion: TestSchemaV2.self)]
    }
}
