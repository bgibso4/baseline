# CloudKit Field Encryption Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Encrypt all health-sensitive fields in CloudKit using SwiftData's `.allowsCloudEncryption` attribute, and add error handling for iCloud Keychain reset scenarios, to comply with App Store guideline 5.1.3(ii).

**Architecture:** Add `.allowsCloudEncryption` to health-sensitive properties on all four synced SwiftData models (WeightEntry, Scan, Measurement, Goal). Add a CloudKit sync monitor that listens for `NSPersistentCloudKitContainer` events and handles the `CKErrorUserDidResetEncryptedDataKey` edge case by re-uploading local data. Structural/queryable fields (id, date, type, status) remain unencrypted.

**Tech Stack:** SwiftData, CloudKit, `NSPersistentCloudKitContainer.eventChangedNotification`

**Important context:** The app has NOT shipped yet, so the CloudKit production schema has not been finalized. This is the ideal time to set encryption — once fields are deployed to production as encrypted or unencrypted, that decision is permanent.

---

### Task 1: Add `.allowsCloudEncryption` to WeightEntry

**Files:**
- Modify: `Baseline/Models/WeightEntry.swift:7-11`
- Test: `BaselineTests/Models/WeightEntryTests.swift`

- [ ] **Step 1: Write a test that verifies encrypted attributes exist on the model schema**

In `BaselineTests/Models/WeightEntryTests.swift`, add:

```swift
func testHealthFieldsAllowCloudEncryption() throws {
    let schema = Schema([WeightEntry.self])
    let entity = try XCTUnwrap(schema.entities.first(where: { $0.name == "WeightEntry" }))

    let weightAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "weight" }))
    XCTAssertTrue(weightAttr.options.contains(.allowsCloudEncryption), "weight must allow cloud encryption")

    let notesAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "notes" }))
    XCTAssertTrue(notesAttr.options.contains(.allowsCloudEncryption), "notes must allow cloud encryption")

    let photoAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "photoData" }))
    XCTAssertTrue(photoAttr.options.contains(.allowsCloudEncryption), "photoData must allow cloud encryption")
}

func testStructuralFieldsNotEncrypted() throws {
    let schema = Schema([WeightEntry.self])
    let entity = try XCTUnwrap(schema.entities.first(where: { $0.name == "WeightEntry" }))

    // date and unit must remain queryable (not encrypted)
    let dateAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "date" }))
    XCTAssertFalse(dateAttr.options.contains(.allowsCloudEncryption), "date must not be encrypted (needed for sorting)")

    let unitAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "unit" }))
    XCTAssertFalse(unitAttr.options.contains(.allowsCloudEncryption), "unit must not be encrypted")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing BaselineTests/WeightEntryTests/testHealthFieldsAllowCloudEncryption -only-testing BaselineTests/WeightEntryTests/testStructuralFieldsNotEncrypted 2>&1 | tail -20`

Expected: FAIL — `weight` does not yet have `.allowsCloudEncryption`

- [ ] **Step 3: Add encryption attributes to WeightEntry**

In `Baseline/Models/WeightEntry.swift`, change the property declarations:

```swift
@Model
class WeightEntry {
    var id: UUID = UUID()
    @Attribute(.allowsCloudEncryption) var weight: Double = 0
    var unit: String = "lb"
    var date: Date = Date()
    @Attribute(.allowsCloudEncryption) var notes: String?
    @Attribute(.externalStorage, .allowsCloudEncryption) var photoData: Data?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
```

Fields encrypted: `weight`, `notes`, `photoData`
Fields NOT encrypted: `id`, `unit`, `date`, `createdAt`, `updatedAt` (needed for queries/sorting)

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing BaselineTests/WeightEntryTests 2>&1 | tail -20`

Expected: ALL PASS — including existing tests (encryption doesn't affect local behavior)

- [ ] **Step 5: Commit**

```bash
git add Baseline/Models/WeightEntry.swift BaselineTests/Models/WeightEntryTests.swift
git commit -m "feat: encrypt WeightEntry health fields for CloudKit sync

