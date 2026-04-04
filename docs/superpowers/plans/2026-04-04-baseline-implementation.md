# Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native iOS weight & body composition tracker — the second app in the Cadre ecosystem — with zero-friction daily logging, InBody scan OCR, trend charts, D1 sync, iCloud backup, HealthKit writes, and widgets.

**Architecture:** SwiftUI app with SwiftData persistence, MVVM pattern using @Observable ViewModels (iOS 17+). Three-tab navigation with raised center "Today" tab. Push-only sync to Cloudflare D1 via Swift SyncEngine. CloudKit for iCloud device sync. Vision framework for InBody printout OCR.

**Tech Stack:** Swift, SwiftUI, SwiftData, CloudKit, HealthKit, Swift Charts, Vision, WidgetKit, TipKit, XcodeGen

**Spec:** `docs/superpowers/specs/2026-04-02-baseline-app-design.md`

---

## Design Gates

This is a **design-driven, mockup-first** app. The following screens require a high-fidelity mockup (HTML visual companion or Figma) approved by the user BEFORE implementing the UI. The plan marks these with **[DESIGN GATE]**. When you hit one, pause implementation, create the mockup, get approval, then proceed.

| Screen | Open Design Questions |
|--------|----------------------|
| Today | Layout, weight display, delta styling, sparkline placement |
| WeighIn Sheet | Input method (stepper vs arc vs hybrid), step-size toggle UX |
| Trends | Moving average line, body comp overlay markers, training phase bands, time range tabs |
| Body Tab | Measurements hub layout, metric cards, scan list |
| Scan Entry | Camera viewfinder UX, field review/correction UI |
| Tab Bar | Raised center tab styling (how much larger, what visual treatment) |
| Widgets | Home screen and lock screen widget designs |

---

## File Structure

```
Baseline/
├── BaselineApp.swift                  # App entry, ModelContainer setup
├── Models/
│   ├── WeightEntry.swift              # @Model — daily weight
│   ├── InBodyScan.swift               # @Model — scan data
│   ├── BodyMeasurement.swift          # @Model — EAV measurements
│   ├── SyncState.swift                # @Model — sync tracking
│   └── MeasurementType.swift          # Enum for measurement types
├── ViewModels/
│   ├── TodayViewModel.swift           # Today screen state + logic
│   ├── WeighInViewModel.swift         # Weight entry logic
│   ├── TrendsViewModel.swift          # Chart data + moving average
│   ├── BodyViewModel.swift            # Body tab state + logic
│   ├── ScanViewModel.swift            # OCR + scan entry logic
│   ├── HistoryViewModel.swift         # History list + deltas
│   └── SettingsViewModel.swift        # Units, export, sync config
├── Views/
│   ├── Navigation/
│   │   └── MainTabView.swift          # 3-tab navigation + custom bar
│   ├── Today/
│   │   ├── TodayView.swift            # Home screen
│   │   └── WeighInSheet.swift         # Weight entry modal
│   ├── Trends/
│   │   └── TrendsView.swift           # Charts screen
│   ├── Body/
│   │   ├── BodyView.swift             # Measurements hub
│   │   ├── LogMeasurementSheet.swift  # Quick measurement entry
│   │   ├── LogScanView.swift          # Camera + manual scan entry
│   │   └── ScanDetailView.swift       # Full scan data view
│   ├── History/
│   │   └── HistoryView.swift          # Chronological weight list
│   └── Settings/
│       └── SettingsView.swift         # Units, export, sync, about
├── Design/
│   ├── CadreTokens.swift              # Colors, spacing, typography
│   └── Components/
│       ├── StatCard.swift             # Reusable stat display card
│       └── SparklineView.swift        # Mini trend sparkline
├── Sync/
│   ├── SyncEngine.swift               # D1 push sync
│   ├── SyncConfig.swift               # Table push configs
│   └── APIClient.swift                # HTTP client for D1 API
├── Health/
│   └── HealthKitManager.swift         # HealthKit write operations
├── OCR/
│   └── InBodyOCRParser.swift          # Vision framework OCR parsing
├── Utilities/
│   ├── DateFormatting.swift           # Date display helpers
│   └── UnitConversion.swift           # lb ↔ kg conversion
└── Info.plist

BaselineTests/
├── Models/
│   ├── WeightEntryTests.swift
│   └── BodyMeasurementTests.swift
├── ViewModels/
│   ├── TodayViewModelTests.swift
│   ├── WeighInViewModelTests.swift
│   ├── TrendsViewModelTests.swift
│   ├── BodyViewModelTests.swift
│   └── HistoryViewModelTests.swift
├── Sync/
│   ├── SyncEngineTests.swift
│   └── APIClientTests.swift
├── Health/
│   └── HealthKitManagerTests.swift
├── OCR/
│   └── InBodyOCRParserTests.swift
└── Utilities/
    └── UnitConversionTests.swift

BaselineWidgets/
├── BaselineWidgets.swift              # Widget bundle entry
├── WeightWidget.swift                 # Home screen widget
├── WeightLockScreenWidget.swift       # Lock screen widget
└── Info.plist
```

---

## Phase 1: Foundation

### Task 1: Project Setup with XcodeGen

**Files:**
- Create: `project.yml`
- Create: `Baseline/BaselineApp.swift`
- Create: `Baseline/Info.plist`
- Create: `Baseline/Baseline.entitlements`
- Create: `BaselineTests/BaselineTests.swift`

- [ ] **Step 1: Install XcodeGen if needed**

```bash
which xcodegen || brew install xcodegen
```

- [ ] **Step 2: Create project.yml**

```yaml
name: Baseline
options:
  bundleIdPrefix: com.cadre
  deploymentTarget:
    iOS: "17.0"
  xcodeVersion: "16.0"
  generateEmptyDirectories: true
  groupSortPosition: top

settings:
  base:
    SWIFT_VERSION: "5.9"
    MARKETING_VERSION: "1.0.0"
    CURRENT_PROJECT_VERSION: 1

targets:
  Baseline:
    type: application
    platform: iOS
    sources:
      - path: Baseline
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.cadre.baseline
        INFOPLIST_FILE: Baseline/Info.plist
        CODE_SIGN_ENTITLEMENTS: Baseline/Baseline.entitlements
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
    entitlements:
      path: Baseline/Baseline.entitlements
    dependencies:
      - target: BaselineWidgets

  BaselineTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: BaselineTests
    dependencies:
      - target: Baseline

  BaselineWidgets:
    type: app-extension
    platform: iOS
    info:
      path: BaselineWidgets/Info.plist
      properties:
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension
    sources:
      - path: BaselineWidgets
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.cadre.baseline.widgets
```

- [ ] **Step 3: Create the app entry point**

Create `Baseline/BaselineApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct BaselineApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                WeightEntry.self,
                InBodyScan.self,
                BodyMeasurement.self,
                SyncState.self,
            ])
            let config = ModelConfiguration(
                "Baseline",
                schema: schema,
                cloudKitDatabase: .automatic
            )
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to configure SwiftData: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(modelContainer)
    }
}
```

- [ ] **Step 4: Create Info.plist**

Create `Baseline/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSHealthUpdateUsageDescription</key>
    <string>Baseline writes your weight and body composition to Apple Health so other apps can access it.</string>
    <key>NSCameraUsageDescription</key>
    <string>Baseline uses the camera to scan InBody printouts and extract your body composition data.</string>
</dict>
</plist>
```

- [ ] **Step 5: Create entitlements file**

Create `Baseline/Baseline.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array/>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.cadre.baseline</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.cadre.baseline</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 6: Create placeholder MainTabView so the app compiles**

Create `Baseline/Views/Navigation/MainTabView.swift`:

```swift
import SwiftUI

struct MainTabView: View {
    var body: some View {
        Text("Baseline")
    }
}

#Preview {
    MainTabView()
}
```

- [ ] **Step 7: Create placeholder widget target**

Create `BaselineWidgets/BaselineWidgets.swift`:

```swift
import WidgetKit
import SwiftUI

