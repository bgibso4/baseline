# Versioned SwiftData Schema — Design

Issue: #78. Date: 2026-11-06. Base commit: `f66afa8`.

## Why

Ben has years of weight history in this app, on their own phone. Losing it is the one failure that can't be recovered from. Everything else (goals, scans they still have paper copies of) is replaceable.

The store has no version today. No `VersionedSchema` or `SchemaMigrationPlan` exists, so every future model change relies on implicit lightweight migration with no test behind it. Post-launch features (progress photos, Apple Intelligence scan parsing) will change the schema, so this has to land before the first public build.

## Goals

1. Existing stores open under the new versioned schema with every record intact and unchanged.
2. A future schema change is a small, reviewable addition: a new `VersionedSchema` plus a migration stage.
3. Tests prove both, using real store files on disk.
4. There is a written, rehearsed procedure for moving Ben's phone from their Xcode build to the release build.

## Non-goals

- New model fields, new models, or any change to stored data.
- A full-fidelity backup feature. Ben decided CSV export is enough: it covers weights and their notes, and they can re-enter scans from their copies.
- Exporting goals or the remaining scan fields in CSV.
- Bringing the widget back.
- Moving the store. It stays at `group.com.cadre.baseline/Baseline.store`.
- Changing the startup failure behavior in `BaselineApp.swift` (`fatalError` when the store can't open). That belongs to the review audit (#41).

## Anti-goals

- **Any code path that deletes, recreates or overwrites a store when opening or migrating fails.** A crash is recoverable. A wiped store may not be.
- A test that looks like it proves migration but doesn't, for example one using in-memory stores, which don't persist between containers.

## Constraints

- iOS 27.0 minimum, Xcode 27.1, Swift 5.9 language mode. No third-party dependencies.
- Models are CloudKit-mirrored, so after the Production schema deploy changes must be additive.
- Two stores in one container: `Baseline` (cloud, in the App Group, holds `WeightEntry`, `Scan`, `Measurement`, `Goal`) and `BaselineLocal` (local only, holds `SyncState`). See `BaselineApp.swift:71-99`.
- 57 references to `WeightEntry` alone across `Baseline/`, and tests refer to `Baseline.Measurement`. Call sites must not need to change.
- Follow `CLAUDE.md`: one primary type per file, pure logic stays testable, `make lint` and `make test` green.

## Design

### Schema types

`BaselineSchemaV1: VersionedSchema`, version `1.0.0`, listing all five models. Each model moves inside it, in its existing file:

```swift
extension BaselineSchemaV1 {
    @Model final class WeightEntry { /* unchanged */ }
}
typealias WeightEntry = BaselineSchemaV1.WeightEntry
```

Properties, attributes and initializers stay exactly as they are. The typealias means call sites don't change, and adopting V2 later means pointing the typealias at the new type. V1 then stays frozen.

Nesting doesn't change the entity name. The 2026-11-04 widget repro used models nested in an enum, and they produced `ZWEIGHTENTRY` and `ZSCAN` tables. The fixture test below is the actual proof for this schema.

`BaselineMigrationPlan: SchemaMigrationPlan` lists `[BaselineSchemaV1.self]` with no stages.

**First task is a spike:** confirm that one five-model `VersionedSchema` can open the two-store setup, using a store generated from `f66afa8`. Each store file holds only part of V1, so this isn't guaranteed. If it fails, the fallback (author's call) is to version only the four cloud models, with `SyncState` left out of V1 and given its own separate container, since it holds only rebuildable sync bookkeeping. Nothing else in this design changes.

### Which stores this has to open

Ben's phone never had the widget added, so its store shouldn't have been through the widget's entity removal. Stored fields look unchanged since about 2026-04-14, so an older build's store should match `f66afa8`. A stage-less plan may be stricter than today's implicit migration, so a store that doesn't match could throw at launch. That loses no data, but the app would crash on launch. The way back is to reinstall the `f66afa8` build from Xcode over it, which keeps the store and can still open it. Keep that commit buildable and record this in the SOP.

### One place that opens the store