Add .allowsCloudEncryption to weight, notes, and photoData fields.
Structural fields (id, date, unit) remain unencrypted for queryability.
Addresses App Store guideline 5.1.3(ii) compliance."
```

---

### Task 2: Add `.allowsCloudEncryption` to Scan

**Files:**
- Modify: `Baseline/Models/Scan.swift:10-11`
- Test: `BaselineTests/Models/ScanTests.swift`

- [ ] **Step 1: Write a test that verifies encrypted attributes on Scan**

In `BaselineTests/Models/ScanTests.swift`, add:

```swift
func testHealthFieldsAllowCloudEncryption() throws {
    let schema = Schema([Scan.self])
    let entity = try XCTUnwrap(schema.entities.first(where: { $0.name == "Scan" }))

    let payloadAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "payloadData" }))
    XCTAssertTrue(payloadAttr.options.contains(.allowsCloudEncryption), "payloadData must allow cloud encryption")

    let notesAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "notes" }))
    XCTAssertTrue(notesAttr.options.contains(.allowsCloudEncryption), "notes must allow cloud encryption")
}

func testStructuralFieldsNotEncrypted() throws {
    let schema = Schema([Scan.self])
    let entity = try XCTUnwrap(schema.entities.first(where: { $0.name == "Scan" }))

    let dateAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "date" }))
    XCTAssertFalse(dateAttr.options.contains(.allowsCloudEncryption), "date must not be encrypted")

    let typeAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "type" }))
    XCTAssertFalse(typeAttr.options.contains(.allowsCloudEncryption), "type must not be encrypted")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing BaselineTests/ScanTests/testHealthFieldsAllowCloudEncryption -only-testing BaselineTests/ScanTests/testStructuralFieldsNotEncrypted 2>&1 | tail -20`

Expected: FAIL

- [ ] **Step 3: Add encryption attributes to Scan**

In `Baseline/Models/Scan.swift`, change:

```swift
@Model
final class Scan {
    var id: UUID = UUID()
    var date: Date = Date()
    var type: String = ""
    var source: String = ""
    @Attribute(.allowsCloudEncryption) var notes: String?
    @Attribute(.allowsCloudEncryption) var payloadData: Data = Data()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
```

Fields encrypted: `payloadData` (contains all InBody body composition data), `notes`
Fields NOT encrypted: `id`, `date`, `type`, `source`, `createdAt`, `updatedAt`

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing BaselineTests/ScanTests 2>&1 | tail -20`

Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add Baseline/Models/Scan.swift BaselineTests/Models/ScanTests.swift
git commit -m "feat: encrypt Scan health fields for CloudKit sync

Add .allowsCloudEncryption to payloadData and notes.
payloadData contains full InBody body composition results."
```

---

### Task 3: Add `.allowsCloudEncryption` to Measurement

**Files:**
- Modify: `Baseline/Models/Measurement.swift:9-10`
- Test: `BaselineTests/Models/MeasurementTests.swift`

- [ ] **Step 1: Write a test that verifies encrypted attributes on Measurement**

In `BaselineTests/Models/MeasurementTests.swift`, add:

```swift
func testHealthFieldsAllowCloudEncryption() throws {
    let schema = Schema([Measurement.self])
    let entity = try XCTUnwrap(schema.entities.first(where: { $0.name == "Measurement" }))

    let valueAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "valueCm" }))
    XCTAssertTrue(valueAttr.options.contains(.allowsCloudEncryption), "valueCm must allow cloud encryption")

    let notesAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "notes" }))
    XCTAssertTrue(notesAttr.options.contains(.allowsCloudEncryption), "notes must allow cloud encryption")
}