struct BaselineWidgetPlaceholder: Widget {
    let kind = "BaselineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaceholderProvider()) { _ in
            Text("Baseline")
        }
        .configurationDisplayName("Weight")
        .description("Today's weight at a glance.")
    }
}

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry { SimpleEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) { completion(SimpleEntry(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        completion(Timeline(entries: [SimpleEntry(date: .now)], policy: .atEnd))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}
```

Create `BaselineWidgets/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
</dict>
</plist>
```

- [ ] **Step 8: Create placeholder test**

Create `BaselineTests/BaselineTests.swift`:

```swift
import XCTest
@testable import Baseline

final class BaselineTests: XCTestCase {
    func testAppLaunches() {
        // Placeholder — verifies the test target links correctly
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 9: Generate Xcode project and build**

```bash
cd /Users/ben/projects/baseline
xcodegen generate
xcodebuild -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 10: Run tests**

```bash
xcodebuild -project Baseline.xcodeproj -scheme BaselineTests -destination 'platform=iOS Simulator,name=iPhone 16' test 2>&1 | tail -5
```

Expected: TEST SUCCEEDED, 1 test passed

- [ ] **Step 11: Commit**

```bash
git add project.yml Baseline/ BaselineTests/ BaselineWidgets/ .gitignore
git commit -m "feat: scaffold Xcode project with XcodeGen — SwiftData, CloudKit, HealthKit, WidgetKit"
```

---

### Task 2: WeightEntry Model + Tests

**Files:**
- Create: `Baseline/Models/WeightEntry.swift`
- Create: `BaselineTests/Models/WeightEntryTests.swift`

- [ ] **Step 1: Write failing tests for WeightEntry**

Create `BaselineTests/Models/WeightEntryTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Baseline

final class WeightEntryTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([WeightEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    func testCreateWeightEntry() {
        let entry = WeightEntry(weight: 197.4, unit: "lb", date: Date())
        context.insert(entry)
        try! context.save()

        let descriptor = FetchDescriptor<WeightEntry>()
        let entries = try! context.fetch(descriptor)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.weight, 197.4)
        XCTAssertEqual(entries.first?.unit, "lb")
    }

    func testDefaultUnitIsLb() {
        let entry = WeightEntry(weight: 200.0)
        XCTAssertEqual(entry.unit, "lb")
    }

    func testWeightInKg() {
        let entry = WeightEntry(weight: 89.5, unit: "kg", date: Date())
        XCTAssertEqual(entry.weightInKg, 89.5)

        let lbEntry = WeightEntry(weight: 197.4, unit: "lb", date: Date())
        XCTAssertEqual(lbEntry.weightInKg, 89.5, accuracy: 0.1)
    }

    func testWeightInLb() {
        let entry = WeightEntry(weight: 89.5, unit: "kg", date: Date())
        XCTAssertEqual(entry.weightInLb, 197.3, accuracy: 0.1)

        let lbEntry = WeightEntry(weight: 197.4, unit: "lb", date: Date())
        XCTAssertEqual(lbEntry.weightInLb, 197.4)
    }

    func testUpdatedAtAutoSets() {
        let entry = WeightEntry(weight: 197.4)
        XCTAssertNotNil(entry.updatedAt)
        XCTAssertNotNil(entry.createdAt)
    }

    func testDateStrippedToMidnight() {
        let now = Date()
        let entry = WeightEntry(weight: 197.4, date: now)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: entry.date)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
xcodebuild test -project Baseline.xcodeproj -scheme BaselineTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(FAIL|error:)" | head -5
```

Expected: Compilation errors — `WeightEntry` not found.

- [ ] **Step 3: Implement WeightEntry model**

Create `Baseline/Models/WeightEntry.swift`:

```swift
import Foundation
import SwiftData

@Model
class WeightEntry {
    var id: UUID
    var weight: Double
    var unit: String
    var date: Date
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    init(weight: Double, unit: String = "lb", date: Date = Date(), notes: String? = nil) {
        self.id = UUID()
        self.weight = weight
        self.unit = unit
        self.date = Calendar.current.startOfDay(for: date)
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Weight converted to kilograms
    var weightInKg: Double {
        unit == "kg" ? weight : weight * 0.45359237
    }

    /// Weight converted to pounds
    var weightInLb: Double {
        unit == "lb" ? weight : weight / 0.45359237
    }
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
xcodebuild test -project Baseline.xcodeproj -scheme BaselineTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(Test Suite|Passed|Failed)" | tail -5
```

Expected: All tests passed.

- [ ] **Step 5: Commit**

```bash
git add Baseline/Models/WeightEntry.swift BaselineTests/Models/WeightEntryTests.swift
git commit -m "feat: add WeightEntry SwiftData model with unit conversion"
```

---

### Task 3: InBodyScan + BodyMeasurement + SyncState Models

**Files:**
- Create: `Baseline/Models/InBodyScan.swift`
- Create: `Baseline/Models/BodyMeasurement.swift`
- Create: `Baseline/Models/SyncState.swift`
- Create: `Baseline/Models/MeasurementType.swift`
- Create: `BaselineTests/Models/BodyMeasurementTests.swift`

- [ ] **Step 1: Write failing tests for BodyMeasurement and MeasurementType**

Create `BaselineTests/Models/BodyMeasurementTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Baseline

final class BodyMeasurementTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([BodyMeasurement.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    func testCreateManualMeasurement() {
        let m = BodyMeasurement(
            date: Date(),
            type: .waist,
            value: 33.5,
            unit: "in",
            source: .manual
        )
        context.insert(m)
        try! context.save()

        let descriptor = FetchDescriptor<BodyMeasurement>()
        let results = try! context.fetch(descriptor)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.type, MeasurementType.waist.rawValue)
        XCTAssertEqual(results.first?.source, MeasurementSource.manual.rawValue)
    }

    func testCreateInBodyMeasurement() {
        let m = BodyMeasurement(
            date: Date(),
            type: .bodyFatPercentage,
            value: 18.5,
            unit: "%",
            source: .inbody
        )
        XCTAssertEqual(m.source, MeasurementSource.inbody.rawValue)
    }

    func testMeasurementTypeCoversExpectedTypes() {
        // Verify all expected measurement types exist
        let expectedTypes: [MeasurementType] = [
            .waist, .neck, .chest, .rightArm, .leftArm,
            .rightThigh, .leftThigh, .hips,
            .bodyFatPercentage, .skeletalMuscleMass, .leanBodyMass
        ]
        for type in expectedTypes {
            XCTAssertFalse(type.rawValue.isEmpty, "\(type) should have a non-empty rawValue")
        }
    }

    func testMeasurementTypeDisplayName() {
        XCTAssertEqual(MeasurementType.waist.displayName, "Waist")
        XCTAssertEqual(MeasurementType.rightArm.displayName, "Right Arm")
        XCTAssertEqual(MeasurementType.bodyFatPercentage.displayName, "Body Fat %")
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
xcodebuild test -project Baseline.xcodeproj -scheme BaselineTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(error:)" | head -5
```

Expected: Compilation errors — models not found.

- [ ] **Step 3: Implement MeasurementType enum**

Create `Baseline/Models/MeasurementType.swift`:

```swift
import Foundation

enum MeasurementType: String, CaseIterable, Codable {
    // Manual tape measurements
    case waist = "waist"
    case neck = "neck"
    case chest = "chest"
    case rightArm = "right_arm"
    case leftArm = "left_arm"
    case rightThigh = "right_thigh"
    case leftThigh = "left_thigh"
    case hips = "hips"

    // Body comp metrics (from InBody or manual)
    case bodyFatPercentage = "body_fat_pct"
    case skeletalMuscleMass = "skeletal_muscle_mass"
    case bodyFatMass = "body_fat_mass"
    case leanBodyMass = "lean_body_mass"
    case totalBodyWater = "total_body_water"
    case bmi = "bmi"
    case basalMetabolicRate = "basal_metabolic_rate"
    case inBodyScore = "inbody_score"

    // Segmental lean
    case rightArmLean = "right_arm_lean"
    case leftArmLean = "left_arm_lean"
    case trunkLean = "trunk_lean"
    case rightLegLean = "right_leg_lean"
    case leftLegLean = "left_leg_lean"

    // Segmental fat
    case rightArmFat = "right_arm_fat"
    case leftArmFat = "left_arm_fat"
    case trunkFat = "trunk_fat"
    case rightLegFat = "right_leg_fat"
    case leftLegFat = "left_leg_fat"

    // Custom user-defined measurement
    case custom = "custom"

    var displayName: String {
        switch self {
        case .waist: return "Waist"
        case .neck: return "Neck"
        case .chest: return "Chest"
        case .rightArm: return "Right Arm"
        case .leftArm: return "Left Arm"
        case .rightThigh: return "Right Thigh"
        case .leftThigh: return "Left Thigh"
        case .hips: return "Hips"
        case .bodyFatPercentage: return "Body Fat %"
        case .skeletalMuscleMass: return "Skeletal Muscle Mass"
        case .bodyFatMass: return "Body Fat Mass"
        case .leanBodyMass: return "Lean Body Mass"
        case .totalBodyWater: return "Total Body Water"
        case .bmi: return "BMI"
        case .basalMetabolicRate: return "Basal Metabolic Rate"
        case .inBodyScore: return "InBody Score"
        case .rightArmLean: return "Right Arm (Lean)"
        case .leftArmLean: return "Left Arm (Lean)"
        case .trunkLean: return "Trunk (Lean)"
        case .rightLegLean: return "Right Leg (Lean)"
        case .leftLegLean: return "Left Leg (Lean)"
        case .rightArmFat: return "Right Arm (Fat)"
        case .leftArmFat: return "Left Arm (Fat)"
        case .trunkFat: return "Trunk (Fat)"
        case .rightLegFat: return "Right Leg (Fat)"
        case .leftLegFat: return "Left Leg (Fat)"
        case .custom: return "Custom"
        }
    }

    /// Default unit for this measurement type
    var defaultUnit: String {
        switch self {
        case .bodyFatPercentage: return "%"
        case .bmi, .inBodyScore, .basalMetabolicRate, .custom: return ""
        case .totalBodyWater: return "L"
        case .skeletalMuscleMass, .bodyFatMass, .leanBodyMass,
             .rightArmLean, .leftArmLean, .trunkLean, .rightLegLean, .leftLegLean,
             .rightArmFat, .leftArmFat, .trunkFat, .rightLegFat, .leftLegFat:
            return "lb"
        default:
            return "in"
        }
    }
}

enum MeasurementSource: String, Codable {
    case manual = "manual"
    case inbody = "inbody"
}
```

- [ ] **Step 4: Implement BodyMeasurement model**

Create `Baseline/Models/BodyMeasurement.swift`:

```swift
import Foundation
import SwiftData

@Model
class BodyMeasurement {
    var id: UUID
    var date: Date
    var type: String
    var value: Double
    var unit: String
    var source: String
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        date: Date,
        type: MeasurementType,
        value: Double,
        unit: String? = nil,
        source: MeasurementSource = .manual,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.type = type.rawValue
        self.value = value
        self.unit = unit ?? type.defaultUnit
        self.source = source.rawValue
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var measurementType: MeasurementType? {
        MeasurementType(rawValue: type)
    }

    var measurementSource: MeasurementSource? {
        MeasurementSource(rawValue: source)
    }
}
```

- [ ] **Step 5: Implement InBodyScan model**

Create `Baseline/Models/InBodyScan.swift`:

```swift
import Foundation
import SwiftData

@Model
class InBodyScan {
    var id: UUID
    var date: Date
    var weight: Double
    var unit: String
    var bodyFatPercentage: Double?
    var skeletalMuscleMass: Double?
    var bodyFatMass: Double?
    var bmi: Double?
    var totalBodyWater: Double?
    var leanBodyMass: Double?
    var basalMetabolicRate: Double?
    var inBodyScore: Double?
    // Segmental lean
    var rightArmLean: Double?
    var leftArmLean: Double?
    var trunkLean: Double?
    var rightLegLean: Double?
    var leftLegLean: Double?
    // Segmental fat
    var rightArmFat: Double?
    var leftArmFat: Double?
    var trunkFat: Double?
    var rightLegFat: Double?
    var leftLegFat: Double?
    // Raw data
    var rawOcrText: String?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    init(date: Date, weight: Double, unit: String = "lb") {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.weight = weight
        self.unit = unit
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Returns BodyMeasurement records for all non-nil metrics on this scan.
    /// Used when saving a scan to also write individual measurements
    /// so the Body tab can trend all metrics uniformly.
    func toBodyMeasurements() -> [BodyMeasurement] {
        var measurements: [BodyMeasurement] = []

        let pairs: [(MeasurementType, Double?, String)] = [
            (.bodyFatPercentage, bodyFatPercentage, "%"),
            (.skeletalMuscleMass, skeletalMuscleMass, unit),
            (.bodyFatMass, bodyFatMass, unit),
            (.leanBodyMass, leanBodyMass, unit),
            (.bmi, bmi, ""),
            (.totalBodyWater, totalBodyWater, "L"),
            (.basalMetabolicRate, basalMetabolicRate, ""),
            (.inBodyScore, inBodyScore, ""),
            (.rightArmLean, rightArmLean, unit),
            (.leftArmLean, leftArmLean, unit),
            (.trunkLean, trunkLean, unit),
            (.rightLegLean, rightLegLean, unit),
            (.leftLegLean, leftLegLean, unit),
            (.rightArmFat, rightArmFat, unit),
            (.leftArmFat, leftArmFat, unit),
            (.trunkFat, trunkFat, unit),
            (.rightLegFat, rightLegFat, unit),
            (.leftLegFat, leftLegFat, unit),
        ]

        for (type, value, measureUnit) in pairs {
            if let value {
                measurements.append(BodyMeasurement(
                    date: date,
                    type: type,
                    value: value,
                    unit: measureUnit,
                    source: .inbody
                ))
            }
        }

        return measurements
    }
}
```

- [ ] **Step 6: Implement SyncState model**

Create `Baseline/Models/SyncState.swift`:

```swift
import Foundation
import SwiftData

@Model
class SyncState {
    @Attribute(.unique) var tableName: String
    var lastSyncTimestamp: String

    init(tableName: String, lastSyncTimestamp: String = "") {
        self.tableName = tableName
        self.lastSyncTimestamp = lastSyncTimestamp
    }
}
```

- [ ] **Step 7: Update BaselineApp.swift to include all models in schema**

The schema in `BaselineApp.swift` already includes all four models from Task 1. Verify it compiles.

- [ ] **Step 8: Run tests — verify all pass**

```bash
xcodebuild test -project Baseline.xcodeproj -scheme BaselineTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(Test Suite|Passed|Failed)" | tail -5
```

Expected: All tests pass.

- [ ] **Step 9: Commit**

```bash
git add Baseline/Models/ BaselineTests/Models/
git commit -m "feat: add InBodyScan, BodyMeasurement, SyncState models with measurement types"
```

---

### Task 4: Utility Helpers + Tests

**Files:**
- Create: `Baseline/Utilities/UnitConversion.swift`
- Create: `Baseline/Utilities/DateFormatting.swift`
- Create: `BaselineTests/Utilities/UnitConversionTests.swift`

- [ ] **Step 1: Write failing tests for unit conversion**

Create `BaselineTests/Utilities/UnitConversionTests.swift`:

```swift
import XCTest
@testable import Baseline

final class UnitConversionTests: XCTestCase {
    func testLbToKg() {
        XCTAssertEqual(UnitConversion.lbToKg(197.4), 89.5, accuracy: 0.1)
    }

    func testKgToLb() {
        XCTAssertEqual(UnitConversion.kgToLb(89.5), 197.3, accuracy: 0.1)
    }

    func testRoundTrip() {
        let original = 185.0
        let converted = UnitConversion.kgToLb(UnitConversion.lbToKg(original))
        XCTAssertEqual(converted, original, accuracy: 0.01)
    }

    func testFormatWeight() {
        XCTAssertEqual(UnitConversion.formatWeight(197.4, unit: "lb"), "197.4")
        XCTAssertEqual(UnitConversion.formatWeight(197.0, unit: "lb"), "197.0")
        XCTAssertEqual(UnitConversion.formatWeight(89.53, unit: "kg"), "89.5")
    }

    func testFormatDelta() {
        XCTAssertEqual(UnitConversion.formatDelta(0.6), "+0.6")
        XCTAssertEqual(UnitConversion.formatDelta(-1.2), "-1.2")
        XCTAssertEqual(UnitConversion.formatDelta(0.0), "0.0")
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

Expected: Compilation error — `UnitConversion` not found.

- [ ] **Step 3: Implement UnitConversion**

Create `Baseline/Utilities/UnitConversion.swift`:

```swift
import Foundation

enum UnitConversion {
    static let lbPerKg = 2.20462262

    static func lbToKg(_ lb: Double) -> Double {
        lb / lbPerKg
    }

    static func kgToLb(_ kg: Double) -> Double {
        kg * lbPerKg
    }

    static func formatWeight(_ value: Double, unit: String) -> String {
        String(format: "%.1f", value)
    }

    static func formatDelta(_ delta: Double) -> String {
        if delta > 0 {
            return "+\(String(format: "%.1f", delta))"
        } else if delta < 0 {
            return String(format: "%.1f", delta)
        } else {
            return "0.0"
        }
    }
}
```

- [ ] **Step 4: Implement DateFormatting**

Create `Baseline/Utilities/DateFormatting.swift`:

```swift
import Foundation

enum DateFormatting {
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static let fullFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// "Apr 4"
    static func shortDay(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    /// "Apr 4, 2026"
    static func fullDate(_ date: Date) -> String {
        fullFormatter.string(from: date)
    }

    /// ISO 8601 string for sync timestamps
    static func iso8601(_ date: Date) -> String {
        iso8601Formatter.string(from: date)
    }

    /// Parse ISO 8601 string
    static func fromISO8601(_ string: String) -> Date? {
        iso8601Formatter.date(from: string)
    }

    /// True if date is today
    static func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    /// True if date is yesterday
    static func isYesterday(_ date: Date) -> Bool {
        Calendar.current.isDateInYesterday(date)
    }
}
```

- [ ] **Step 5: Run tests — verify all pass**

```bash
xcodebuild test -project Baseline.xcodeproj -scheme BaselineTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(Passed|Failed)" | tail -5
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add Baseline/Utilities/ BaselineTests/Utilities/
git commit -m "feat: add UnitConversion and DateFormatting helpers"
```

---

### Task 5: Design Tokens (Scaffold)

**Files:**
- Create: `Baseline/Design/CadreTokens.swift`

Design token **values** will be refined during mockup phase. This task creates the structure with reasonable starting values. The dark-theme, premium aesthetic is the direction.

- [ ] **Step 1: Create CadreTokens.swift**

```swift
import SwiftUI

// MARK: - Colors
// Values are placeholders — refined during high-fidelity mockup phase.
// This file becomes the seed of CadreKit when Apex migrates to Swift.

enum CadreColors {
    // Backgrounds
    static let bg = Color(hex: "0A0A0F")
    static let card = Color(hex: "16161F")
    static let cardElevated = Color(hex: "1E1E2A")

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "8E8E9A")
    static let textTertiary = Color(hex: "5A5A66")

    // Accent
    static let accent = Color(hex: "6C63FF")
    static let accentLight = Color(hex: "8B84FF")

    // Semantic
    static let positive = Color(hex: "34C759")
    static let negative = Color(hex: "FF3B30")
    static let neutral = Color(hex: "8E8E9A")

    // Chart
    static let chartLine = Color(hex: "6C63FF")
    static let chartMovingAverage = Color(hex: "FF9F0A")
    static let chartFill = Color(hex: "6C63FF").opacity(0.15)
    static let chartGrid = Color(hex: "2A2A36")
}

// MARK: - Spacing

enum CadreSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Typography

enum CadreTypography {
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title = Font.system(size: 28, weight: .bold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 17, weight: .regular)
    static let callout = Font.system(size: 16, weight: .regular)
    static let subheadline = Font.system(size: 15, weight: .regular)
    static let footnote = Font.system(size: 13, weight: .regular)
    static let caption = Font.system(size: 12, weight: .regular)

    // Weight display — the big number on Today screen
    static let weightDisplay = Font.system(size: 64, weight: .bold, design: .rounded)
    static let weightUnit = Font.system(size: 20, weight: .medium, design: .rounded)
    static let deltaDisplay = Font.system(size: 17, weight: .medium, design: .rounded)
}

// MARK: - Corner Radius

enum CadreRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let full: CGFloat = 9999
}

// MARK: - Color Hex Init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}
```

- [ ] **Step 2: Build to verify compilation**

```bash
xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Baseline/Design/CadreTokens.swift
git commit -m "feat: scaffold Cadre design tokens — colors, spacing, typography, radii"
```

---

### Task 6: Three-Tab Navigation Shell

**Files:**
- Modify: `Baseline/Views/Navigation/MainTabView.swift`

- [ ] **Step 1: Implement MainTabView with three tabs**

Replace `Baseline/Views/Navigation/MainTabView.swift`:

```swift
import SwiftUI

enum AppTab: Int, CaseIterable {
    case trends
    case today
    case body
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            TrendsPlaceholder()
                .tabItem {
                    Label("Trends", systemImage: "chart.xyaxis.line")
                }
                .tag(AppTab.trends)

            TodayPlaceholder()
                .tabItem {
                    Label("Today", systemImage: "scalemass.fill")
                }
                .tag(AppTab.today)

            BodyPlaceholder()
                .tabItem {
                    Label("Body", systemImage: "figure.stand")
                }
                .tag(AppTab.body)
        }
        .tint(CadreColors.accent)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Placeholder screens (replaced in later tasks)

private struct TodayPlaceholder: View {
    var body: some View {
        NavigationStack {
            ZStack {
                CadreColors.bg.ignoresSafeArea()
                Text("Today")
                    .font(CadreTypography.title)
                    .foregroundStyle(CadreColors.textPrimary)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { } label: {
                        Image(systemName: "list.bullet")
                    }
                }
            }
        }
    }
}

private struct TrendsPlaceholder: View {
    var body: some View {
        NavigationStack {
            ZStack {
                CadreColors.bg.ignoresSafeArea()
                Text("Trends")
                    .font(CadreTypography.title)
                    .foregroundStyle(CadreColors.textPrimary)
            }
            .navigationTitle("Trends")
        }
    }
}

private struct BodyPlaceholder: View {
    var body: some View {
        NavigationStack {
            ZStack {
                CadreColors.bg.ignoresSafeArea()
                Text("Body")
                    .font(CadreTypography.title)
                    .foregroundStyle(CadreColors.textPrimary)
            }
            .navigationTitle("Body")
        }
    }
}

#Preview {
    MainTabView()
}
```

- [ ] **Step 2: Build and run in simulator to verify tabs work**

```bash
xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED. App launches with 3 tabs, Today selected by default, dark theme.

- [ ] **Step 3: Commit**

```bash
git add Baseline/Views/Navigation/MainTabView.swift
git commit -m "feat: add three-tab navigation shell — Trends, Today (center), Body"
```

---

## Phase 2: Core Daily Flow

### Task 7: TodayViewModel + Tests

**Files:**
- Create: `Baseline/ViewModels/TodayViewModel.swift`
- Create: `BaselineTests/ViewModels/TodayViewModelTests.swift`

- [ ] **Step 1: Write failing tests**

Create `BaselineTests/ViewModels/TodayViewModelTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Baseline

final class TodayViewModelTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([WeightEntry.self, InBodyScan.self, BodyMeasurement.self, SyncState.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    func testTodayEntryNilWhenNoEntries() {
        let vm = TodayViewModel(modelContext: context)
        vm.refresh()
        XCTAssertNil(vm.todayEntry)
    }

    func testTodayEntryFoundWhenExists() {
        let entry = WeightEntry(weight: 197.4, date: Date())
        context.insert(entry)
        try! context.save()

        let vm = TodayViewModel(modelContext: context)
        vm.refresh()
        XCTAssertNotNil(vm.todayEntry)
        XCTAssertEqual(vm.todayEntry?.weight, 197.4)
    }

    func testDeltaFromYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayEntry = WeightEntry(weight: 197.0, date: yesterday)
        let todayEntry = WeightEntry(weight: 197.6, date: Date())
        context.insert(yesterdayEntry)
        context.insert(todayEntry)
        try! context.save()

        let vm = TodayViewModel(modelContext: context)
        vm.refresh()
        XCTAssertEqual(vm.delta, 0.6, accuracy: 0.01)
    }

    func testDeltaNilWhenOnlyOneEntry() {
        let entry = WeightEntry(weight: 197.4, date: Date())
        context.insert(entry)
        try! context.save()

        let vm = TodayViewModel(modelContext: context)
        vm.refresh()
        XCTAssertNil(vm.delta)
    }

    func testPreviousEntryIsYesterdayNotOlder() {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let oldEntry = WeightEntry(weight: 195.0, date: threeDaysAgo)
        let todayEntry = WeightEntry(weight: 197.4, date: Date())
        context.insert(oldEntry)
        context.insert(todayEntry)
        try! context.save()

        let vm = TodayViewModel(modelContext: context)
        vm.refresh()
        // Delta compares to most recent previous entry, not just yesterday
        XCTAssertEqual(vm.delta, 2.4, accuracy: 0.01)
    }

    func testRecentEntriesForSparkline() {
        // Insert 10 days of entries
        for i in 0..<10 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            let entry = WeightEntry(weight: 195.0 + Double(i) * 0.3, date: date)
            context.insert(entry)
        }
        try! context.save()

        let vm = TodayViewModel(modelContext: context)
        vm.refresh()
        XCTAssertEqual(vm.recentWeights.count, 10)
    }

    func testLastWeightForWeighInDefault() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let entry = WeightEntry(weight: 197.4, date: yesterday)
        context.insert(entry)
        try! context.save()

        let vm = TodayViewModel(modelContext: context)
        vm.refresh()
        XCTAssertEqual(vm.lastWeight, 197.4)
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

Expected: Compilation error — `TodayViewModel` not found.

- [ ] **Step 3: Implement TodayViewModel**

Create `Baseline/ViewModels/TodayViewModel.swift`:

```swift
import Foundation
import SwiftData
import Observation

@Observable
class TodayViewModel {
    private let modelContext: ModelContext

    var todayEntry: WeightEntry?
    var previousEntry: WeightEntry?
    var recentWeights: [WeightEntry] = []

    var delta: Double? {
        guard let today = todayEntry, let previous = previousEntry else { return nil }
        return today.weight - previous.weight
    }

    /// The most recent weight — used as default for the WeighIn sheet
    var lastWeight: Double? {
        if let todayEntry { return todayEntry.weight }
        return previousEntry?.weight
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func refresh() {
        let today = Calendar.current.startOfDay(for: Date())

        // Fetch today's entry
        var todayDescriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.date == today }
        )
        todayDescriptor.fetchLimit = 1
        todayEntry = try? modelContext.fetch(todayDescriptor).first

        // Fetch most recent entry before today
        var previousDescriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.date < today },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        previousDescriptor.fetchLimit = 1
        previousEntry = try? modelContext.fetch(previousDescriptor).first

        // Fetch last 14 days for sparkline
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: today)!
        let recentDescriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.date >= twoWeeksAgo },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        recentWeights = (try? modelContext.fetch(recentDescriptor)) ?? []
    }
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
xcodebuild test -project Baseline.xcodeproj -scheme BaselineTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(Passed|Failed)" | tail -5
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add Baseline/ViewModels/TodayViewModel.swift BaselineTests/ViewModels/TodayViewModelTests.swift
git commit -m "feat: add TodayViewModel with delta calculation and sparkline data"
```

---

### Task 8: Today Screen UI [DESIGN GATE]

**Files:**
- Create: `Baseline/Views/Today/TodayView.swift`
- Create: `Baseline/Design/Components/SparklineView.swift`
- Modify: `Baseline/Views/Navigation/MainTabView.swift` — replace TodayPlaceholder

**DESIGN GATE:** Before implementing this task, create a high-fidelity mockup of the Today screen showing:
- Today's weight (large number), unit label, delta from last entry
- Mini sparkline of recent weights
- "Weigh In" button (primary action)
- Settings gear icon (top-left), History list icon (top-right)
- Overall dark theme with Cadre design tokens

Get user approval on the mockup. Then implement to match.

- [ ] **Step 1: Create SparklineView component**

Create `Baseline/Design/Components/SparklineView.swift`:

```swift
import SwiftUI
import Charts

struct SparklineView: View {
    let weights: [WeightEntry]

    var body: some View {
        if weights.count >= 2 {
            Chart(weights, id: \.id) { entry in
                LineMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", entry.weight)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(CadreColors.chartLine)

                AreaMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", entry.weight)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(CadreColors.chartFill)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: .automatic(includesZero: false))
        } else {
            Text("Not enough data")
                .font(CadreTypography.caption)
                .foregroundStyle(CadreColors.textTertiary)
        }
    }
}
```

- [ ] **Step 2: Create TodayView**

Create `Baseline/Views/Today/TodayView.swift`:

```swift
import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var vm: TodayViewModel?
    @State private var showWeighIn = false
    @State private var showSettings = false
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            ZStack {
                CadreColors.bg.ignoresSafeArea()

                VStack(spacing: CadreSpacing.lg) {
                    Spacer()

                    // Weight display
                    if let entry = vm?.todayEntry {
                        weightDisplay(weight: entry.weight, unit: entry.unit)
                    } else if let last = vm?.lastWeight {
                        // No entry today — show last weight dimmed
                        weightDisplay(weight: last, unit: UserDefaults.standard.string(forKey: "weightUnit") ?? "lb", dimmed: true)
                        Text("No entry today")
                            .font(CadreTypography.subheadline)
                            .foregroundStyle(CadreColors.textTertiary)
                    } else {
                        Text("No data yet")
                            .font(CadreTypography.headline)
                            .foregroundStyle(CadreColors.textSecondary)
                    }

                    // Delta
                    if let delta = vm?.delta {
                        deltaLabel(delta)
                    }

                    // Sparkline
                    if let weights = vm?.recentWeights, weights.count >= 2 {
                        SparklineView(weights: weights)
                            .frame(height: 60)
                            .padding(.horizontal, CadreSpacing.lg)
                    }

                    Spacer()

                    // Weigh In button
                    Button {
                        showWeighIn = true
                    } label: {
                        Text("Weigh In")
                            .font(CadreTypography.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, CadreSpacing.md)
                            .background(CadreColors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: CadreRadius.lg))
                    }
                    .padding(.horizontal, CadreSpacing.xl)
                    .padding(.bottom, CadreSpacing.lg)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(CadreColors.textSecondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showHistory = true } label: {
                        Image(systemName: "list.bullet")
                            .foregroundStyle(CadreColors.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showWeighIn) {
                // WeighInSheet will be implemented in Task 10
                Text("Weigh In Sheet")
                    .presentationDetents([.medium])
            }
            .navigationDestination(isPresented: $showSettings) {
                Text("Settings") // Replaced in Task 18
            }
            .navigationDestination(isPresented: $showHistory) {
                Text("History") // Replaced in Task 11
            }
            .onAppear {
                if vm == nil {
                    vm = TodayViewModel(modelContext: modelContext)
                }
                vm?.refresh()
            }
        }
    }

    private func weightDisplay(weight: Double, unit: String, dimmed: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: CadreSpacing.xs) {
            Text(UnitConversion.formatWeight(weight, unit: unit))
                .font(CadreTypography.weightDisplay)
                .foregroundStyle(dimmed ? CadreColors.textTertiary : CadreColors.textPrimary)
            Text(unit)
                .font(CadreTypography.weightUnit)
                .foregroundStyle(CadreColors.textSecondary)
        }
    }

    private func deltaLabel(_ delta: Double) -> some View {
        let color = delta > 0 ? CadreColors.negative :
                    delta < 0 ? CadreColors.positive :
                    CadreColors.neutral
        return Text(UnitConversion.formatDelta(delta))
            .font(CadreTypography.deltaDisplay)
            .foregroundStyle(color)
    }
}

#Preview {
    TodayView()
        .modelContainer(for: [WeightEntry.self, InBodyScan.self, BodyMeasurement.self, SyncState.self], inMemory: true)
}
```

- [ ] **Step 3: Update MainTabView to use TodayView**

In `MainTabView.swift`, replace `TodayPlaceholder()` with `TodayView()` in the TabView body. Remove the `TodayPlaceholder` struct.

- [ ] **Step 4: Build and verify**

```bash
xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Baseline/Views/Today/ Baseline/Design/Components/SparklineView.swift Baseline/Views/Navigation/MainTabView.swift
git commit -m "feat: add Today screen with weight display, delta, sparkline, and Weigh In button"
```

---

### Task 9: WeighInViewModel + Tests

**Files:**
- Create: `Baseline/ViewModels/WeighInViewModel.swift`
- Create: `BaselineTests/ViewModels/WeighInViewModelTests.swift`

- [ ] **Step 1: Write failing tests**

Create `BaselineTests/ViewModels/WeighInViewModelTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Baseline

final class WeighInViewModelTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([WeightEntry.self, InBodyScan.self, BodyMeasurement.self, SyncState.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    func testDefaultsToLastWeight() {
        let vm = WeighInViewModel(modelContext: context, lastWeight: 197.4, unit: "lb")
        XCTAssertEqual(vm.currentWeight, 197.4)
    }

    func testDefaultsTo150WhenNoHistory() {
        let vm = WeighInViewModel(modelContext: context, lastWeight: nil, unit: "lb")
        XCTAssertEqual(vm.currentWeight, 150.0)
    }

    func testIncrementByStepSize() {
        let vm = WeighInViewModel(modelContext: context, lastWeight: 197.4, unit: "lb")
        vm.stepSize = 0.1
        vm.increment()
        XCTAssertEqual(vm.currentWeight, 197.5, accuracy: 0.01)
    }

    func testDecrementByStepSize() {
        let vm = WeighInViewModel(modelContext: context, lastWeight: 197.4, unit: "lb")
        vm.stepSize = 0.5
        vm.decrement()
        XCTAssertEqual(vm.currentWeight, 196.9, accuracy: 0.01)
    }

    func testToggleStepSize() {
        let vm = WeighInViewModel(modelContext: context, lastWeight: 197.4, unit: "lb")
        XCTAssertEqual(vm.stepSize, 0.1)
        vm.cycleStepSize()
        XCTAssertEqual(vm.stepSize, 0.5)
        vm.cycleStepSize()
        XCTAssertEqual(vm.stepSize, 1.0)
        vm.cycleStepSize()
        XCTAssertEqual(vm.stepSize, 0.1)
    }

    func testSaveCreatesNewEntry() {
        let vm = WeighInViewModel(modelContext: context, lastWeight: 197.4, unit: "lb")
        vm.currentWeight = 198.0
        vm.save()

        let descriptor = FetchDescriptor<WeightEntry>()
        let entries = try! context.fetch(descriptor)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.weight, 198.0)
    }

    func testSaveUpdatesExistingTodayEntry() {
        // Pre-existing entry for today
        let existing = WeightEntry(weight: 197.4, date: Date())
        context.insert(existing)
        try! context.save()

        let vm = WeighInViewModel(modelContext: context, lastWeight: 197.4, unit: "lb")
        vm.currentWeight = 198.0
        vm.save()

        let descriptor = FetchDescriptor<WeightEntry>()
        let entries = try! context.fetch(descriptor)
        XCTAssertEqual(entries.count, 1, "Should update existing, not create duplicate")
        XCTAssertEqual(entries.first?.weight, 198.0)
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

Expected: Compilation error — `WeighInViewModel` not found.

- [ ] **Step 3: Implement WeighInViewModel**

Create `Baseline/ViewModels/WeighInViewModel.swift`:

```swift
import Foundation
import SwiftData
import Observation

@Observable
class WeighInViewModel {
    private let modelContext: ModelContext
    let unit: String

    var currentWeight: Double
    var stepSize: Double = 0.1

    private let stepSizes: [Double] = [0.1, 0.5, 1.0]

    init(modelContext: ModelContext, lastWeight: Double?, unit: String) {
        self.modelContext = modelContext
        self.unit = unit
        self.currentWeight = lastWeight ?? (unit == "kg" ? 70.0 : 150.0)
    }

    func increment() {
        currentWeight = (currentWeight + stepSize).rounded(toPlaces: 1)
    }

    func decrement() {
        currentWeight = (currentWeight - stepSize).rounded(toPlaces: 1)
    }

    func cycleStepSize() {
        guard let currentIndex = stepSizes.firstIndex(of: stepSize) else {
            stepSize = stepSizes[0]
            return
        }
        let nextIndex = (currentIndex + 1) % stepSizes.count
        stepSize = stepSizes[nextIndex]
    }

    func save() {
        let today = Calendar.current.startOfDay(for: Date())

        // Check for existing entry today
        var descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.date == today }
        )
        descriptor.fetchLimit = 1

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.weight = currentWeight
            existing.updatedAt = Date()
        } else {
            let entry = WeightEntry(weight: currentWeight, unit: unit, date: Date())
            modelContext.insert(entry)
        }

        try? modelContext.save()

        // Trigger sync after saving weight
        if let container = modelContext.container {
            SyncHelper.triggerSync(modelContainer: container)
        }
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
xcodebuild test -project Baseline.xcodeproj -scheme BaselineTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(Passed|Failed)" | tail -5
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add Baseline/ViewModels/WeighInViewModel.swift BaselineTests/ViewModels/WeighInViewModelTests.swift
git commit -m "feat: add WeighInViewModel with stepper, step-size toggle, save/update"
```

---

### Task 10: WeighIn Sheet UI [DESIGN GATE]

**Files:**
- Create: `Baseline/Views/Today/WeighInSheet.swift`
- Modify: `Baseline/Views/Today/TodayView.swift` — wire up sheet

**DESIGN GATE:** Before implementing, create a mockup of the WeighIn sheet:
- Weight display (large number, current value)
- +/- stepper buttons
- Step-size toggle (0.1 / 0.5 / 1.0)
- Save button
- Date label (today)

The input method (stepper vs arc vs hybrid) is resolved here. Start with stepper. If the mockup exploration leads to arc/hybrid, adjust the implementation.

- [ ] **Step 1: Implement WeighInSheet**

Create `Baseline/Views/Today/WeighInSheet.swift`:

```swift
import SwiftUI
import SwiftData

struct WeighInSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var vm: WeighInViewModel?

    let lastWeight: Double?
    let unit: String
    var onSave: (() -> Void)?

    var body: some View {
        ZStack {
            CadreColors.bg.ignoresSafeArea()

            VStack(spacing: CadreSpacing.xl) {
                // Date
                Text(DateFormatting.fullDate(Date()))
                    .font(CadreTypography.subheadline)
                    .foregroundStyle(CadreColors.textSecondary)
                    .padding(.top, CadreSpacing.lg)

                Spacer()

                // Weight display
                HStack(alignment: .firstTextBaseline, spacing: CadreSpacing.xs) {
                    Text(UnitConversion.formatWeight(vm?.currentWeight ?? 0, unit: unit))
                        .font(CadreTypography.weightDisplay)
                        .foregroundStyle(CadreColors.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.15), value: vm?.currentWeight)
                    Text(unit)
                        .font(CadreTypography.weightUnit)
                        .foregroundStyle(CadreColors.textSecondary)
                }

                // Stepper controls
                HStack(spacing: CadreSpacing.xl) {
                    // Decrement
                    Button {
                        vm?.decrement()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(CadreColors.accent)
                    }
                    .buttonRepeatBehavior(.enabled)

                    // Step size toggle
                    Button {
                        vm?.cycleStepSize()
                    } label: {
                        Text("±\(String(format: vm?.stepSize == 1.0 ? "%.0f" : "%.1f", vm?.stepSize ?? 0.1))")
                            .font(CadreTypography.callout)
                            .foregroundStyle(CadreColors.textSecondary)
                            .padding(.horizontal, CadreSpacing.md)
                            .padding(.vertical, CadreSpacing.sm)
                            .background(CadreColors.card)
                            .clipShape(Capsule())
                    }

                    // Increment
                    Button {
                        vm?.increment()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(CadreColors.accent)
                    }
                    .buttonRepeatBehavior(.enabled)
                }

                Spacer()

                // Save button
                Button {
                    vm?.save()
                    onSave?()
                    dismiss()
                } label: {
                    Text("Save")
                        .font(CadreTypography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CadreSpacing.md)
                        .background(CadreColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: CadreRadius.lg))
                }
                .padding(.horizontal, CadreSpacing.xl)
                .padding(.bottom, CadreSpacing.lg)
            }
        }
        .onAppear {
            if vm == nil {
                vm = WeighInViewModel(modelContext: modelContext, lastWeight: lastWeight, unit: unit)
            }
        }
    }
}

#Preview {
    WeighInSheet(lastWeight: 197.4, unit: "lb")
        .modelContainer(for: [WeightEntry.self, InBodyScan.self, BodyMeasurement.self, SyncState.self], inMemory: true)
}
```

- [ ] **Step 2: Wire WeighInSheet into TodayView**

In `TodayView.swift`, replace the `.sheet(isPresented: $showWeighIn)` content:

```swift
.sheet(isPresented: $showWeighIn) {
    WeighInSheet(
        lastWeight: vm?.lastWeight,
        unit: UserDefaults.standard.string(forKey: "weightUnit") ?? "lb"
    ) {
        vm?.refresh()
    }
    .presentationDetents([.medium])
}
```

- [ ] **Step 3: Build and test in simulator**

```bash
xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED. Tapping "Weigh In" opens the sheet with stepper controls.

- [ ] **Step 4: Commit**

```bash
git add Baseline/Views/Today/WeighInSheet.swift Baseline/Views/Today/TodayView.swift
git commit -m "feat: add WeighIn sheet with stepper input, step-size toggle, save"
```

---

### Task 11: HistoryViewModel + History Screen

**Files:**
- Create: `Baseline/ViewModels/HistoryViewModel.swift`
- Create: `BaselineTests/ViewModels/HistoryViewModelTests.swift`
- Create: `Baseline/Views/History/HistoryView.swift`
- Modify: `Baseline/Views/Today/TodayView.swift` — wire up navigation

- [ ] **Step 1: Write failing tests**

Create `BaselineTests/ViewModels/HistoryViewModelTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Baseline

final class HistoryViewModelTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([WeightEntry.self, InBodyScan.self, BodyMeasurement.self, SyncState.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    func testEntriesSortedNewestFirst() {
        for i in 0..<5 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            context.insert(WeightEntry(weight: 195.0 + Double(i), date: date))
        }
        try! context.save()

        let vm = HistoryViewModel(modelContext: context)
        vm.refresh()
        XCTAssertEqual(vm.entries.count, 5)
        XCTAssertEqual(vm.entries.first?.weight, 195.0) // today = 195.0
    }

    func testDeltaBetweenConsecutiveEntries() {
        let today = WeightEntry(weight: 197.6, date: Date())
        let yesterday = WeightEntry(weight: 197.0, date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        context.insert(today)
        context.insert(yesterday)
        try! context.save()

        let vm = HistoryViewModel(modelContext: context)
        vm.refresh()
        let delta = vm.delta(for: vm.entries[0])
        XCTAssertEqual(delta, 0.6, accuracy: 0.01)
    }

    func testDeleteEntry() {
        let entry = WeightEntry(weight: 197.4, date: Date())
        context.insert(entry)
        try! context.save()

        let vm = HistoryViewModel(modelContext: context)
        vm.refresh()
        XCTAssertEqual(vm.entries.count, 1)

        vm.delete(entry)
        vm.refresh()
        XCTAssertEqual(vm.entries.count, 0)
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

Expected: Compilation error — `HistoryViewModel` not found.

- [ ] **Step 3: Implement HistoryViewModel**

Create `Baseline/ViewModels/HistoryViewModel.swift`:

```swift
import Foundation
import SwiftData
import Observation

@Observable
class HistoryViewModel {
    private let modelContext: ModelContext

    var entries: [WeightEntry] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func refresh() {
        let descriptor = FetchDescriptor<WeightEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        entries = (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Delta from the previous entry (entry at index+1 in the sorted array)
    func delta(for entry: WeightEntry) -> Double? {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }),
              index + 1 < entries.count else { return nil }
        return entry.weight - entries[index + 1].weight
    }

    func delete(_ entry: WeightEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
    }

    func update(_ entry: WeightEntry, weight: Double, notes: String?) {
        entry.weight = weight
        entry.notes = notes
        entry.updatedAt = Date()
        try? modelContext.save()
    }
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
xcodebuild test -project Baseline.xcodeproj -scheme BaselineTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(Passed|Failed)" | tail -5
```

Expected: All tests pass.

- [ ] **Step 5: Implement HistoryView**

Create `Baseline/Views/History/HistoryView.swift`:

```swift
import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var vm: HistoryViewModel?
    @State private var editingEntry: WeightEntry?
    @State private var editWeight: String = ""
    @State private var editNotes: String = ""

    var body: some View {
        ZStack {
            CadreColors.bg.ignoresSafeArea()

            if let vm, !vm.entries.isEmpty {
                List {
                    ForEach(vm.entries, id: \.id) { entry in
                        historyRow(entry)
                            .listRowBackground(CadreColors.card)
                            .onTapGesture {
                                editWeight = String(format: "%.1f", entry.weight)
                                editNotes = entry.notes ?? ""
                                editingEntry = entry
                            }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            vm.delete(vm.entries[index])
                        }
                        vm.refresh()
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            } else {
                Text("No entries yet")
                    .font(CadreTypography.body)
                    .foregroundStyle(CadreColors.textTertiary)
            }
        }
        .navigationTitle("History")
        .onAppear {
            if vm == nil {
                vm = HistoryViewModel(modelContext: modelContext)
            }
            vm?.refresh()
        }
        .sheet(item: $editingEntry) { entry in
            NavigationStack {
                Form {
                    Section("Weight") {
                        TextField("Weight", text: $editWeight)
                            .keyboardType(.decimalPad)
                    }
                    Section("Notes") {
                        TextField("Notes", text: $editNotes)
                    }
                }
                .navigationTitle("Edit Entry")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { editingEntry = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if let newWeight = Double(editWeight) {
                                vm?.update(entry, weight: newWeight, notes: editNotes.isEmpty ? nil : editNotes)
                                vm?.refresh()
                            }
                            editingEntry = nil
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func historyRow(_ entry: WeightEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: CadreSpacing.xs) {
                Text(DateFormatting.fullDate(entry.date))
                    .font(CadreTypography.subheadline)
                    .foregroundStyle(CadreColors.textSecondary)
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(CadreTypography.caption)
                        .foregroundStyle(CadreColors.textTertiary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: CadreSpacing.xs) {
                Text("\(UnitConversion.formatWeight(entry.weight, unit: entry.unit)) \(entry.unit)")
                    .font(CadreTypography.headline)
                    .foregroundStyle(CadreColors.textPrimary)
                if let delta = vm?.delta(for: entry) {
                    let color = delta > 0 ? CadreColors.negative :
                                delta < 0 ? CadreColors.positive : CadreColors.neutral
                    Text(UnitConversion.formatDelta(delta))
                        .font(CadreTypography.caption)
                        .foregroundStyle(color)
                }
            }
        }
        .padding(.vertical, CadreSpacing.xs)
    }
}
```

- [ ] **Step 6: Wire HistoryView into TodayView**

In `TodayView.swift`, replace the `.navigationDestination(isPresented: $showHistory)` content:

```swift
.navigationDestination(isPresented: $showHistory) {
    HistoryView()
}
```

- [ ] **Step 7: Build and verify**

```bash
xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED

- [ ] **Step 8: Commit**

```bash
git add Baseline/ViewModels/HistoryViewModel.swift BaselineTests/ViewModels/HistoryViewModelTests.swift Baseline/Views/History/HistoryView.swift Baseline/Views/Today/TodayView.swift
git commit -m "feat: add History screen with sorted entries, deltas, swipe-to-delete"
```

---

## Phase 3: Trends

### Task 12: TrendsViewModel + Tests

**Files:**
- Create: `Baseline/ViewModels/TrendsViewModel.swift`
- Create: `BaselineTests/ViewModels/TrendsViewModelTests.swift`

- [ ] **Step 1: Write failing tests**

Create `BaselineTests/ViewModels/TrendsViewModelTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Baseline

final class TrendsViewModelTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([WeightEntry.self, InBodyScan.self, BodyMeasurement.self, SyncState.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    func testTimeRangeFiltering() {
        // Insert 100 days of data
        for i in 0..<100 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            context.insert(WeightEntry(weight: 195.0 + sin(Double(i) * 0.1) * 3, date: date))
        }
        try! context.save()

        let vm = TrendsViewModel(modelContext: context)

        vm.timeRange = .week
        vm.refresh()
        XCTAssertEqual(vm.entries.count, 7)

        vm.timeRange = .month
        vm.refresh()
        XCTAssertEqual(vm.entries.count, 30)

        vm.timeRange = .threeMonths
        vm.refresh()
        XCTAssertEqual(vm.entries.count, 90)

        vm.timeRange = .year
        vm.refresh()
        XCTAssertEqual(vm.entries.count, 100) // only 100 days of data
    }

    func testMovingAverage7Day() {
        // Insert 14 days of data with a known pattern
        for i in 0..<14 {
            let date = Calendar.current.date(byAdding: .day, value: -(13 - i), to: Date())!
            // Alternating: 196, 198, 196, 198...
            let weight = i % 2 == 0 ? 196.0 : 198.0
            context.insert(WeightEntry(weight: weight, date: date))
        }
        try! context.save()

        let vm = TrendsViewModel(modelContext: context)
        vm.timeRange = .month
        vm.refresh()

        let ma = vm.movingAverage
        // After 7 days, the moving average should be ~197.0 (mean of alternating 196,198)
        XCTAssertFalse(ma.isEmpty)
        // The 7th point onward should be close to 197
        if ma.count >= 7 {
            XCTAssertEqual(ma[6].value, 197.0, accuracy: 0.1)
        }
    }

    func testWeightRange() {
        context.insert(WeightEntry(weight: 195.0, date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!))
        context.insert(WeightEntry(weight: 200.0, date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!))
        context.insert(WeightEntry(weight: 197.0, date: Date()))
        try! context.save()

        let vm = TrendsViewModel(modelContext: context)
        vm.timeRange = .week
        vm.refresh()
        XCTAssertEqual(vm.minWeight, 195.0)
        XCTAssertEqual(vm.maxWeight, 200.0)
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

Expected: Compilation error — `TrendsViewModel` not found.

- [ ] **Step 3: Implement TrendsViewModel**

Create `Baseline/ViewModels/TrendsViewModel.swift`:

```swift
import Foundation
import SwiftData
import Observation

enum TimeRange: String, CaseIterable {
    case week = "W"
    case month = "M"
    case threeMonths = "3M"
    case year = "Y"

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        case .year: return 365
        }
    }
}

struct MovingAveragePoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

@Observable
class TrendsViewModel {
    private let modelContext: ModelContext

    var timeRange: TimeRange = .month
    var entries: [WeightEntry] = []
    var movingAverage: [MovingAveragePoint] = []

    var minWeight: Double { entries.map(\.weight).min() ?? 0 }
    var maxWeight: Double { entries.map(\.weight).max() ?? 0 }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func refresh() {
        let today = Calendar.current.startOfDay(for: Date())
        let startDate = Calendar.current.date(byAdding: .day, value: -timeRange.days, to: today)!

        let descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.date >= startDate },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        entries = (try? modelContext.fetch(descriptor)) ?? []
        calculateMovingAverage()
    }

    private func calculateMovingAverage() {
        let window = 7
        guard entries.count >= window else {
            movingAverage = []
            return
        }

        var result: [MovingAveragePoint] = []
        for i in (window - 1)..<entries.count {
            let windowSlice = entries[(i - window + 1)...i]
            let avg = windowSlice.map(\.weight).reduce(0, +) / Double(window)
            result.append(MovingAveragePoint(date: entries[i].date, value: avg))
        }
        movingAverage = result
    }
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
xcodebuild test -project Baseline.xcodeproj -scheme BaselineTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(Passed|Failed)" | tail -5
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add Baseline/ViewModels/TrendsViewModel.swift BaselineTests/ViewModels/TrendsViewModelTests.swift
git commit -m "feat: add TrendsViewModel with time range filtering and 7-day moving average"
```

---

### Task 13: Trends Chart UI [DESIGN GATE]

**Files:**
- Create: `Baseline/Views/Trends/TrendsView.swift`
- Modify: `Baseline/Views/Navigation/MainTabView.swift` — replace TrendsPlaceholder

**DESIGN GATE:** Before implementing, create a mockup showing:
- Time range tabs (W / M / 3M / Y)
- Weight line chart with data points
- 7-day moving average as a second line (different color)
- Body comp markers at InBody scan dates (optional — validate in mockup)
- Interactive crosshair on tap/drag

- [ ] **Step 1: Implement TrendsView**

Create `Baseline/Views/Trends/TrendsView.swift`:

```swift
import SwiftUI
import SwiftData
import Charts

struct TrendsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var vm: TrendsViewModel?
    @State private var selectedEntry: WeightEntry?

    var body: some View {
        NavigationStack {
            ZStack {
                CadreColors.bg.ignoresSafeArea()

                VStack(spacing: CadreSpacing.md) {
                    // Time range picker
                    Picker("Range", selection: Binding(
                        get: { vm?.timeRange ?? .month },
                        set: { vm?.timeRange = $0; vm?.refresh() }
                    )) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, CadreSpacing.lg)
                    .padding(.top, CadreSpacing.md)

                    // Chart
                    if let vm, !vm.entries.isEmpty {
                        Chart {
                            // Raw weight line
                            ForEach(vm.entries, id: \.id) { entry in
                                LineMark(
                                    x: .value("Date", entry.date),
                                    y: .value("Weight", entry.weight)
                                )
                                .foregroundStyle(CadreColors.chartLine)
                                .interpolationMethod(.catmullRom)

                                PointMark(
                                    x: .value("Date", entry.date),
                                    y: .value("Weight", entry.weight)
                                )
                                .foregroundStyle(CadreColors.chartLine)
                                .symbolSize(20)
                            }

                            // Moving average line
                            ForEach(vm.movingAverage) { point in
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("MA", point.value),
                                    series: .value("Series", "Moving Avg")
                                )
                                .foregroundStyle(CadreColors.chartMovingAverage)
                                .interpolationMethod(.catmullRom)
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                            }
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .chartXAxis {
                            AxisMarks(values: .automatic) { _ in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                    .foregroundStyle(CadreColors.chartGrid)
                                AxisValueLabel()
                                    .foregroundStyle(CadreColors.textTertiary)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { _ in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                    .foregroundStyle(CadreColors.chartGrid)
                                AxisValueLabel()
                                    .foregroundStyle(CadreColors.textTertiary)
                            }
                        }
                        .chartOverlay { proxy in
                            GeometryReader { geometry in
                                Rectangle()
                                    .fill(.clear)
                                    .contentShape(Rectangle())
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                let x = value.location.x
                                                if let date: Date = proxy.value(atX: x) {
                                                    selectedEntry = vm.entries.min(by: {
                                                        abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                                    })
                                                }
                                            }
                                            .onEnded { _ in
                                                selectedEntry = nil
                                            }
                                    )
                            }
                        }
                        .frame(height: 300)
                        .padding(.horizontal, CadreSpacing.lg)

                        // Selected point info
                        if let selected = selectedEntry {
                            HStack {
                                Text(DateFormatting.fullDate(selected.date))
                                    .font(CadreTypography.subheadline)
                                    .foregroundStyle(CadreColors.textSecondary)
                                Spacer()
                                Text("\(UnitConversion.formatWeight(selected.weight, unit: selected.unit)) \(selected.unit)")
                                    .font(CadreTypography.headline)
                                    .foregroundStyle(CadreColors.textPrimary)
                            }
                            .padding(.horizontal, CadreSpacing.lg)
                        }
                    } else {
                        Spacer()
                        Text("No data for this range")
                            .font(CadreTypography.body)
                            .foregroundStyle(CadreColors.textTertiary)
                    }

                    Spacer()
                }
            }
            .navigationTitle("Trends")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            if vm == nil {
                vm = TrendsViewModel(modelContext: modelContext)
            }
            vm?.refresh()
        }
    }
}
```

- [ ] **Step 2: Update MainTabView — replace TrendsPlaceholder**

In `MainTabView.swift`, replace `TrendsPlaceholder()` with `TrendsView()`. Remove the `TrendsPlaceholder` struct.

- [ ] **Step 3: Build and verify**

```bash
xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Baseline/Views/Trends/TrendsView.swift Baseline/Views/Navigation/MainTabView.swift
git commit -m "feat: add Trends chart with time ranges, moving average, interactive crosshair"
```

---

## Phase 4: Body Measurements

### Task 14: BodyViewModel + Tests

**Files:**
- Create: `Baseline/ViewModels/BodyViewModel.swift`
- Create: `BaselineTests/ViewModels/BodyViewModelTests.swift`

- [ ] **Step 1: Write failing tests**

Create `BaselineTests/ViewModels/BodyViewModelTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Baseline

final class BodyViewModelTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([WeightEntry.self, InBodyScan.self, BodyMeasurement.self, SyncState.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    func testLatestMeasurementsByType() {
        // Two waist measurements — should only show the latest
        let older = BodyMeasurement(date: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
                                     type: .waist, value: 34.0, source: .manual)
        let newer = BodyMeasurement(date: Date(), type: .waist, value: 33.5, source: .manual)
        context.insert(older)
        context.insert(newer)
        try! context.save()

        let vm = BodyViewModel(modelContext: context)
        vm.refresh()

        let waist = vm.latestMeasurements.first(where: { $0.type == MeasurementType.waist.rawValue })
        XCTAssertEqual(waist?.value, 33.5)
    }

    func testRecentScans() {
        let scan = InBodyScan(date: Date(), weight: 197.4)
        scan.bodyFatPercentage = 18.5
        context.insert(scan)
        try! context.save()

        let vm = BodyViewModel(modelContext: context)
        vm.refresh()
        XCTAssertEqual(vm.recentScans.count, 1)
        XCTAssertEqual(vm.recentScans.first?.bodyFatPercentage, 18.5)
    }

    func testSaveMeasurement() {
        let vm = BodyViewModel(modelContext: context)
        vm.saveMeasurement(type: .neck, value: 16.0, unit: "in")

        let descriptor = FetchDescriptor<BodyMeasurement>()
        let results = try! context.fetch(descriptor)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.type, MeasurementType.neck.rawValue)
        XCTAssertEqual(results.first?.value, 16.0)
    }

    func testSaveScanCreatesBodyMeasurements() {
        let vm = BodyViewModel(modelContext: context)

        let scan = InBodyScan(date: Date(), weight: 197.4)
        scan.bodyFatPercentage = 18.5
        scan.skeletalMuscleMass = 85.0

        vm.saveScan(scan)

        let scanDescriptor = FetchDescriptor<InBodyScan>()
        let scans = try! context.fetch(scanDescriptor)
        XCTAssertEqual(scans.count, 1)

        // Should also create BodyMeasurement records from the scan
        let measurementDescriptor = FetchDescriptor<BodyMeasurement>(
            predicate: #Predicate { $0.source == "inbody" }
        )
        let measurements = try! context.fetch(measurementDescriptor)
        XCTAssertEqual(measurements.count, 2) // bodyFatPercentage + skeletalMuscleMass
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

Expected: Compilation error — `BodyViewModel` not found.

- [ ] **Step 3: Implement BodyViewModel**

Create `Baseline/ViewModels/BodyViewModel.swift`:

```swift
import Foundation
import SwiftData
import Observation

@Observable
class BodyViewModel {
    private let modelContext: ModelContext

    var latestMeasurements: [BodyMeasurement] = []
    var recentScans: [InBodyScan] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func refresh() {
        loadLatestMeasurements()
        loadRecentScans()
    }

    private func loadLatestMeasurements() {
        let descriptor = FetchDescriptor<BodyMeasurement>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []

        // Keep only the most recent of each type
        var seen = Set<String>()
        var latest: [BodyMeasurement] = []
        for m in all {
            if !seen.contains(m.type) {
                seen.insert(m.type)
                latest.append(m)
            }
        }
        latestMeasurements = latest
    }

    private func loadRecentScans() {
        let descriptor = FetchDescriptor<InBodyScan>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        recentScans = (try? modelContext.fetch(descriptor)) ?? []
    }

    func saveMeasurement(type: MeasurementType, value: Double, unit: String? = nil, notes: String? = nil) {
        let measurement = BodyMeasurement(
            date: Date(),
            type: type,
            value: value,
            unit: unit,
            source: .manual,
            notes: notes
        )
        modelContext.insert(measurement)
        try? modelContext.save()

        // Trigger sync after saving measurement
        if let container = modelContext.container {
            SyncHelper.triggerSync(modelContainer: container)
        }
    }

    func saveScan(_ scan: InBodyScan) {
        modelContext.insert(scan)

        // Write individual BodyMeasurement records from scan data
        for measurement in scan.toBodyMeasurements() {
            modelContext.insert(measurement)
        }

        try? modelContext.save()

        // Trigger sync after saving scan
        if let container = modelContext.container {
            SyncHelper.triggerSync(modelContainer: container)
        }
    }
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
xcodebuild test -project Baseline.xcodeproj -scheme BaselineTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(Passed|Failed)" | tail -5
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add Baseline/ViewModels/BodyViewModel.swift BaselineTests/ViewModels/BodyViewModelTests.swift
git commit -m "feat: add BodyViewModel with measurement tracking and scan-to-measurement conversion"
```

---

### Task 15: Body Tab + Log Measurement UI [DESIGN GATE]

**Files:**
- Create: `Baseline/Views/Body/BodyView.swift`
- Create: `Baseline/Views/Body/LogMeasurementSheet.swift`
- Create: `Baseline/Design/Components/StatCard.swift`
- Modify: `Baseline/Views/Navigation/MainTabView.swift` — replace BodyPlaceholder

**DESIGN GATE:** Before implementing, create a mockup showing:
- Latest measurement cards (waist, body fat %, muscle mass, etc.)
- Recent InBody scans list
- "Log Measurement" and "Log Scan" action buttons

- [ ] **Step 1: Create StatCard component**

Create `Baseline/Design/Components/StatCard.swift`:

```swift
import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: CadreSpacing.xs) {
            Text(title)
                .font(CadreTypography.caption)
                .foregroundStyle(CadreColors.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(CadreTypography.headline)
                    .foregroundStyle(CadreColors.textPrimary)
                Text(unit)
                    .font(CadreTypography.caption)
                    .foregroundStyle(CadreColors.textSecondary)
            }
            if let subtitle {
                Text(subtitle)
                    .font(CadreTypography.caption)
                    .foregroundStyle(CadreColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CadreSpacing.md)
        .background(CadreColors.card)
        .clipShape(RoundedRectangle(cornerRadius: CadreRadius.md))
    }
}
```

- [ ] **Step 2: Create BodyView**

Create `Baseline/Views/Body/BodyView.swift`:

```swift
import SwiftUI
import SwiftData

struct BodyView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var vm: BodyViewModel?
    @State private var showLogMeasurement = false
    @State private var showLogScan = false

    var body: some View {
        NavigationStack {
            ZStack {
                CadreColors.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: CadreSpacing.lg) {
                        // Latest measurements grid
                        if let vm, !vm.latestMeasurements.isEmpty {
                            measurementGrid(vm.latestMeasurements)
                        }

                        // Actions
                        HStack(spacing: CadreSpacing.md) {
                            Button { showLogMeasurement = true } label: {
                                Label("Log Measurement", systemImage: "ruler")
                                    .font(CadreTypography.subheadline)
                                    .foregroundStyle(CadreColors.accent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, CadreSpacing.md)
                                    .background(CadreColors.card)
                                    .clipShape(RoundedRectangle(cornerRadius: CadreRadius.md))
                            }

                            Button { showLogScan = true } label: {
                                Label("Log Scan", systemImage: "camera")
                                    .font(CadreTypography.subheadline)
                                    .foregroundStyle(CadreColors.accent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, CadreSpacing.md)
                                    .background(CadreColors.card)
                                    .clipShape(RoundedRectangle(cornerRadius: CadreRadius.md))
                            }
                        }
                        .padding(.horizontal, CadreSpacing.lg)

                        // Recent scans
                        if let vm, !vm.recentScans.isEmpty {
                            VStack(alignment: .leading, spacing: CadreSpacing.sm) {
                                Text("InBody Scans")
                                    .font(CadreTypography.headline)
                                    .foregroundStyle(CadreColors.textPrimary)
                                    .padding(.horizontal, CadreSpacing.lg)

                                ForEach(vm.recentScans, id: \.id) { scan in
                                    NavigationLink {
                                        ScanDetailView(scan: scan)
                                    } label: {
                                        scanRow(scan)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, CadreSpacing.md)
                }
            }
            .navigationTitle("Body")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showLogMeasurement) {
                LogMeasurementSheet {
                    vm?.refresh()
                }
                .presentationDetents([.medium])
            }
            .navigationDestination(isPresented: $showLogScan) {
                LogScanPlaceholder() // Replaced in Task 17
            }
        }
        .onAppear {
            if vm == nil {
                vm = BodyViewModel(modelContext: modelContext)
            }
            vm?.refresh()
        }
    }

    private func measurementGrid(_ measurements: [BodyMeasurement]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: CadreSpacing.md) {
            ForEach(measurements, id: \.id) { m in
                StatCard(
                    title: m.measurementType?.displayName ?? m.type,
                    value: String(format: "%.1f", m.value),
                    unit: m.unit,
                    subtitle: DateFormatting.shortDay(m.date)
                )
            }
        }
        .padding(.horizontal, CadreSpacing.lg)
    }

    private func scanRow(_ scan: InBodyScan) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: CadreSpacing.xs) {
                Text(DateFormatting.fullDate(scan.date))
                    .font(CadreTypography.subheadline)
                    .foregroundStyle(CadreColors.textPrimary)
                if let bf = scan.bodyFatPercentage {
                    Text("Body Fat: \(String(format: "%.1f", bf))%")
                        .font(CadreTypography.caption)
                        .foregroundStyle(CadreColors.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(CadreColors.textTertiary)
        }
        .padding(CadreSpacing.md)
        .background(CadreColors.card)
        .clipShape(RoundedRectangle(cornerRadius: CadreRadius.md))
        .padding(.horizontal, CadreSpacing.lg)
    }
}

// Placeholder until Task 17
private struct LogScanPlaceholder: View {
    var body: some View {
        Text("Log Scan — coming soon")
            .foregroundStyle(CadreColors.textTertiary)
    }
}
```

- [ ] **Step 3: Create LogMeasurementSheet**

Create `Baseline/Views/Body/LogMeasurementSheet.swift`:

```swift
import SwiftUI
import SwiftData

struct LogMeasurementSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: MeasurementType = .waist
    @State private var value: String = ""
    @State private var customName: String = ""
    var onSave: (() -> Void)?

    // Show tape-measure types plus custom in quick entry
    private let tapeMeasureTypes: [MeasurementType] = [
        .waist, .neck, .chest, .rightArm, .leftArm,
        .rightThigh, .leftThigh, .hips, .custom
    ]

    var body: some View {
        ZStack {
            CadreColors.bg.ignoresSafeArea()

            VStack(spacing: CadreSpacing.lg) {
                Text("Log Measurement")
                    .font(CadreTypography.headline)
                    .foregroundStyle(CadreColors.textPrimary)
                    .padding(.top, CadreSpacing.lg)

                // Type picker
                Picker("Type", selection: $selectedType) {
                    ForEach(tapeMeasureTypes, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)

                // Custom measurement name field (shown when "Custom" is selected)
                if selectedType == .custom {
                    TextField("Measurement name", text: $customName)
                        .font(CadreTypography.body)
                        .foregroundStyle(CadreColors.textPrimary)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, CadreSpacing.xl)
                }

                // Value input
                HStack {
                    TextField("Value", text: $value)
                        .keyboardType(.decimalPad)
                        .font(CadreTypography.title)
                        .foregroundStyle(CadreColors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(selectedType.defaultUnit)
                        .font(CadreTypography.headline)
                        .foregroundStyle(CadreColors.textSecondary)
                }
                .padding(.horizontal, CadreSpacing.xl)

                Spacer()

                // Save
                Button {
                    if let doubleValue = Double(value) {
                        let vm = BodyViewModel(modelContext: modelContext)
                        if selectedType == .custom, !customName.isEmpty {
                            // Custom type: save with the user-provided name as the type string.
                            // BodyMeasurement.type is a String, so custom names work naturally.
                            let measurement = BodyMeasurement(
                                date: Date(),
                                type: .custom,
                                value: doubleValue,
                                source: .manual
                            )
                            measurement.type = customName // override rawValue with custom name
                            modelContext.insert(measurement)
                            try? modelContext.save()
                        } else {
                            vm.saveMeasurement(type: selectedType, value: doubleValue)
                        }
                        onSave?()
                        dismiss()
                    }
                } label: {
                    Text("Save")
                        .font(CadreTypography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CadreSpacing.md)
                        .background(value.isEmpty ? CadreColors.textTertiary : CadreColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: CadreRadius.lg))
                }
                .disabled(value.isEmpty)
                .padding(.horizontal, CadreSpacing.xl)
                .padding(.bottom, CadreSpacing.lg)
            }
        }
    }
}
```

- [ ] **Step 4: Create ScanDetailView placeholder**

Create `Baseline/Views/Body/ScanDetailView.swift`:

```swift
import SwiftUI

struct ScanDetailView: View {
    let scan: InBodyScan

    var body: some View {
        ZStack {
            CadreColors.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: CadreSpacing.lg) {
                    // Header
                    VStack(spacing: CadreSpacing.sm) {
                        Text(DateFormatting.fullDate(scan.date))
                            .font(CadreTypography.headline)
                            .foregroundStyle(CadreColors.textPrimary)
                        Text("\(UnitConversion.formatWeight(scan.weight, unit: scan.unit)) \(scan.unit)")
                            .font(CadreTypography.title)
                            .foregroundStyle(CadreColors.textPrimary)
                    }
                    .padding(.top, CadreSpacing.lg)

                    // Key metrics
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: CadreSpacing.md) {
                        if let v = scan.bodyFatPercentage { StatCard(title: "Body Fat", value: String(format: "%.1f", v), unit: "%") }
                        if let v = scan.skeletalMuscleMass { StatCard(title: "Skeletal Muscle", value: String(format: "%.1f", v), unit: scan.unit) }
                        if let v = scan.bodyFatMass { StatCard(title: "Fat Mass", value: String(format: "%.1f", v), unit: scan.unit) }
                        if let v = scan.leanBodyMass { StatCard(title: "Lean Mass", value: String(format: "%.1f", v), unit: scan.unit) }
                        if let v = scan.bmi { StatCard(title: "BMI", value: String(format: "%.1f", v), unit: "") }
                        if let v = scan.totalBodyWater { StatCard(title: "Body Water", value: String(format: "%.1f", v), unit: "L") }
                        if let v = scan.basalMetabolicRate { StatCard(title: "BMR", value: String(format: "%.0f", v), unit: "kcal") }
                        if let v = scan.inBodyScore { StatCard(title: "InBody Score", value: String(format: "%.0f", v), unit: "") }
                    }
                    .padding(.horizontal, CadreSpacing.lg)

                    // Segmental analysis (if any data exists)
                    if scan.rightArmLean != nil || scan.rightArmFat != nil {
                        VStack(alignment: .leading, spacing: CadreSpacing.sm) {
                            Text("Segmental Analysis")
                                .font(CadreTypography.headline)
                                .foregroundStyle(CadreColors.textPrimary)
                                .padding(.horizontal, CadreSpacing.lg)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: CadreSpacing.md) {
                                if let v = scan.rightArmLean { StatCard(title: "R Arm Lean", value: String(format: "%.1f", v), unit: scan.unit) }
                                if let v = scan.leftArmLean { StatCard(title: "L Arm Lean", value: String(format: "%.1f", v), unit: scan.unit) }
                                if let v = scan.trunkLean { StatCard(title: "Trunk Lean", value: String(format: "%.1f", v), unit: scan.unit) }
                                if let v = scan.rightLegLean { StatCard(title: "R Leg Lean", value: String(format: "%.1f", v), unit: scan.unit) }
                                if let v = scan.leftLegLean { StatCard(title: "L Leg Lean", value: String(format: "%.1f", v), unit: scan.unit) }
                                if let v = scan.rightArmFat { StatCard(title: "R Arm Fat", value: String(format: "%.1f", v), unit: scan.unit) }
                                if let v = scan.leftArmFat { StatCard(title: "L Arm Fat", value: String(format: "%.1f", v), unit: scan.unit) }
                                if let v = scan.trunkFat { StatCard(title: "Trunk Fat", value: String(format: "%.1f", v), unit: scan.unit) }
                                if let v = scan.rightLegFat { StatCard(title: "R Leg Fat", value: String(format: "%.1f", v), unit: scan.unit) }
                                if let v = scan.leftLegFat { StatCard(title: "L Leg Fat", value: String(format: "%.1f", v), unit: scan.unit) }
                            }
                            .padding(.horizontal, CadreSpacing.lg)
                        }
                    }
                }
            }
        }
        .navigationTitle("Scan Detail")
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
```

- [ ] **Step 5: Update MainTabView — replace BodyPlaceholder**

In `MainTabView.swift`, replace `BodyPlaceholder()` with `BodyView()`. Remove the `BodyPlaceholder` struct.

- [ ] **Step 6: Build and verify**

```bash
xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add Baseline/Views/Body/ Baseline/Design/Components/StatCard.swift Baseline/Views/Navigation/MainTabView.swift
git commit -m "feat: add Body tab with measurement grid, log measurement sheet, scan detail view"
```

---

### Task 16: InBody OCR Parser + Tests

**Files:**
- Create: `Baseline/OCR/InBodyOCRParser.swift`
- Create: `BaselineTests/OCR/InBodyOCRParserTests.swift`

- [ ] **Step 1: Write failing tests**

Create `BaselineTests/OCR/InBodyOCRParserTests.swift`:

```swift
import XCTest
@testable import Baseline

final class InBodyOCRParserTests: XCTestCase {

    func testParseWeight() {
        let text = """
        Body Composition Analysis
        Weight: 197.4 lbs
        Skeletal Muscle Mass: 85.2 lbs
        Body Fat Mass: 35.6 lbs
        """
        let result = InBodyOCRParser.parse(text)
        XCTAssertEqual(result.weight, 197.4, accuracy: 0.1)
    }

    func testParseBodyFatPercentage() {
        let text = """
        Percent Body Fat
        18.5 %
        """
        let result = InBodyOCRParser.parse(text)
        XCTAssertEqual(result.bodyFatPercentage, 18.5, accuracy: 0.1)
    }

    func testParseSkeletalMuscleMass() {
        let text = """
        Skeletal Muscle Mass
        85.2 lbs
        """
        let result = InBodyOCRParser.parse(text)
        XCTAssertEqual(result.skeletalMuscleMass, 85.2, accuracy: 0.1)
    }

    func testParseBMI() {
        let text = """
        BMI: 25.3
        InBody Score: 78
        """
        let result = InBodyOCRParser.parse(text)
        XCTAssertEqual(result.bmi, 25.3, accuracy: 0.1)
        XCTAssertEqual(result.inBodyScore, 78, accuracy: 0.1)
    }

    func testParseSegmentalLean() {
        let text = """
        Segmental Lean Analysis
        Right Arm: 8.5 lbs
        Left Arm: 8.3 lbs
        Trunk: 52.1 lbs
        Right Leg: 20.4 lbs
        Left Leg: 20.2 lbs
        """
        let result = InBodyOCRParser.parse(text)
        XCTAssertEqual(result.rightArmLean, 8.5, accuracy: 0.1)
        XCTAssertEqual(result.leftArmLean, 8.3, accuracy: 0.1)
        XCTAssertEqual(result.trunkLean, 52.1, accuracy: 0.1)
    }

    func testParseReturnsNilForMissingFields() {
        let text = "Weight: 197.4 lbs"
        let result = InBodyOCRParser.parse(text)
        XCTAssertEqual(result.weight, 197.4, accuracy: 0.1)
        XCTAssertNil(result.bodyFatPercentage)
        XCTAssertNil(result.skeletalMuscleMass)
    }

    func testEmptyTextReturnsAllNil() {
        let result = InBodyOCRParser.parse("")
        XCTAssertNil(result.weight)
        XCTAssertNil(result.bodyFatPercentage)
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

Expected: Compilation error — `InBodyOCRParser` not found.

- [ ] **Step 3: Implement InBodyOCRParser**

Create `Baseline/OCR/InBodyOCRParser.swift`:

```swift
import Foundation
import Vision
import UIKit

struct InBodyParseResult {
    var weight: Double?
    var bodyFatPercentage: Double?
    var skeletalMuscleMass: Double?
    var bodyFatMass: Double?
    var bmi: Double?
    var totalBodyWater: Double?
    var leanBodyMass: Double?
    var basalMetabolicRate: Double?
    var inBodyScore: Double?
    var rightArmLean: Double?
    var leftArmLean: Double?
    var trunkLean: Double?
    var rightLegLean: Double?
    var leftLegLean: Double?
    var rightArmFat: Double?
    var leftArmFat: Double?
    var trunkFat: Double?
    var rightLegFat: Double?
    var leftLegFat: Double?
    var rawText: String = ""
}

enum InBodyOCRParser {

    // MARK: - Text Parsing (from recognized OCR text)

    static func parse(_ text: String) -> InBodyParseResult {
        var result = InBodyParseResult()
        result.rawText = text
        let lines = text.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()

            // Weight
            if lower.contains("weight") && !lower.contains("body fat") {
                result.weight = extractNumber(from: line)
            }

            // Body fat percentage
            if lower.contains("percent body fat") || lower.contains("body fat %") || lower.contains("pbf") {
                result.bodyFatPercentage = extractNumber(from: line) ?? extractNumber(fromNextLine: lines, after: index)
            }

            // Skeletal muscle mass
            if lower.contains("skeletal muscle mass") || lower.contains("smm") {
                result.skeletalMuscleMass = extractNumber(from: line) ?? extractNumber(fromNextLine: lines, after: index)
            }

            // Body fat mass
            if lower.contains("body fat mass") && !lower.contains("percent") {
                result.bodyFatMass = extractNumber(from: line) ?? extractNumber(fromNextLine: lines, after: index)
            }

            // BMI
            if lower.contains("bmi") && !lower.contains("score") {
                result.bmi = extractNumber(from: line)
            }

            // Total body water
            if lower.contains("total body water") || lower.contains("tbw") {
                result.totalBodyWater = extractNumber(from: line) ?? extractNumber(fromNextLine: lines, after: index)
            }

            // Lean body mass
            if lower.contains("lean body mass") || lower.contains("lbm") {
                result.leanBodyMass = extractNumber(from: line) ?? extractNumber(fromNextLine: lines, after: index)
            }

            // BMR
            if lower.contains("basal metabolic rate") || lower.contains("bmr") {
                result.basalMetabolicRate = extractNumber(from: line) ?? extractNumber(fromNextLine: lines, after: index)
            }

            // InBody Score
            if lower.contains("inbody score") {
                result.inBodyScore = extractNumber(from: line) ?? extractNumber(fromNextLine: lines, after: index)
            }

            // Segmental lean
            if lower.contains("segmental lean") {
                parseSegmentalLean(lines: Array(lines.dropFirst(index + 1)), result: &result)
            }

            // Segmental fat
            if lower.contains("segmental fat") {
                parseSegmentalFat(lines: Array(lines.dropFirst(index + 1)), result: &result)
            }
        }

        return result
    }

    // MARK: - Image OCR (Vision framework)

    static func recognizeText(from image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - Helpers

    private static func extractNumber(from text: String) -> Double? {
        let pattern = #"(\d+\.?\d*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return Double(text[range])
    }

    private static func extractNumber(fromNextLine lines: [String], after index: Int) -> Double? {
        guard index + 1 < lines.count else { return nil }
        return extractNumber(from: lines[index + 1])
    }

    private static func parseSegmentalLean(lines: [String], result: inout InBodyParseResult) {
        for line in lines.prefix(5) {
            let lower = line.lowercased()
            if lower.contains("right arm") { result.rightArmLean = extractNumber(from: line) }
            else if lower.contains("left arm") { result.leftArmLean = extractNumber(from: line) }
            else if lower.contains("trunk") { result.trunkLean = extractNumber(from: line) }
            else if lower.contains("right leg") { result.rightLegLean = extractNumber(from: line) }
            else if lower.contains("left leg") { result.leftLegLean = extractNumber(from: line) }
        }
    }

    private static func parseSegmentalFat(lines: [String], result: inout InBodyParseResult) {
        for line in lines.prefix(5) {
            let lower = line.lowercased()
            if lower.contains("right arm") { result.rightArmFat = extractNumber(from: line) }
            else if lower.contains("left arm") { result.leftArmFat = extractNumber(from: line) }
            else if lower.contains("trunk") { result.trunkFat = extractNumber(from: line) }
            else if lower.contains("right leg") { result.rightLegFat = extractNumber(from: line) }
            else if lower.contains("left leg") { result.leftLegFat = extractNumber(from: line) }
        }
    }
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
xcodebuild test -project Baseline.xcodeproj -scheme BaselineTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(Passed|Failed)" | tail -5
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add Baseline/OCR/ BaselineTests/OCR/
git commit -m "feat: add InBody OCR parser with Vision framework and text extraction"
```

---

### Task 17: Scan Entry Flow [DESIGN GATE]

**Files:**
- Create: `Baseline/ViewModels/ScanViewModel.swift`
- Create: `Baseline/Views/Body/LogScanView.swift`
- Modify: `Baseline/Views/Body/BodyView.swift` — wire up navigation

**DESIGN GATE:** Create a mockup of the scan flow:
- Camera viewfinder with guide overlay
- Field review screen showing extracted values with edit capability
- Manual entry fallback form

- [ ] **Step 1: Implement ScanViewModel**

Create `Baseline/ViewModels/ScanViewModel.swift`:

```swift
import Foundation
import SwiftData
import Observation
import UIKit

@Observable
class ScanViewModel {
    private let modelContext: ModelContext

    var parseResult: InBodyParseResult?
    var isProcessing = false
    var showManualEntry = false

    // Editable fields (populated from OCR, user can correct)
    var weight: String = ""
    var bodyFatPercentage: String = ""
    var skeletalMuscleMass: String = ""
    var bodyFatMass: String = ""
    var bmi: String = ""
    var totalBodyWater: String = ""
    var leanBodyMass: String = ""
    var basalMetabolicRate: String = ""
    var inBodyScore: String = ""

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func processImage(_ image: UIImage) async {
        isProcessing = true
        let text = await InBodyOCRParser.recognizeText(from: image)
        let result = InBodyOCRParser.parse(text)
        parseResult = result
        populateFields(from: result)
        isProcessing = false
    }

    private func populateFields(from result: InBodyParseResult) {
        if let v = result.weight { weight = String(format: "%.1f", v) }
        if let v = result.bodyFatPercentage { bodyFatPercentage = String(format: "%.1f", v) }
        if let v = result.skeletalMuscleMass { skeletalMuscleMass = String(format: "%.1f", v) }
        if let v = result.bodyFatMass { bodyFatMass = String(format: "%.1f", v) }
        if let v = result.bmi { bmi = String(format: "%.1f", v) }
        if let v = result.totalBodyWater { totalBodyWater = String(format: "%.1f", v) }
        if let v = result.leanBodyMass { leanBodyMass = String(format: "%.1f", v) }
        if let v = result.basalMetabolicRate { basalMetabolicRate = String(format: "%.0f", v) }
        if let v = result.inBodyScore { inBodyScore = String(format: "%.0f", v) }
    }

    func save() {
        guard let weightValue = Double(weight) else { return }

        let scan = InBodyScan(date: Date(), weight: weightValue)
        scan.bodyFatPercentage = Double(bodyFatPercentage)
        scan.skeletalMuscleMass = Double(skeletalMuscleMass)
        scan.bodyFatMass = Double(bodyFatMass)
        scan.bmi = Double(bmi)
        scan.totalBodyWater = Double(totalBodyWater)
        scan.leanBodyMass = Double(leanBodyMass)
        scan.basalMetabolicRate = Double(basalMetabolicRate)
        scan.inBodyScore = Double(inBodyScore)
        scan.rawOcrText = parseResult?.rawText

        let bodyVM = BodyViewModel(modelContext: modelContext)
        bodyVM.saveScan(scan)
    }
}
```

- [ ] **Step 2: Implement LogScanView**

Create `Baseline/Views/Body/LogScanView.swift`:

```swift
import SwiftUI
import SwiftData

struct LogScanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var vm: ScanViewModel?
    @State private var showCamera = false
    @State private var capturedImage: UIImage?

    var onSave: (() -> Void)?

    var body: some View {
        ZStack {
            CadreColors.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: CadreSpacing.lg) {
                    // Camera / scan button
                    if capturedImage == nil {
                        VStack(spacing: CadreSpacing.md) {
                            Button {
                                showCamera = true
                            } label: {
                                VStack(spacing: CadreSpacing.sm) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 48))
                                    Text("Scan InBody Printout")
                                        .font(CadreTypography.headline)
                                }
                                .foregroundStyle(CadreColors.accent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .background(CadreColors.card)
                                .clipShape(RoundedRectangle(cornerRadius: CadreRadius.lg))
                            }

                            Button("Enter Manually") {
                                vm?.showManualEntry = true
                            }
                            .font(CadreTypography.subheadline)
                            .foregroundStyle(CadreColors.textSecondary)
                        }
                        .padding(.horizontal, CadreSpacing.lg)
                        .padding(.top, CadreSpacing.xl)
                    }

                    // Processing indicator
                    if vm?.isProcessing == true {
                        ProgressView("Scanning...")
                            .foregroundStyle(CadreColors.textSecondary)
                    }

                    // Review / manual entry form
                    if vm?.parseResult != nil || vm?.showManualEntry == true {
                        scanForm
                    }
                }
            }
        }
        .navigationTitle("Log Scan")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showCamera) {
            CameraView { image in
                capturedImage = image
                Task { await vm?.processImage(image) }
            }
        }
        .onAppear {
            if vm == nil {
                vm = ScanViewModel(modelContext: modelContext)
            }
        }
    }

    private var scanForm: some View {
        VStack(spacing: CadreSpacing.md) {
            Text(vm?.parseResult != nil ? "Review & Correct" : "Manual Entry")
                .font(CadreTypography.headline)
                .foregroundStyle(CadreColors.textPrimary)

            scanField("Weight", value: Binding(get: { vm?.weight ?? "" }, set: { vm?.weight = $0 }), unit: "lb")
            scanField("Body Fat %", value: Binding(get: { vm?.bodyFatPercentage ?? "" }, set: { vm?.bodyFatPercentage = $0 }), unit: "%")
            scanField("Skeletal Muscle Mass", value: Binding(get: { vm?.skeletalMuscleMass ?? "" }, set: { vm?.skeletalMuscleMass = $0 }), unit: "lb")
            scanField("Body Fat Mass", value: Binding(get: { vm?.bodyFatMass ?? "" }, set: { vm?.bodyFatMass = $0 }), unit: "lb")
            scanField("BMI", value: Binding(get: { vm?.bmi ?? "" }, set: { vm?.bmi = $0 }), unit: "")
            scanField("Total Body Water", value: Binding(get: { vm?.totalBodyWater ?? "" }, set: { vm?.totalBodyWater = $0 }), unit: "L")
            scanField("Lean Body Mass", value: Binding(get: { vm?.leanBodyMass ?? "" }, set: { vm?.leanBodyMass = $0 }), unit: "lb")
            scanField("BMR", value: Binding(get: { vm?.basalMetabolicRate ?? "" }, set: { vm?.basalMetabolicRate = $0 }), unit: "kcal")
            scanField("InBody Score", value: Binding(get: { vm?.inBodyScore ?? "" }, set: { vm?.inBodyScore = $0 }), unit: "")

            // Save
            Button {
                vm?.save()
                onSave?()
                dismiss()
            } label: {
                Text("Save Scan")
                    .font(CadreTypography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CadreSpacing.md)
                    .background(CadreColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: CadreRadius.lg))
            }
            .padding(.top, CadreSpacing.md)
        }
        .padding(.horizontal, CadreSpacing.lg)
    }

    private func scanField(_ title: String, value: Binding<String>, unit: String) -> some View {
        HStack {
            Text(title)
                .font(CadreTypography.subheadline)
                .foregroundStyle(CadreColors.textSecondary)
                .frame(width: 140, alignment: .leading)
            TextField("—", text: value)
                .keyboardType(.decimalPad)
                .font(CadreTypography.headline)
                .foregroundStyle(CadreColors.textPrimary)
                .multilineTextAlignment(.trailing)
            if !unit.isEmpty {
                Text(unit)
                    .font(CadreTypography.caption)
                    .foregroundStyle(CadreColors.textTertiary)
                    .frame(width: 30, alignment: .leading)
            }
        }
        .padding(CadreSpacing.sm)
        .background(CadreColors.card)
        .clipShape(RoundedRectangle(cornerRadius: CadreRadius.sm))
    }
}

// MARK: - Camera View (UIImagePickerController wrapper)

struct CameraView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
```

- [ ] **Step 3: Wire LogScanView into BodyView**

In `BodyView.swift`, replace the `LogScanPlaceholder` navigation destination:

```swift
.navigationDestination(isPresented: $showLogScan) {
    LogScanView {
        vm?.refresh()
    }
}
```

Remove the `LogScanPlaceholder` struct.

- [ ] **Step 4: Build and verify**

```bash
xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Baseline/ViewModels/ScanViewModel.swift Baseline/Views/Body/LogScanView.swift Baseline/Views/Body/BodyView.swift
git commit -m "feat: add InBody scan entry flow with camera OCR and manual fallback"
```

---

## Phase 5: Infrastructure

### Task 18: Settings Screen

**Files:**
- Create: `Baseline/ViewModels/SettingsViewModel.swift`
- Create: `Baseline/Views/Settings/SettingsView.swift`
- Modify: `Baseline/Views/Today/TodayView.swift` — wire up navigation

- [ ] **Step 1: Implement SettingsViewModel**

Create `Baseline/ViewModels/SettingsViewModel.swift`:

```swift
import Foundation
import Observation

@Observable
class SettingsViewModel {
    var unit: String {
        get { UserDefaults.standard.string(forKey: "weightUnit") ?? "lb" }
        set { UserDefaults.standard.set(newValue, forKey: "weightUnit") }
    }

    var syncApiUrl: String {
        get { UserDefaults.standard.string(forKey: "syncApiUrl") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "syncApiUrl") }
    }

    var syncApiKey: String {
        get { UserDefaults.standard.string(forKey: "syncApiKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "syncApiKey") }
    }

    var isSyncEnabled: Bool {
        !syncApiUrl.isEmpty && !syncApiKey.isEmpty
    }
}
```

- [ ] **Step 2: Implement SettingsView**

Create `Baseline/Views/Settings/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @State private var vm = SettingsViewModel()

    var body: some View {
        ZStack {
            CadreColors.bg.ignoresSafeArea()

            List {
                // Units
                Section("Units") {
                    Picker("Weight Unit", selection: $vm.unit) {
                        Text("Pounds (lb)").tag("lb")
                        Text("Kilograms (kg)").tag("kg")
                    }
                }
                .listRowBackground(CadreColors.card)

                // Sync (developer feature)
                Section {
                    TextField("API URL", text: $vm.syncApiUrl)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("API Key", text: $vm.syncApiKey)
                } header: {
                    Text("D1 Sync")
                } footer: {
                    Text("Push weight and body comp data to your Cadre D1 backend. Leave blank to disable.")
                }
                .listRowBackground(CadreColors.card)

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(CadreColors.textSecondary)
                    }
                    HStack {
                        Text("Ecosystem")
                        Spacer()
                        Text("Cadre")
                            .foregroundStyle(CadreColors.textSecondary)
                    }
                }
                .listRowBackground(CadreColors.card)
            }
            .scrollContentBackground(.hidden)
            .foregroundStyle(CadreColors.textPrimary)
        }
        .navigationTitle("Settings")
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
```

- [ ] **Step 3: Wire SettingsView into TodayView**

In `TodayView.swift`, replace the Settings navigation destination:

```swift
.navigationDestination(isPresented: $showSettings) {
    SettingsView()
}
```

- [ ] **Step 4: Build and verify**

```bash
xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Baseline/ViewModels/SettingsViewModel.swift Baseline/Views/Settings/SettingsView.swift Baseline/Views/Today/TodayView.swift
git commit -m "feat: add Settings screen with unit toggle, D1 sync config, about section"
```

---

### Task 19: CSV Export + Tests

**Files:**
- Create: `Baseline/Utilities/CSVExporter.swift`
- Create: `BaselineTests/Utilities/CSVExporterTests.swift`
- Modify: `Baseline/Views/Settings/SettingsView.swift` — add export button

- [ ] **Step 1: Write failing tests**

Create `BaselineTests/Utilities/CSVExporterTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Baseline

final class CSVExporterTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([WeightEntry.self, InBodyScan.self, BodyMeasurement.self, SyncState.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    func testExportWeightEntries() {
        let entry = WeightEntry(weight: 197.4, unit: "lb", date: Date())
        context.insert(entry)
        try! context.save()

        let csv = CSVExporter.exportWeights(context: context)
        XCTAssertTrue(csv.hasPrefix("date,weight,unit,notes"))
        XCTAssertTrue(csv.contains("197.4"))
        XCTAssertTrue(csv.contains("lb"))
    }

    func testExportBodyMeasurements() {
        let m = BodyMeasurement(date: Date(), type: .waist, value: 33.5, source: .manual)
        context.insert(m)
        try! context.save()

        let csv = CSVExporter.exportMeasurements(context: context)
        XCTAssertTrue(csv.hasPrefix("date,type,value,unit,source"))
        XCTAssertTrue(csv.contains("waist"))
        XCTAssertTrue(csv.contains("33.5"))
    }

    func testExportEmptyReturnsHeaderOnly() {
        let csv = CSVExporter.exportWeights(context: context)
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 1) // header only
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

Expected: Compilation error — `CSVExporter` not found.

- [ ] **Step 3: Implement CSVExporter**

Create `Baseline/Utilities/CSVExporter.swift`:

```swift
import Foundation
import SwiftData

enum CSVExporter {

    static func exportWeights(context: ModelContext) -> String {
        let descriptor = FetchDescriptor<WeightEntry>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let entries = (try? context.fetch(descriptor)) ?? []

        var csv = "date,weight,unit,notes\n"
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        for entry in entries {
            let date = dateFormatter.string(from: entry.date)
            let notes = entry.notes?.replacingOccurrences(of: ",", with: ";") ?? ""
            csv += "\(date),\(entry.weight),\(entry.unit),\(notes)\n"
        }
        return csv
    }

    static func exportMeasurements(context: ModelContext) -> String {
        let descriptor = FetchDescriptor<BodyMeasurement>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let measurements = (try? context.fetch(descriptor)) ?? []

        var csv = "date,type,value,unit,source\n"
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        for m in measurements {
            let date = dateFormatter.string(from: m.date)
            csv += "\(date),\(m.type),\(m.value),\(m.unit),\(m.source)\n"
        }
        return csv
    }

    static func exportScans(context: ModelContext) -> String {
        let descriptor = FetchDescriptor<InBodyScan>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let scans = (try? context.fetch(descriptor)) ?? []

        var csv = "date,weight,body_fat_pct,skeletal_muscle_mass,body_fat_mass,bmi,lean_body_mass,inbody_score\n"
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        for scan in scans {
            let date = dateFormatter.string(from: scan.date)
            let fields = [
                date,
                String(scan.weight),
                scan.bodyFatPercentage.map(String.init) ?? "",
                scan.skeletalMuscleMass.map(String.init) ?? "",
                scan.bodyFatMass.map(String.init) ?? "",
                scan.bmi.map(String.init) ?? "",
                scan.leanBodyMass.map(String.init) ?? "",
                scan.inBodyScore.map(String.init) ?? "",
            ]
            csv += fields.joined(separator: ",") + "\n"
        }
        return csv
    }
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
xcodebuild test -project Baseline.xcodeproj -scheme BaselineTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(Passed|Failed)" | tail -5
```

Expected: All tests pass.

- [ ] **Step 5: Add export button to SettingsView**

In `SettingsView.swift`, add a new section before "About":

```swift
// Data Export
Section("Data") {
    ShareLink("Export Weight Data", item: CSVExporter.exportWeights(context: modelContext))
    ShareLink("Export Measurements", item: CSVExporter.exportMeasurements(context: modelContext))
    ShareLink("Export InBody Scans", item: CSVExporter.exportScans(context: modelContext))
}
.listRowBackground(CadreColors.card)
```

Add `@Environment(\.modelContext) private var modelContext` to SettingsView.

- [ ] **Step 6: Build and verify**

```bash
xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add Baseline/Utilities/CSVExporter.swift BaselineTests/Utilities/CSVExporterTests.swift Baseline/Views/Settings/SettingsView.swift
git commit -m "feat: add CSV export for weights, measurements, and InBody scans"
```

---

### Task 20: HealthKit Manager + Tests

**Files:**
- Create: `Baseline/Health/HealthKitManager.swift`
- Create: `BaselineTests/Health/HealthKitManagerTests.swift`

- [ ] **Step 1: Write failing tests**

Create `BaselineTests/Health/HealthKitManagerTests.swift`:

```swift
import XCTest
import HealthKit
@testable import Baseline

final class HealthKitManagerTests: XCTestCase {

    func testHealthKitTypesAreCorrect() {
        // Verify the quantity types we plan to write are valid
        let types = HealthKitManager.writableTypes
        XCTAssertTrue(types.contains(HKQuantityType(.bodyMass)))
        XCTAssertTrue(types.contains(HKQuantityType(.bodyFatPercentage)))
        XCTAssertTrue(types.contains(HKQuantityType(.leanBodyMass)))
        XCTAssertTrue(types.contains(HKQuantityType(.bodyMassIndex)))
        XCTAssertTrue(types.contains(HKQuantityType(.waistCircumference)))
    }

    func testBuildWeightSample() {
        let date = Date()
        let sample = HealthKitManager.buildWeightSample(weight: 197.4, unit: "lb", date: date)
        XCTAssertNotNil(sample)
        XCTAssertEqual(sample?.quantityType, HKQuantityType(.bodyMass))
        XCTAssertEqual(sample?.startDate, date)
    }

    func testBuildWeightSampleKg() {
        let sample = HealthKitManager.buildWeightSample(weight: 89.5, unit: "kg", date: Date())
        XCTAssertNotNil(sample)
        // Value should be stored in the unit passed
        let kgUnit = HKUnit.gramUnit(with: .kilo)
        XCTAssertEqual(sample?.quantity.doubleValue(for: kgUnit), 89.5, accuracy: 0.1)
    }

    func testBuildBodyFatSample() {
        let sample = HealthKitManager.buildBodyFatSample(percentage: 18.5, date: Date())
        XCTAssertNotNil(sample)
        XCTAssertEqual(sample?.quantityType, HKQuantityType(.bodyFatPercentage))
        // HealthKit expects body fat as a ratio (0.185 for 18.5%)
        let pctUnit = HKUnit.percent()
        XCTAssertEqual(sample?.quantity.doubleValue(for: pctUnit), 0.185, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

Expected: Compilation error — `HealthKitManager` not found.

- [ ] **Step 3: Implement HealthKitManager**

Create `Baseline/Health/HealthKitManager.swift`:

```swift
import Foundation
import HealthKit

enum HealthKitManager {
    private static let store = HKHealthStore()

    static let writableTypes: Set<HKSampleType> = [
        HKQuantityType(.bodyMass),
        HKQuantityType(.bodyFatPercentage),
        HKQuantityType(.leanBodyMass),
        HKQuantityType(.bodyMassIndex),
        HKQuantityType(.waistCircumference),
    ]

    // MARK: - Authorization

    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    static func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: writableTypes, read: [])
            return true
        } catch {
            return false
        }
    }

    // MARK: - Write

    static func saveWeight(_ entry: WeightEntry) async {
        guard let sample = buildWeightSample(weight: entry.weight, unit: entry.unit, date: entry.date) else { return }
        try? await store.save(sample)
    }

    static func saveScanMetrics(_ scan: InBodyScan) async {
        var samples: [HKSample] = []

        if let bf = scan.bodyFatPercentage, let s = buildBodyFatSample(percentage: bf, date: scan.date) {
            samples.append(s)
        }
        if let lbm = scan.leanBodyMass, let s = buildLeanBodyMassSample(mass: lbm, unit: scan.unit, date: scan.date) {
            samples.append(s)
        }
        if let bmi = scan.bmi, let s = buildBMISample(bmi: bmi, date: scan.date) {
            samples.append(s)
        }

        if !samples.isEmpty {
            try? await store.save(samples)
        }
    }

    static func saveWaistCircumference(value: Double, unit: String, date: Date) async {
        guard let sample = buildWaistSample(value: value, unit: unit, date: date) else { return }
        try? await store.save(sample)
    }

    // MARK: - Sample Builders

    static func buildWeightSample(weight: Double, unit: String, date: Date) -> HKQuantitySample? {
        let hkUnit: HKUnit = unit == "kg" ? .gramUnit(with: .kilo) : .pound()
        let quantity = HKQuantity(unit: hkUnit, doubleValue: weight)
        return HKQuantitySample(type: HKQuantityType(.bodyMass), quantity: quantity, start: date, end: date)
    }

    static func buildBodyFatSample(percentage: Double, date: Date) -> HKQuantitySample? {
        // HealthKit expects body fat as a decimal ratio (e.g., 0.185 for 18.5%)
        let quantity = HKQuantity(unit: .percent(), doubleValue: percentage / 100.0)
        return HKQuantitySample(type: HKQuantityType(.bodyFatPercentage), quantity: quantity, start: date, end: date)
    }

    static func buildLeanBodyMassSample(mass: Double, unit: String, date: Date) -> HKQuantitySample? {
        let hkUnit: HKUnit = unit == "kg" ? .gramUnit(with: .kilo) : .pound()
        let quantity = HKQuantity(unit: hkUnit, doubleValue: mass)
        return HKQuantitySample(type: HKQuantityType(.leanBodyMass), quantity: quantity, start: date, end: date)
    }

    static func buildBMISample(bmi: Double, date: Date) -> HKQuantitySample? {
        let quantity = HKQuantity(unit: .count(), doubleValue: bmi)
        return HKQuantitySample(type: HKQuantityType(.bodyMassIndex), quantity: quantity, start: date, end: date)
    }

    static func buildWaistSample(value: Double, unit: String, date: Date) -> HKQuantitySample? {
        let hkUnit: HKUnit = unit == "cm" ? .meterUnit(with: .centi) : .inch()
        let quantity = HKQuantity(unit: hkUnit, doubleValue: value)
        return HKQuantitySample(type: HKQuantityType(.waistCircumference), quantity: quantity, start: date, end: date)
    }
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
xcodebuild test -project Baseline.xcodeproj -scheme BaselineTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(Passed|Failed)" | tail -5
```

Expected: All tests pass (sample builder tests don't require HealthKit authorization).

- [ ] **Step 5: Commit**

```bash
git add Baseline/Health/ BaselineTests/Health/
git commit -m "feat: add HealthKitManager — writes weight, body fat, lean mass, BMI, waist to Apple Health"
```

---

### Task 21: Integrate HealthKit Writes

**Files:**
- Modify: `Baseline/ViewModels/WeighInViewModel.swift` — write to HealthKit on save
- Modify: `Baseline/ViewModels/BodyViewModel.swift` — write scan metrics + waist to HealthKit

- [ ] **Step 1: Add HealthKit write to WeighInViewModel.save()**

In `WeighInViewModel.swift`, add after the `try? modelContext.save()` line:

```swift
// Write to HealthKit (fire-and-forget)
Task {
    _ = await HealthKitManager.requestAuthorization()
    let entry = WeightEntry(weight: currentWeight, unit: unit, date: Date())
    await HealthKitManager.saveWeight(entry)
}
```

- [ ] **Step 2: Add HealthKit write to BodyViewModel.saveScan()**

In `BodyViewModel.swift`, add after `try? modelContext.save()` in `saveScan()`:

```swift
// Write scan metrics to HealthKit
Task {
    _ = await HealthKitManager.requestAuthorization()
    await HealthKitManager.saveScanMetrics(scan)
}
```

- [ ] **Step 3: Add HealthKit write to BodyViewModel.saveMeasurement()**

In `BodyViewModel.swift`, add after `try? modelContext.save()` in `saveMeasurement()`:

```swift
// Write waist to HealthKit if applicable
if type == .waist {
    Task {
        _ = await HealthKitManager.requestAuthorization()
        await HealthKitManager.saveWaistCircumference(value: value, unit: unit ?? type.defaultUnit, date: Date())
    }
}
```

- [ ] **Step 4: Build and verify**

```bash
xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Baseline/ViewModels/WeighInViewModel.swift Baseline/ViewModels/BodyViewModel.swift
git commit -m "feat: integrate HealthKit writes on weight save, scan save, and waist measurement"
```

---

### Task 22: D1 Sync Engine + Tests

**Files:**
- Create: `Baseline/Sync/APIClient.swift`
- Create: `Baseline/Sync/SyncEngine.swift`
- Create: `Baseline/Sync/SyncConfig.swift`
- Create: `BaselineTests/Sync/APIClientTests.swift`
- Create: `BaselineTests/Sync/SyncEngineTests.swift`

- [ ] **Step 1: Write failing APIClient tests**

Create `BaselineTests/Sync/APIClientTests.swift`:

```swift
import XCTest
@testable import Baseline

final class APIClientTests: XCTestCase {

    func testBuildPushRequest() {
        let client = APIClient(baseURL: "https://api.example.com", apiKey: "test-key")
        let records: [[String: Any]] = [
            ["id": "abc-123", "date": "2026-04-04", "weight": 197.4, "unit": "lb", "updated_at": "2026-04-04T12:00:00Z"]
        ]

        let request = client.buildPushRequest(table: "body_weights", appId: "baseline", records: records)
        XCTAssertEqual(request?.url?.absoluteString, "https://api.example.com/v1/body_weights")
        XCTAssertEqual(request?.httpMethod, "POST")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "X-API-Key"), "test-key")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testBuildPushRequestBody() throws {
        let client = APIClient(baseURL: "https://api.example.com", apiKey: "test-key")
        let records: [[String: Any]] = [
            ["id": "abc-123", "weight": 197.4]
        ]

        let request = client.buildPushRequest(table: "body_weights", appId: "baseline", records: records)
        let body = try JSONSerialization.jsonObject(with: request!.httpBody!) as! [String: Any]
        XCTAssertEqual(body["app_id"] as? String, "baseline")
        XCTAssertEqual((body["records"] as? [[String: Any]])?.count, 1)
    }
}
```

- [ ] **Step 2: Write failing SyncEngine tests**

Create `BaselineTests/Sync/SyncEngineTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Baseline

final class SyncEngineTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([WeightEntry.self, InBodyScan.self, BodyMeasurement.self, SyncState.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    func testGetLastSyncReturnsEmptyForNewTable() {
        let engine = SyncEngine(modelContext: context, apiClient: APIClient(baseURL: "", apiKey: ""))
        let last = engine.getLastSync(table: "body_weights")
        XCTAssertEqual(last, "")
    }

    func testSetAndGetLastSync() {
        let engine = SyncEngine(modelContext: context, apiClient: APIClient(baseURL: "", apiKey: ""))
        engine.setLastSync(table: "body_weights", timestamp: "2026-04-04T12:00:00Z")
        let last = engine.getLastSync(table: "body_weights")
        XCTAssertEqual(last, "2026-04-04T12:00:00Z")
    }

    func testWeightEntryToSyncRecord() {
        let entry = WeightEntry(weight: 197.4, unit: "lb", date: Date())
        let record = SyncConfig.weightEntryToRecord(entry)
        XCTAssertEqual(record["weight"] as? Double, 197.4)
        XCTAssertEqual(record["unit"] as? String, "lb")
        XCTAssertNotNil(record["id"])
        XCTAssertNotNil(record["date"])
        XCTAssertNotNil(record["updated_at"])
    }
}
```

- [ ] **Step 3: Run tests — verify they fail**

Expected: Compilation errors.

- [ ] **Step 4: Implement APIClient**

Create `Baseline/Sync/APIClient.swift`:

```swift
import Foundation

struct SyncResponse: Decodable {
    let synced: Int
    let errors: Int
}

class APIClient {
    let baseURL: String
    let apiKey: String

    init(baseURL: String, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    func buildPushRequest(table: String, appId: String, records: [[String: Any]]) -> URLRequest? {
        guard let url = URL(string: "\(baseURL)/v1/\(table)") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "app_id": appId,
            "records": records,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    func push(table: String, appId: String, records: [[String: Any]]) async -> SyncResponse? {
        guard !records.isEmpty,
              let request = buildPushRequest(table: table, appId: appId, records: records) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode(SyncResponse.self, from: data)
        } catch {
            return nil
        }
    }
}
```

- [ ] **Step 5: Implement SyncConfig**

Create `Baseline/Sync/SyncConfig.swift`:

```swift
import Foundation

enum SyncConfig {

    static func weightEntryToRecord(_ entry: WeightEntry) -> [String: Any] {
        var record: [String: Any] = [
            "id": entry.id.uuidString,
            "date": DateFormatting.iso8601(entry.date),
            "weight": entry.weight,
            "unit": entry.unit,
            "updated_at": DateFormatting.iso8601(entry.updatedAt),
        ]
        if let notes = entry.notes, !notes.isEmpty { record["notes"] = notes }
        return record
    }

    static func inBodyScanToRecord(_ scan: InBodyScan) -> [String: Any] {
        var record: [String: Any] = [
            "id": scan.id.uuidString,
            "date": DateFormatting.iso8601(scan.date),
            "weight": scan.weight,
            "unit": scan.unit,
            "updated_at": DateFormatting.iso8601(scan.updatedAt),
        ]
        if let v = scan.skeletalMuscleMass { record["skeletal_muscle_mass"] = v }
        if let v = scan.bodyFatPercentage { record["body_fat_percent"] = v }
        if let v = scan.bodyFatMass { record["body_fat_mass"] = v }
        if let v = scan.leanBodyMass { record["lean_body_mass"] = v }
        if let v = scan.bmi { record["bmi"] = v }
        if let v = scan.totalBodyWater { record["total_body_water"] = v }
        if let v = scan.basalMetabolicRate { record["basal_metabolic_rate"] = v }
        if let v = scan.inBodyScore { record["inbody_score"] = v }
        if let v = scan.notes { record["notes"] = v }
        return record
    }

    static func bodyMeasurementToRecord(_ m: BodyMeasurement) -> [String: Any] {
        [
            "id": m.id.uuidString,
            "date": DateFormatting.iso8601(m.date),
            "type": m.type,
            "value": m.value,
            "unit": m.unit,
            "source": m.source,
            "updated_at": DateFormatting.iso8601(m.updatedAt),
        ]
    }
}
```

- [ ] **Step 6: Implement SyncEngine**

Create `Baseline/Sync/SyncEngine.swift`:

```swift
import Foundation
import SwiftData

class SyncEngine {
    private let modelContext: ModelContext
    private let apiClient: APIClient
    private let appId = "baseline"

    init(modelContext: ModelContext, apiClient: APIClient) {
        self.modelContext = modelContext
        self.apiClient = apiClient
    }

    // MARK: - Last Sync Tracking

    func getLastSync(table: String) -> String {
        var descriptor = FetchDescriptor<SyncState>(
            predicate: #Predicate { $0.tableName == table }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor).first?.lastSyncTimestamp) ?? ""
    }

    func setLastSync(table: String, timestamp: String) {
        var descriptor = FetchDescriptor<SyncState>(
            predicate: #Predicate { $0.tableName == table }
        )
        descriptor.fetchLimit = 1

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.lastSyncTimestamp = timestamp
        } else {
            modelContext.insert(SyncState(tableName: table, lastSyncTimestamp: timestamp))
        }
        try? modelContext.save()
    }

    // MARK: - Sync All

    func syncAll() async {
        await syncWeights()
        await syncScans()
        await syncMeasurements()
    }

    // MARK: - Sync Individual Tables

    func syncWeights() async {
        let since = getLastSync(table: "body_weights")
        let descriptor = FetchDescriptor<WeightEntry>(
            sortBy: [SortDescriptor(\.updatedAt)]
        )

        guard let allEntries = try? modelContext.fetch(descriptor) else { return }

        // Filter incrementally: if we have a prior sync timestamp, only push entries updated after it
        let entries: [WeightEntry]
        if since.isEmpty {
            entries = allEntries
        } else if let sinceDate = ISO8601DateFormatter().date(from: since) {
            entries = allEntries.filter { $0.updatedAt > sinceDate }
        } else {
            entries = allEntries
        }

        guard !entries.isEmpty else { return }

        let records = entries.map { SyncConfig.weightEntryToRecord($0) }
        if let response = await apiClient.push(table: "body_weights", appId: appId, records: records),
           response.errors == 0,
           let maxTimestamp = entries.map({ DateFormatting.iso8601($0.updatedAt) }).max() {
            setLastSync(table: "body_weights", timestamp: maxTimestamp)
        }
    }

    func syncScans() async {
        let since = getLastSync(table: "body_comp_scans")
        let descriptor = FetchDescriptor<InBodyScan>(
            sortBy: [SortDescriptor(\.updatedAt)]
        )

        guard let allScans = try? modelContext.fetch(descriptor) else { return }

        let scans: [InBodyScan]
        if since.isEmpty {
            scans = allScans
        } else if let sinceDate = ISO8601DateFormatter().date(from: since) {
            scans = allScans.filter { $0.updatedAt > sinceDate }
        } else {
            scans = allScans
        }

        guard !scans.isEmpty else { return }

        let records = scans.map { SyncConfig.inBodyScanToRecord($0) }
        if let response = await apiClient.push(table: "body_comp_scans", appId: appId, records: records),
           response.errors == 0,
           let maxTimestamp = scans.map({ DateFormatting.iso8601($0.updatedAt) }).max() {
            setLastSync(table: "body_comp_scans", timestamp: maxTimestamp)
        }
    }

    func syncMeasurements() async {
        let since = getLastSync(table: "body_measurements")
        let descriptor = FetchDescriptor<BodyMeasurement>(
            sortBy: [SortDescriptor(\.updatedAt)]
        )

        guard let allMeasurements = try? modelContext.fetch(descriptor) else { return }

        let measurements: [BodyMeasurement]
        if since.isEmpty {
            measurements = allMeasurements
        } else if let sinceDate = ISO8601DateFormatter().date(from: since) {
            measurements = allMeasurements.filter { $0.updatedAt > sinceDate }
        } else {
            measurements = allMeasurements
        }

        guard !measurements.isEmpty else { return }

        let records = measurements.map { SyncConfig.bodyMeasurementToRecord($0) }
        if let response = await apiClient.push(table: "body_measurements", appId: appId, records: records),
           response.errors == 0,
           let maxTimestamp = measurements.map({ DateFormatting.iso8601($0.updatedAt) }).max() {
            setLastSync(table: "body_measurements", timestamp: maxTimestamp)
        }
    }
}
```

- [ ] **Step 7: Run tests — verify they pass**

```bash
xcodebuild test -project Baseline.xcodeproj -scheme BaselineTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(Passed|Failed)" | tail -5
```

Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
git add Baseline/Sync/ BaselineTests/Sync/
git commit -m "feat: add D1 SyncEngine with APIClient, table configs, timestamp tracking"
```

---

### Task 23: Integrate Sync into App Lifecycle

**Files:**
- Modify: `Baseline/BaselineApp.swift` — trigger sync on app open

- [ ] **Step 1: Add sync trigger to BaselineApp**

In `BaselineApp.swift`, update the WindowGroup body:

```swift
var body: some Scene {
    WindowGroup {
        MainTabView()
            .onAppear {
                triggerSync()
            }
    }
    .modelContainer(modelContainer)
}

private func triggerSync() {
    SyncHelper.triggerSync(modelContainer: modelContainer)
}

// Static helper so ViewModels can also trigger sync after writes
enum SyncHelper {
    static func triggerSync(modelContainer: ModelContainer) {
        let settings = SettingsViewModel()
        guard settings.isSyncEnabled else { return }

        Task {
            let context = ModelContext(modelContainer)
            let client = APIClient(baseURL: settings.syncApiUrl, apiKey: settings.syncApiKey)
            let engine = SyncEngine(modelContext: context, apiClient: client)
            await engine.syncAll()
        }
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Baseline/BaselineApp.swift
git commit -m "feat: trigger D1 sync on app launch when sync is configured"
```

---

### Task 24: CloudKit Configuration

**Files:**
- Modify: `Baseline/BaselineApp.swift` — ensure CloudKit ModelConfiguration is set

CloudKit integration with SwiftData is primarily a configuration step. The ModelConfiguration in Task 1 already uses `cloudKitDatabase: .automatic`. This task verifies the setup and ensures models are CloudKit-compatible.

- [ ] **Step 1: Verify CloudKit compatibility**

SwiftData + CloudKit requires:
- No `@Attribute(.unique)` constraints (CloudKit doesn't enforce them)
- All properties must be optional or have defaults

Review `SyncState.swift` — it has `@Attribute(.unique)` on `tableName`. This is fine because SyncState is local-only (not synced to CloudKit). But to prevent CloudKit issues, exclude it from the CloudKit schema.

Update `BaselineApp.swift` to use separate configurations:

```swift
init() {
    do {
        let schema = Schema([
            WeightEntry.self,
            InBodyScan.self,
            BodyMeasurement.self,
            SyncState.self,
        ])

        // Main data — syncs to iCloud
        let cloudConfig = ModelConfiguration(
            "Baseline",
            schema: Schema([WeightEntry.self, InBodyScan.self, BodyMeasurement.self]),
            cloudKitDatabase: .automatic
        )

        // Sync state — local only, not synced to iCloud
        let localConfig = ModelConfiguration(
            "BaselineLocal",
            schema: Schema([SyncState.self]),
            cloudKitDatabase: .none
        )

        modelContainer = try ModelContainer(for: schema, configurations: [cloudConfig, localConfig])
    } catch {
        fatalError("Failed to configure SwiftData: \(error)")
    }
}
```

- [ ] **Step 2: Verify Xcode project has CloudKit capability**

The entitlements file from Task 1 already includes the CloudKit container identifier. Verify:
- `com.apple.developer.icloud-container-identifiers` includes `iCloud.com.cadre.baseline`
- `com.apple.developer.icloud-services` includes `CloudKit`

- [ ] **Step 3: Build and verify**

```bash
xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Baseline/BaselineApp.swift
git commit -m "feat: split ModelContainer — CloudKit for user data, local-only for sync state"
```

---

## Phase 6: Polish & Extensions

### Task 25: Haptic Feedback

**Files:**
- Create: `Baseline/Utilities/Haptics.swift`
- Modify: `Baseline/Views/Today/WeighInSheet.swift` — add haptics on stepper, save
- Modify: `Baseline/Views/Body/LogMeasurementSheet.swift` — add haptics on save

- [ ] **Step 1: Create Haptics helper**

Create `Baseline/Utilities/Haptics.swift`:

```swift
import UIKit

enum Haptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
```

- [ ] **Step 2: Add haptics to WeighInSheet**

In `WeighInSheet.swift`:
- Add `Haptics.light()` inside the increment and decrement button actions
- Add `Haptics.selection()` inside the step-size toggle button action
- Add `Haptics.success()` inside the save button action, before dismiss

- [ ] **Step 3: Add haptics to LogMeasurementSheet**

In `LogMeasurementSheet.swift`:
- Add `Haptics.success()` inside the save button action, before dismiss

- [ ] **Step 4: Build and verify**

```bash
xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Baseline/Utilities/Haptics.swift Baseline/Views/Today/WeighInSheet.swift Baseline/Views/Body/LogMeasurementSheet.swift
git commit -m "feat: add haptic feedback on weight stepper, save actions, measurement saves"
```

---

### Task 26: TipKit Onboarding

**Files:**
- Create: `Baseline/Utilities/BaselineTips.swift`
- Modify: `Baseline/BaselineApp.swift` — configure TipKit
- Modify: `Baseline/Views/Today/TodayView.swift` — add weigh-in tip
- Modify: `Baseline/Views/Body/BodyView.swift` — add scan tip

- [ ] **Step 1: Define tips**

Create `Baseline/Utilities/BaselineTips.swift`:

```swift
import TipKit

struct WeighInTip: Tip {
    var title: Text { Text("Log Your Weight") }
    var message: Text? { Text("Tap 'Weigh In' to record today's weight. It defaults to your last entry — just adjust and save.") }
    var image: Image? { Image(systemName: "scalemass") }
}

struct ScanTip: Tip {
    var title: Text { Text("InBody Scan") }
    var message: Text? { Text("Got a printout from the InBody machine? Tap 'Log Scan' to photograph it — we'll extract the data automatically.") }
    var image: Image? { Image(systemName: "camera") }
}

struct TrendsTip: Tip {
    var title: Text { Text("Track Your Trend") }
    var message: Text? { Text("Swipe through time ranges to see your weight trend. The dashed line is your 7-day moving average.") }
    var image: Image? { Image(systemName: "chart.xyaxis.line") }
}
```

- [ ] **Step 2: Configure TipKit in BaselineApp**

In `BaselineApp.swift`, add to `init()` after the ModelContainer setup:

```swift
try? Tips.configure([
    .displayFrequency(.weekly)
])
```

- [ ] **Step 3: Add tips to views**

In `TodayView.swift`, add above the "Weigh In" button:

```swift
TipView(WeighInTip())
    .padding(.horizontal, CadreSpacing.xl)
```

In `BodyView.swift`, add above the action buttons:

```swift
TipView(ScanTip())
    .padding(.horizontal, CadreSpacing.lg)
```

- [ ] **Step 4: Build and verify**

```bash
xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Baseline/Utilities/BaselineTips.swift Baseline/BaselineApp.swift Baseline/Views/Today/TodayView.swift Baseline/Views/Body/BodyView.swift
git commit -m "feat: add TipKit contextual onboarding for weigh-in, scan, and trends"
```

---

### Task 27: Accessibility Audit

**Files:**
- Modify: `Baseline/Views/Today/TodayView.swift`
- Modify: `Baseline/Views/Today/WeighInSheet.swift`
- Modify: `Baseline/Views/Trends/TrendsView.swift`
- Modify: `Baseline/Design/Components/StatCard.swift`

- [ ] **Step 1: Add accessibility labels and traits to TodayView**

In `TodayView.swift`, add to the weight display:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("Today's weight: \(UnitConversion.formatWeight(entry.weight, unit: entry.unit)) \(entry.unit)")
```

Add to delta label:

```swift
.accessibilityLabel("Change: \(UnitConversion.formatDelta(delta)) \(delta > 0 ? "gained" : "lost")")
```

- [ ] **Step 2: Add accessibility to WeighInSheet**

In `WeighInSheet.swift`:

```swift
// On the weight display
.accessibilityLabel("Current weight: \(UnitConversion.formatWeight(vm?.currentWeight ?? 0, unit: unit)) \(unit)")
.accessibilityValue(UnitConversion.formatWeight(vm?.currentWeight ?? 0, unit: unit))

// On stepper buttons
.accessibilityLabel("Decrease weight by \(String(format: "%.1f", vm?.stepSize ?? 0.1))")
.accessibilityLabel("Increase weight by \(String(format: "%.1f", vm?.stepSize ?? 0.1))")

// On step size button
.accessibilityLabel("Step size: \(String(format: "%.1f", vm?.stepSize ?? 0.1)). Tap to change.")
.accessibilityHint("Cycles through 0.1, 0.5, and 1.0")
```

- [ ] **Step 3: Add accessibility to StatCard**

In `StatCard.swift`, wrap the card:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("\(title): \(value) \(unit)")
```

- [ ] **Step 4: Add accessibility to TrendsView chart**

In `TrendsView.swift`, add to the Chart:

```swift
.accessibilityLabel("Weight trend chart showing \(vm?.entries.count ?? 0) data points over \(vm?.timeRange.rawValue ?? "month")")
```

- [ ] **Step 5: Update fonts for Dynamic Type support**

The current `CadreTypography` uses fixed-size `Font.system(size:)` constructors, which do NOT scale with Dynamic Type. Update the key sizes in `CadreTokens.swift` to use `Font.TextStyle`-based constructors (e.g., `Font.title`, `Font.headline`, `Font.body`) or use `.relativeTo(_:)` with custom sizes so they scale with the user's preferred text size. After updating, verify by building and testing in the simulator with Accessibility Inspector at various Dynamic Type settings.

- [ ] **Step 6: Commit**

```bash
git add Baseline/Views/ Baseline/Design/Components/
git commit -m "feat: add accessibility labels, traits, and VoiceOver support across all screens"
```

---

### Task 28: Widget Extension [DESIGN GATE]

**Files:**
- Modify: `BaselineWidgets/BaselineWidgets.swift`
- Create: `BaselineWidgets/WeightWidget.swift`
- Create: `BaselineWidgets/WeightLockScreenWidget.swift`
- Modify: `project.yml` — add App Group entitlement to widget target

**DESIGN GATE:** Create mockups for:
- Home screen widget (small: today's weight + delta, medium: weight + sparkline)
- Lock screen widget (circular: today's weight, rectangular: weight + delta)

- [ ] **Step 1: Update project.yml for shared App Group**

Add the App Group entitlement to the BaselineWidgets target in `project.yml` so it can access the shared SwiftData store. Also add the shared model files as sources.

- [ ] **Step 2: Create shared data access**

The widget needs to read WeightEntry data. Since widgets run in a separate process, they need access to the same SwiftData store via the App Group container.

Create a shared `ModelContainer` helper that both the app and widget can use. This involves updating the app's `ModelConfiguration` to use the App Group URL:

```swift
// In BaselineApp.swift — update the ModelConfiguration URL:
let appGroupURL = FileManager.default
    .containerURL(forSecurityApplicationGroupIdentifier: "group.com.cadre.baseline")!
    .appendingPathComponent("Baseline.store")

let cloudConfig = ModelConfiguration(
    "Baseline",
    schema: Schema([WeightEntry.self, InBodyScan.self, BodyMeasurement.self]),
    url: appGroupURL,
    cloudKitDatabase: .automatic
)
```

- [ ] **Step 3: Implement home screen widget**

Create `BaselineWidgets/WeightWidget.swift`:

```swift
import WidgetKit
import SwiftUI
import SwiftData

struct WeightWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeightWidgetEntry {
        WeightWidgetEntry(date: .now, weight: 197.4, unit: "lb", delta: -0.6)
    }

    func getSnapshot(in context: Context, completion: @escaping (WeightWidgetEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeightWidgetEntry>) -> Void) {
        let entry = loadLatestWeight()
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
        completion(timeline)
    }

    private func loadLatestWeight() -> WeightWidgetEntry {
        do {
            let appGroupURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: "group.com.cadre.baseline")!
                .appendingPathComponent("Baseline.store")
            let config = ModelConfiguration("Baseline", url: appGroupURL)
            let container = try ModelContainer(for: WeightEntry.self, configurations: [config])
            let context = ModelContext(container)

            let today = Calendar.current.startOfDay(for: Date())
            var descriptor = FetchDescriptor<WeightEntry>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            descriptor.fetchLimit = 2
            let entries = try context.fetch(descriptor)

            let latest = entries.first
            let previous = entries.count > 1 ? entries[1] : nil
            let delta = (latest != nil && previous != nil) ? latest!.weight - previous!.weight : nil

            return WeightWidgetEntry(
                date: .now,
                weight: latest?.weight,
                unit: latest?.unit ?? "lb",
                delta: delta
            )
        } catch {
            return WeightWidgetEntry(date: .now, weight: nil, unit: "lb", delta: nil)
        }
    }
}

struct WeightWidgetEntry: TimelineEntry {
    let date: Date
    let weight: Double?
    let unit: String
    let delta: Double?
}

struct WeightWidgetView: View {
    var entry: WeightWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Baseline")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            if let weight = entry.weight {
                Text(String(format: "%.1f", weight))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(entry.unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No data")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            if let delta = entry.delta {
                Text(delta >= 0 ? "+\(String(format: "%.1f", delta))" : String(format: "%.1f", delta))
                    .font(.caption)
                    .foregroundStyle(delta > 0 ? .red : .green)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumWidget: some View {
        HStack {
            smallWidget
            Spacer()
            // TODO: sparkline requires fetching recent WeightEntry array — implement after widget shared data access is proven
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct WeightWidget: Widget {
    let kind = "WeightWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeightWidgetProvider()) { entry in
            WeightWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Weight")
        .description("Your latest weight and daily change.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
```

- [ ] **Step 4: Implement lock screen widget**

Create `BaselineWidgets/WeightLockScreenWidget.swift`:

```swift
import WidgetKit
import SwiftUI

struct WeightLockScreenWidget: Widget {
    let kind = "WeightLockScreen"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeightWidgetProvider()) { entry in
            WeightLockScreenView(entry: entry)
        }
        .configurationDisplayName("Weight")
        .description("Today's weight on your lock screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct WeightLockScreenView: View {
    var entry: WeightWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        default:
            circularView
        }
    }

    private var circularView: some View {
        VStack(spacing: 0) {
            if let weight = entry.weight {
                Text(String(format: "%.0f", weight))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(entry.unit)
                    .font(.system(size: 8))
            } else {
                Image(systemName: "scalemass")
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var rectangularView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Weight")
                    .font(.caption2)
                if let weight = entry.weight {
                    Text("\(String(format: "%.1f", weight)) \(entry.unit)")
                        .font(.system(.body, design: .rounded, weight: .bold))
                }
            }
            Spacer()
            if let delta = entry.delta {
                Text(delta >= 0 ? "+\(String(format: "%.1f", delta))" : String(format: "%.1f", delta))
                    .font(.caption)
                    .foregroundStyle(delta > 0 ? .red : .green)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
```

- [ ] **Step 5: Update widget bundle entry point**

Replace `BaselineWidgets/BaselineWidgets.swift`:

```swift
import WidgetKit
import SwiftUI

@main
struct BaselineWidgetBundle: WidgetBundle {
    var body: some Widget {
        WeightWidget()
        WeightLockScreenWidget()
    }
}
```

- [ ] **Step 6: Build and verify**

```bash
xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add BaselineWidgets/ Baseline/BaselineApp.swift project.yml
git commit -m "feat: add home screen and lock screen widgets showing today's weight and delta"
```

---

## Final Checklist

After all tasks are complete:

- [ ] Full build succeeds: `xcodebuild build`
- [ ] All tests pass: `xcodebuild test`
- [ ] App launches in simulator — Today tab shows, can navigate all 3 tabs
- [ ] Weigh In flow works: tap button → adjust → save → Today updates
- [ ] History shows entries with deltas
- [ ] Trends chart renders with time range switching
- [ ] Body tab shows measurements, scan entry works (manual fallback)
- [ ] Settings saves unit preference and sync config
- [ ] Haptic feedback fires on stepper taps and saves
- [ ] TipKit tips appear on first launch
- [ ] VoiceOver reads all screens correctly
- [ ] Widget shows in widget gallery