Move store construction out of `BaselineApp.init` into one factory, taking the store URLs as parameters so tests can use temporary files. It uses `Schema(versionedSchema:)` and `migrationPlan: BaselineMigrationPlan.self`, and keeps both configurations and their names. It takes the CloudKit setting as a parameter so tests can run it with CloudKit off. `BaselineApp` calls it with the real URL and `.automatic`, and keeps its current failure behavior.

The in-memory UI-test path in `BaselineApp` and the test helper `ModelConfiguration.inMemoryForTesting` stay as they are.

### Tests

All on disk, in the logic-test plan, so they run in CI.

1. **Golden fixture.** Generate a real store using the code at `f66afa8`, before any model moves, and commit it to `BaselineTests/Fixtures/`. It contains weights with and without notes, a weight with a photo (external storage), scans, measurements, goals and `SyncState`. The test copies it to a temp directory, opens it through the factory, and asserts every field of every record. It closes and reopens it and asserts the same again. This is the regression guard for Ben's real data, and it must never be regenerated from newer code. The fixture needs its WAL checkpointed, or the WAL files committed with it.
2. **Future changes.** A test-only V2 schema covers the lightweight cases most likely to occur: a new optional attribute, a new model (the shape progress photos would take) and a rename via `originalName`. Seed a V1 store on disk, migrate, assert all records survive with correct values.
3. **Failure doesn't destroy data.** Opening a store with an incompatible schema throws, and the original file's bytes are unchanged afterward.

### The move to the release build (manual, documented)

Add this to `docs/TESTFLIGHT_SOP.md`:

**What we know about Ben's phone.** It has run TestFlight builds, so it went TestFlight (Production) → Xcode (Development) on the same local store, and Production very likely holds the records Ben created during that period. The release build sends the phone back to Production. Nobody has tested what mirroring does with that store and those records: it may match them up, re-upload the newer ones, or import the Production copies as duplicates (records have no unique constraint).

1. On the day of the move, export fresh CSVs from Settings on the current build, save them off the phone, and open the weights file to check the row count and oldest date. Also make an encrypted Finder backup of the phone; it's the only copy that holds the real store (goals, every scan field, photos). It restores the whole phone, so it's a last resort. (Ben exported a CSV on 2026-11-16, before work started.)
2. Merge this work. Look at Production in the CloudKit Console and note the schema and record counts per type. Then deploy the CloudKit schema to Production.
3. **Rehearse on Ben's wife's phone**, reproducing Ben's history: TestFlight build → log some entries → Xcode build of `f66afa8` over it → log more → TestFlight build of this work over it. The Xcode install needs Developer Mode on her phone (connect to Xcode, then Settings → Privacy & Security → Developer Mode, restart). Before starting, export her CSVs, since her phone may hold her own Baseline data. Simulators can't install TestFlight builds, so this has to be a physical device. Never sign Ben's real phone into a different iCloud account to rehearse: an account change can purge or reassign the local store.
4. **Stop conditions.** After the rehearsal, check for: any lost record, any duplicate record, the app crashing on launch. If any happen, Ben's phone does not move until the cause is fixed in a separate change.
5. Install a TestFlight build over the Xcode build on Ben's phone. It shares the bundle ID, so the local store stays.
6. Check the weight count and history against the CSV. Then check the CloudKit Console for what reached Production.

**If older records don't reach Production (Ben's call: leave the data untouched).** Launch anyway. The phone's store is the source of truth, and fixing sync is separate work after launch. No import, delete-and-reimport, or dedupe tool is run on Ben's phone to force it. CSV import couldn't do it safely anyway: `.skip` matches by day and uploads nothing, `.overwrite` deletes and recreates each record and rewrites the matching HealthKit samples, and reinstalling loses goals and the scan fields the CSV leaves out. Until sync is fixed, Ben keeps a current CSV export and doesn't delete the app or move to a new phone.

## Success

- Fixture test passes on `feat/versioned-schema`, and the fixture came from `f66afa8`.
- `make lint` and `make test` green, and CI green.
- No model property, attribute or call site changed apart from the move.
- Rehearsal done on Ben's wife's phone with no stop condition hit, and Ben's weight history verified on the release build against their CSV.

## Left to the builder

- File names for the schema, plan and factory.
- How the fixture is generated, as long as it runs against `f66afa8` and the method is recorded next to the fixture.
- Exact fixture sizes and contents beyond the list above.