func testStructuralFieldsNotEncrypted() throws {
    let schema = Schema([Measurement.self])
    let entity = try XCTUnwrap(schema.entities.first(where: { $0.name == "Measurement" }))

    let dateAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "date" }))
    XCTAssertFalse(dateAttr.options.contains(.allowsCloudEncryption))

    let typeAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "type" }))
    XCTAssertFalse(typeAttr.options.contains(.allowsCloudEncryption))
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing BaselineTests/MeasurementTests/testHealthFieldsAllowCloudEncryption -only-testing BaselineTests/MeasurementTests/testStructuralFieldsNotEncrypted 2>&1 | tail -20`

Expected: FAIL

- [ ] **Step 3: Add encryption attributes to Measurement**

In `Baseline/Models/Measurement.swift`, change:

```swift
@Model
final class Measurement {
    var id: UUID = UUID()
    var date: Date = Date()
    var type: String = ""
    @Attribute(.allowsCloudEncryption) var valueCm: Double = 0
    @Attribute(.allowsCloudEncryption) var notes: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
```

Fields encrypted: `valueCm`, `notes`
Fields NOT encrypted: `id`, `date`, `type`, `createdAt`, `updatedAt`

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing BaselineTests/MeasurementTests 2>&1 | tail -20`

Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add Baseline/Models/Measurement.swift BaselineTests/Models/MeasurementTests.swift
git commit -m "feat: encrypt Measurement health fields for CloudKit sync

Add .allowsCloudEncryption to valueCm and notes."
```

---

### Task 4: Add `.allowsCloudEncryption` to Goal

**Files:**
- Modify: `Baseline/Models/Goal.swift:13-15`
- Test: `BaselineTests/Models/GoalTests.swift`

- [ ] **Step 1: Write a test that verifies encrypted attributes on Goal**

In `BaselineTests/Models/GoalTests.swift`, add:

```swift
func testHealthFieldsAllowCloudEncryption() throws {
    let schema = Schema([Goal.self])
    let entity = try XCTUnwrap(schema.entities.first(where: { $0.name == "Goal" }))

    let targetAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "targetValue" }))
    XCTAssertTrue(targetAttr.options.contains(.allowsCloudEncryption), "targetValue must allow cloud encryption")

    let startAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "startValue" }))
    XCTAssertTrue(startAttr.options.contains(.allowsCloudEncryption), "startValue must allow cloud encryption")
}

func testStructuralFieldsNotEncrypted() throws {
    let schema = Schema([Goal.self])
    let entity = try XCTUnwrap(schema.entities.first(where: { $0.name == "Goal" }))

    let metricAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "metric" }))
    XCTAssertFalse(metricAttr.options.contains(.allowsCloudEncryption), "metric must not be encrypted (needed for queries)")

    let statusAttr = try XCTUnwrap(entity.attributes.first(where: { $0.name == "status" }))
    XCTAssertFalse(statusAttr.options.contains(.allowsCloudEncryption), "status must not be encrypted (needed for queries)")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing BaselineTests/GoalTests/testHealthFieldsAllowCloudEncryption -only-testing BaselineTests/GoalTests/testStructuralFieldsNotEncrypted 2>&1 | tail -20`

Expected: FAIL

- [ ] **Step 3: Add encryption attributes to Goal**

In `Baseline/Models/Goal.swift`, change:

```swift
@Model
final class Goal {
    var id: UUID = UUID()
    var metric: String = ""
    @Attribute(.allowsCloudEncryption) var targetValue: Double = 0.0
    var targetDate: Date?
    @Attribute(.allowsCloudEncryption) var startValue: Double = 0.0
    var startDate: Date = Date()
    var status: GoalStatus = GoalStatus.active
    var completedDate: Date?
    var createdAt: Date = Date()
```

Fields encrypted: `targetValue`, `startValue`
Fields NOT encrypted: `id`, `metric` (needed for queries — "which metric has an active goal?"), `targetDate`, `startDate`, `status` (needed for filtering active/completed), `completedDate`, `createdAt`

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing BaselineTests/GoalTests 2>&1 | tail -20`

Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add Baseline/Models/Goal.swift BaselineTests/Models/GoalTests.swift
git commit -m "feat: encrypt Goal health fields for CloudKit sync

Add .allowsCloudEncryption to targetValue and startValue.
metric and status remain unencrypted for query filtering."
```

---

### Task 5: Add CloudKit Sync Event Monitor

**Files:**
- Create: `Baseline/Sync/CloudKitSyncMonitor.swift`
- Test: `BaselineTests/Sync/CloudKitSyncMonitorTests.swift`

This task adds a lightweight observer that listens for CloudKit sync events from `NSPersistentCloudKitContainer` and logs sync status. It also detects the `CKErrorUserDidResetEncryptedDataKey` condition.

- [ ] **Step 1: Write tests for the sync monitor**

Create `BaselineTests/Sync/CloudKitSyncMonitorTests.swift`:

```swift
import XCTest
import CloudKit
import CoreData
@testable import Baseline

final class CloudKitSyncMonitorTests: XCTestCase {

