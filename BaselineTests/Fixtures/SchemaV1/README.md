# SchemaV1 golden store fixture

Real SwiftData stores written by the app code at commit `f66afa8` (the last commit before
versioned schemas, #78). Later tests open these with newer code and assert every field against
`expected.json`. **Never regenerate this from newer code**: it is the regression guard for
users' existing on-disk data, so it must reflect what shipped.

Contents:
- `Baseline.store` - cloud-schema store (WeightEntry, Scan, Measurement, Goal)
- `BaselineLocal.store` - local store (SyncState); file name recorded in `expected.json`
- `Baseline_SUPPORT/_EXTERNAL_DATA/` - external-storage photo blob. This is the
  `.Baseline_SUPPORT` directory with the leading dot removed, because hidden directories do not
  survive resource copying into the test bundle. The test helper renames it back.
- `expected.json` - values read back from the stores (dates are `timeIntervalSinceReferenceDate`,
  scan payloads base64, photo as SHA-256 hex)

## How it was generated

```bash
SCRATCH=<scratch dir>
mkdir -p "$SCRATCH/fixture-gen" && git archive f66afa8 | tar -x -C "$SCRATCH/fixture-gen"
cd "$SCRATCH/fixture-gen"
# add BaselineTests/SchemaV1FixtureGenerator.swift (source below)
xcodegen generate
TEST_RUNNER_FIXTURE_OUT="$SCRATCH/fixture-out" xcodebuild test -project Baseline.xcodeproj \
  -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath "$SCRATCH/fixture-gen-dd" -only-testing:BaselineTests/SchemaV1FixtureGenerator
sqlite3 "$SCRATCH/fixture-out/Baseline.store" "PRAGMA wal_checkpoint(TRUNCATE);"
sqlite3 "$SCRATCH/fixture-out/BaselineLocal.store" "PRAGMA wal_checkpoint(TRUNCATE);"
# confirm *-wal files are 0 bytes (do not commit -wal/-shm) and
# .Baseline_SUPPORT/_EXTERNAL_DATA holds exactly one file
```

Then copy the stores, `expected.json` and the external data file here, renaming
`.Baseline_SUPPORT` to `Baseline_SUPPORT`.

## Generator source (verbatim)

```swift
import CryptoKit
import SwiftData
import XCTest
@testable import Baseline

/// One-shot generator for the SchemaV1 golden fixture. Lives only in the exported
/// f66afa8 tree; never run from newer code.
final class SchemaV1FixtureGenerator: XCTestCase {
    private typealias BaselineMeasurement = Baseline.Measurement

    private func t(_ offset: Double) -> Date { Date(timeIntervalSinceReferenceDate: offset) }
    private func ti(_ date: Date?) -> Any { date.map { $0.timeIntervalSinceReferenceDate } ?? NSNull() }
    private func opt(_ value: Any?) -> Any { value ?? NSNull() }

    func testGenerate() throws {
        let outPath = try XCTUnwrap(ProcessInfo.processInfo.environment["FIXTURE_OUT"])
        let out = URL(fileURLWithPath: outPath, isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        // Default local store file name, as the app at f66afa8 uses.
        let originalLocal = ModelConfiguration(
            "BaselineLocal",
            schema: Schema([SyncState.self]),
            cloudKitDatabase: .none
        )
        let localName = originalLocal.url.lastPathComponent

        let cloudSchema = Schema([WeightEntry.self, Scan.self, BaselineMeasurement.self, Goal.self])
        let cloudConfig = ModelConfiguration(
            "Baseline",
            schema: cloudSchema,
            url: out.appendingPathComponent("Baseline.store"),
            cloudKitDatabase: .none
        )
        let localConfig = ModelConfiguration(
            "BaselineLocal",
            schema: Schema([SyncState.self]),
            url: out.appendingPathComponent(localName),
            cloudKitDatabase: .none
        )
        let fullSchema = Schema([
            WeightEntry.self, Scan.self, BaselineMeasurement.self, SyncState.self, Goal.self
        ])
        let container = try ModelContainer(for: fullSchema, configurations: [cloudConfig, localConfig])
        let context = ModelContext(container)

        // Weights
        let photo = Data((0..<(256 * 1024)).map { UInt8($0 % 251) })
        let w1 = WeightEntry(weight: 180.5, unit: "lb", notes: "Morning, fasted")
        w1.id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        w1.date = t(700_000_000); w1.createdAt = t(700_000_100); w1.updatedAt = t(700_000_200)
        let w2 = WeightEntry(weight: 179.0, unit: "lb", notes: nil)
        w2.id = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        w2.date = t(700_086_400); w2.createdAt = t(700_086_500); w2.updatedAt = t(700_086_600)
        let w3 = WeightEntry(weight: 81.25, unit: "kg", notes: "With photo", photoData: photo)
        w3.id = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        w3.date = t(700_172_800); w3.createdAt = t(700_172_900); w3.updatedAt = t(700_173_000)
        [w1, w2, w3].forEach { context.insert($0) }

        // Scans
        func payload(_ weight: Double) throws -> Data {
            let p = InBodyPayload(
                weightKg: weight, skeletalMuscleMassKg: 38.4, bodyFatMassKg: 16.2,
                bodyFatPct: 19.8, totalBodyWaterL: 49.1, bmi: 24.6, basalMetabolicRate: 1780,
                intracellularWaterL: 30.5, extracellularWaterL: 18.6, dryLeanMassKg: 13.4,
                leanBodyMassKg: 65.6, inBodyScore: 78, rightArmLeanKg: 3.9, leftArmLeanKg: 3.8,
                trunkLeanKg: 30.1, rightLegLeanKg: 10.2, leftLegLeanKg: 10.1,
                rightArmFatKg: 0.8, leftArmFatKg: 0.8, trunkFatKg: 8.1, rightLegFatKg: 2.4,
                leftLegFatKg: 2.3, ecwTbwRatio: 0.379, skeletalMuscleIndex: 8.7,
                visceralFatLevel: 6, rightArmLeanPct: 102, leftArmLeanPct: 101,
                trunkLeanPct: 98, rightLegLeanPct: 99, leftLegLeanPct: 100,
                rightArmFatPct: 110, leftArmFatPct: 108, trunkFatPct: 95,
                rightLegFatPct: 97, leftLegFatPct: 96
            )
            return try JSONEncoder().encode(p)
        }
        let s1 = Scan(date: t(700_000_000), type: .inBody, source: .manual,
                      payload: try payload(81.9), notes: "Gym scan")
        s1.id = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
        s1.date = t(700_000_000); s1.createdAt = t(700_000_300); s1.updatedAt = t(700_000_400)
        let s2 = Scan(date: t(700_086_400), type: .inBody, source: .ocr,
                      payload: try payload(81.2), notes: nil)
        s2.id = UUID(uuidString: "00000000-0000-0000-0000-000000000012")!
        s2.date = t(700_086_400); s2.createdAt = t(700_086_700); s2.updatedAt = t(700_086_800)
        [s1, s2].forEach { context.insert($0) }

        // Measurements
        let m1 = BaselineMeasurement(date: t(700_000_000), type: .waist, valueCm: 84.5, notes: "Relaxed")
        m1.id = UUID(uuidString: "00000000-0000-0000-0000-000000000021")!
        m1.date = t(700_000_000); m1.createdAt = t(700_000_500); m1.updatedAt = t(700_000_600)
        let m2 = BaselineMeasurement(date: t(700_086_400), type: .armLeft, valueCm: 35.2, notes: nil)
        m2.id = UUID(uuidString: "00000000-0000-0000-0000-000000000022")!
        m2.date = t(700_086_400); m2.createdAt = t(700_086_900); m2.updatedAt = t(700_087_000)
        [m1, m2].forEach { context.insert($0) }

        // Goals
        let g1 = Goal(metric: "weight", targetValue: 170, startValue: 185, targetDate: t(710_000_000))
        g1.id = UUID(uuidString: "00000000-0000-0000-0000-000000000031")!
        g1.targetDate = t(710_000_000); g1.startDate = t(700_000_000); g1.createdAt = t(700_000_700)
        let g2 = Goal(metric: "waist", targetValue: 82, startValue: 86, targetDate: nil)
        g2.id = UUID(uuidString: "00000000-0000-0000-0000-000000000032")!
        g2.targetDate = nil; g2.startDate = t(699_000_000); g2.createdAt = t(699_000_100)
        g2.status = .completed; g2.completedDate = t(705_000_000)
        [g1, g2].forEach { context.insert($0) }

        context.insert(SyncState(tableName: "weight_entries", lastSyncTimestamp: "2026-04-14T07:18:00Z"))
        try context.save()

        // Fetch back through a fresh context
        let fresh = ModelContext(container)
        let weights = try fresh.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date)]))
        let scans = try fresh.fetch(FetchDescriptor<Scan>(sortBy: [SortDescriptor(\.date)]))
        let measurements = try fresh.fetch(FetchDescriptor<BaselineMeasurement>(sortBy: [SortDescriptor(\.date)]))
        let goals = try fresh.fetch(FetchDescriptor<Goal>(sortBy: [SortDescriptor(\.createdAt)]))
        let syncs = try fresh.fetch(FetchDescriptor<SyncState>())

        let json: [String: Any] = [
            "localStoreFileName": localName,
            "weights": weights.map { w -> [String: Any] in
                [
                    "id": w.id.uuidString, "weight": w.weight, "unit": w.unit, "date": ti(w.date),
                    "notes": opt(w.notes),
                    "photoSHA256": opt(w.photoData.map { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() }),
                    "createdAt": ti(w.createdAt), "updatedAt": ti(w.updatedAt)
                ]
            },
            "scans": scans.map { s -> [String: Any] in
                [
                    "id": s.id.uuidString, "date": ti(s.date), "type": s.type, "source": s.source,
                    "notes": opt(s.notes), "payloadBase64": s.payloadData.base64EncodedString(),
                    "createdAt": ti(s.createdAt), "updatedAt": ti(s.updatedAt)
                ]
            },
            "measurements": measurements.map { m -> [String: Any] in
                [
                    "id": m.id.uuidString, "date": ti(m.date), "type": m.type, "valueCm": m.valueCm,
                    "notes": opt(m.notes), "createdAt": ti(m.createdAt), "updatedAt": ti(m.updatedAt)
                ]
            },
            "goals": goals.map { g -> [String: Any] in
                [
                    "id": g.id.uuidString, "metric": g.metric, "targetValue": g.targetValue,
                    "targetDate": ti(g.targetDate), "startValue": g.startValue,
                    "startDate": ti(g.startDate), "status": g.status.rawValue,
                    "completedDate": ti(g.completedDate), "createdAt": ti(g.createdAt)
                ]
            },
            "syncStates": syncs.map { ["tableName": $0.tableName, "lastSyncTimestamp": $0.lastSyncTimestamp] }
        ]
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: out.appendingPathComponent("expected.json"))
        XCTAssertEqual(weights.count, 3)
        XCTAssertEqual(scans.count, 2)
    }
}
```