    func testDetectsKeychainResetError() {
        // Build a CKError with the userDidResetEncryptedDataKey flag
        let innerError = CKError(
            CKError.Code.zoneNotFound,
            userInfo: [CKErrorUserDidResetEncryptedDataKey: NSNumber(value: true)]
        )
        XCTAssertTrue(CloudKitSyncMonitor.isKeychainResetError(innerError))
    }

    func testIgnoresNormalZoneNotFoundError() {
        let normalError = CKError(CKError.Code.zoneNotFound)
        XCTAssertFalse(CloudKitSyncMonitor.isKeychainResetError(normalError))
    }

    func testIgnoresUnrelatedErrors() {
        let networkError = CKError(CKError.Code.networkUnavailable)
        XCTAssertFalse(CloudKitSyncMonitor.isKeychainResetError(networkError))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing BaselineTests/CloudKitSyncMonitorTests 2>&1 | tail -20`

Expected: FAIL — `CloudKitSyncMonitor` doesn't exist yet

- [ ] **Step 3: Implement CloudKitSyncMonitor**

Create `Baseline/Sync/CloudKitSyncMonitor.swift`:

```swift
import Foundation
import CloudKit
import CoreData
import os

/// Monitors NSPersistentCloudKitContainer sync events and handles the
/// iCloud Keychain reset edge case (encrypted field data becomes unreadable).
///
/// Call `CloudKitSyncMonitor.start(container:)` once at app launch.
enum CloudKitSyncMonitor {

    private static let logger = Logger(subsystem: "com.cadre.baseline", category: "CloudKitSync")
    private static var observer: NSObjectProtocol?

    /// Begin observing CloudKit sync events from the given container.
    static func start(container: NSPersistentContainer) {
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: container,
            queue: .main
        ) { notification in
            guard let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event else { return }

            if let error = event.error {
                handleSyncError(error)
            }
        }
    }

    /// Check whether a CKError indicates the user reset their iCloud Keychain,
    /// making previously encrypted CloudKit data unreadable.
    static func isKeychainResetError(_ error: CKError) -> Bool {
        guard error.code == .zoneNotFound else { return false }
        return error.userInfo[CKErrorUserDidResetEncryptedDataKey] != nil
    }

    // MARK: - Private

    private static func handleSyncError(_ error: Error) {
        // NSPersistentCloudKitContainer wraps CKErrors in its own error domain.
        // Walk the underlying error chain to find CKErrors.
        let nsError = error as NSError

        // Check the error itself
        if let ckError = error as? CKError {
            if isKeychainResetError(ckError) {
                handleKeychainReset()
                return
            }
        }

        // Check underlying errors (NSPersistentCloudKitContainer nests CKErrors)
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? CKError {
            if isKeychainResetError(underlying) {
                handleKeychainReset()
                return
            }
        }

        // Check partial failure errors for nested keychain reset
        if let partialErrors = nsError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
            for (_, partialError) in partialErrors {
                if let ckError = partialError as? CKError, isKeychainResetError(ckError) {
                    handleKeychainReset()
                    return
                }
            }
        }

        // Log non-keychain-reset sync errors for diagnostics
        logger.warning("CloudKit sync error: \(error.localizedDescription)")
    }

    private static func handleKeychainReset() {
        logger.error("iCloud Keychain was reset — encrypted CloudKit data is unreadable. Local data is intact.")
        // Local SwiftData store is unaffected (encryption is cloud-side only).
        // NSPersistentCloudKitContainer will automatically re-export local records
        // on the next sync cycle, encrypting them with the new key material.
        //
        // No manual zone deletion is needed when using NSPersistentCloudKitContainer —
        // the framework manages zone lifecycle. If sync stalls, the user can
        // force a re-sync by toggling iCloud off/on in Settings.
        //
        // Future enhancement: surface a non-blocking notification to the user
        // explaining that their data is safe locally and will re-sync shortly.
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing BaselineTests/CloudKitSyncMonitorTests 2>&1 | tail -20`

Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add Baseline/Sync/CloudKitSyncMonitor.swift BaselineTests/Sync/CloudKitSyncMonitorTests.swift
git commit -m "feat: add CloudKit sync monitor with keychain reset detection

Observes NSPersistentCloudKitContainer events and detects the
CKErrorUserDidResetEncryptedDataKey condition. Local data is
unaffected by keychain resets (encryption is cloud-side only)."
```

---

### Task 6: Wire CloudKitSyncMonitor into App Launch

**Files:**
- Modify: `Baseline/BaselineApp.swift`

- [ ] **Step 1: Add the monitor start call to BaselineApp.init()**

In `Baseline/BaselineApp.swift`, after the `ModelContainer` is created and before the mirror setup, add:

```swift
        // Monitor CloudKit sync events (keychain reset detection, error logging)
        CloudKitSyncMonitor.start(
            container: modelContainer.container
        )
```

Wait — `ModelContainer` in SwiftData doesn't directly expose `NSPersistentContainer`. We need to use `NSPersistentCloudKitContainer.eventChangedNotification` which fires globally. Update the monitor to observe without a specific container reference:

Instead, modify `CloudKitSyncMonitor.start(container:)` to `CloudKitSyncMonitor.start()` and pass `object: nil` to `NotificationCenter.default.addObserver`. Then in `BaselineApp.init()`, simply call:

```swift
        CloudKitSyncMonitor.start()
```

Place it right after `DecimalPadDoneBar.install()` and before the mirror setup.

The final `init()` should look like:

```swift
    init() {
        DecimalPadDoneBar.install()
        CloudKitSyncMonitor.start()

        // User data — syncs to iCloud via CloudKit, stored in shared App Group container
        let cloudSchema = Schema([WeightEntry.self, Scan.self, BaselineMeasurement.self, Goal.self])
        // ... rest unchanged
    }
```

- [ ] **Step 2: Update CloudKitSyncMonitor.start() signature**

Change the `start` method to not require a container parameter:

```swift
    static func start() {
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,  // observe all containers
            queue: .main
        ) { notification in
```

And update the test accordingly — the `start()` call in tests doesn't need a container either.

- [ ] **Step 3: Build and verify no compilation errors**

Run: `xcodebuild build -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16 Pro' 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Run full test suite to verify nothing regressed**

Run: `xcodebuild test -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16 Pro' 2>&1 | tail -30`

Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add Baseline/BaselineApp.swift Baseline/Sync/CloudKitSyncMonitor.swift
git commit -m "feat: wire CloudKit sync monitor into app launch

CloudKitSyncMonitor.start() called at app init alongside
DecimalPadDoneBar.install(). Observes all CloudKit container events."
```

---

### Task 7: Update FUTURE_WORK.md and Add App Review Notes

**Files:**
- Modify: `docs/FUTURE_WORK.md`
- Create: `docs/APP_REVIEW_NOTES.md`

- [ ] **Step 1: Mark the guideline 5.1.3 investigation as complete in FUTURE_WORK.md**

This was tracked as part of item 8 (Apple requirements spike). Add a completed entry in the Completed section:

```markdown
- [x] **Guideline 5.1.3 compliance** — CloudKit fields encrypted with `.allowsCloudEncryption`, sync monitor added for keychain reset edge case
```

- [ ] **Step 2: Create App Review Notes document**

Create `docs/APP_REVIEW_NOTES.md` with the submission notes we'll use when submitting to the App Store. These notes explain our architecture and compliance posture to the reviewer:

```markdown
# App Store Review Notes

Notes to include in the "App Review Information" section of App Store Connect when submitting Baseline for review.

---

## Health Data Architecture

Baseline is a personal body weight and body composition tracker. Users manually enter their own weight or scan an InBody body composition sheet.

### Data Storage

- All user health data is stored locally on-device in a SwiftData persistent store
- Cross-device sync uses CloudKit private database (user's own iCloud account)
- **All health-sensitive fields are end-to-end encrypted** using SwiftData's `.allowsCloudEncryption` attribute, which maps to CloudKit's `encryptedValues` API
- Encrypted fields: body weight values, body composition measurements, scan payloads, goal target/start values, user notes
- Structural fields (dates, IDs, measurement types, goal status) are not encrypted as they contain no personally identifiable health information
- No health data is stored on any developer-operated server
- No health data is shared with any third party

### HealthKit Integration

- Baseline **writes** to HealthKit only (weight, body fat percentage, BMR, body measurements)
- Baseline does **not** read from HealthKit
- All HealthKit data originates from user manual entry, not from HealthKit queries
- HealthKit data is not used for advertising, marketing, or data mining

### Privacy

- Privacy manifest (`PrivacyInfo.xcprivacy`) declares health data collection for app functionality
- No tracking, no analytics, no third-party SDKs
- Users can export all data via CSV from Settings
- Users can delete all data from Settings
```

- [ ] **Step 3: Commit**

```bash
git add docs/FUTURE_WORK.md docs/APP_REVIEW_NOTES.md
git commit -m "docs: add App Review notes and mark 5.1.3 compliance complete

App Review notes document our encryption architecture, HealthKit
write-only usage, and privacy posture for App Store submission."
```

---

## Encryption Decision Summary

For reference, here is the complete field-by-field encryption map:

### WeightEntry
| Field | Encrypted | Reason |
|-------|-----------|--------|
| `id` | No | Structural identifier |
| `weight` | **Yes** | Health measurement |
| `unit` | No | Non-identifying metadata |
| `date` | No | Needed for sorting/filtering |
| `notes` | **Yes** | May contain personal health context |
| `photoData` | **Yes** | May contain body/scale photos |
| `createdAt` | No | Metadata timestamp |
| `updatedAt` | No | Metadata timestamp |

### Scan
| Field | Encrypted | Reason |
|-------|-----------|--------|
| `id` | No | Structural identifier |
| `date` | No | Needed for sorting/filtering |
| `type` | No | Non-identifying enum (e.g. "inBody") |
| `source` | No | Non-identifying enum (e.g. "ocr") |
| `notes` | **Yes** | May contain personal context |
| `payloadData` | **Yes** | Full body composition data (weight, body fat, muscle mass, etc.) |
| `createdAt` | No | Metadata timestamp |
| `updatedAt` | No | Metadata timestamp |

### Measurement
| Field | Encrypted | Reason |
|-------|-----------|--------|
| `id` | No | Structural identifier |
| `date` | No | Needed for sorting/filtering |
| `type` | No | Non-identifying enum (e.g. "waist") |
| `valueCm` | **Yes** | Health measurement |
| `notes` | **Yes** | May contain personal context |
| `createdAt` | No | Metadata timestamp |
| `updatedAt` | No | Metadata timestamp |

### Goal
| Field | Encrypted | Reason |
|-------|-----------|--------|
| `id` | No | Structural identifier |
| `metric` | No | Needed for filtering ("which metric has a goal?") |
| `targetValue` | **Yes** | Health target (e.g. target weight) |
| `targetDate` | No | Non-identifying date |
| `startValue` | **Yes** | Health baseline measurement |
| `startDate` | No | Non-identifying date |
| `status` | No | Needed for filtering (active/completed/abandoned) |
| `completedDate` | No | Non-identifying date |
| `createdAt` | No | Metadata timestamp |

### SyncState (local-only, no CloudKit sync)
| Field | Encrypted | Reason |
|-------|-----------|--------|
| `tableName` | N/A | Not synced to CloudKit |
| `lastSyncTimestamp` | N/A | Not synced to CloudKit |
