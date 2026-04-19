# Unify Scan Edit Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Edit Scan screen render with the same layout as the Scan Entry manual form by driving both through `ScanEntryViewModel` + `ScanEntryFlow.manualFormStep`, eliminating ~500 lines of duplicated form code.

**Architecture:** Introduce an "editing" mode on `ScanEntryViewModel`: a new `loadForEdit(scan:payload:massPref:)` method seeds `fields`, `scanDate`, `selectedType`, `selectedSource`, and a new `editingScan: Scan?` handle. `save()` branches on `editingScan` — if set, it updates the existing `Scan` in place (new payload, new date, `updatedAt = now`) and deletes any *other* conflicting scan on the target date. `ScanEntryFlow.formHeader` swaps the title to "Edit Scan" when `vm.editingScan != nil`. `ScanEditView` collapses to a thin wrapper that creates a seeded VM and renders `ScanEntryFlow(viewModel:)`.

**Tech Stack:** SwiftUI, SwiftData, Swift 6, XCTest, swift-snapshot-testing.

---

## File Structure

**Modified:**
- `Baseline/ViewModels/ScanEntryViewModel.swift` — add `editingScan` property, `loadForEdit(...)` method, edit-aware `save()` and `existingScanForSelectedDate()`.
- `Baseline/Views/Body/ScanEntryFlow.swift` — `formHeader` title is `"Edit Scan"` when `vm.editingScan != nil`.
- `Baseline/Views/Body/ScanDetailView.swift` — collapse `ScanEditView` struct (≈485 lines) into a ≈30-line wrapper that seeds a `ScanEntryViewModel` and hosts `ScanEntryFlow`.

**Test files:**
- `BaselineTests/ViewModels/ScanEntryViewModelTests.swift` — add tests for `loadForEdit`, edit-mode `save`, conflict handling.
- `BaselineTests/Snapshots/ScanEntrySnapshotTests.swift` — add `testScanEdit_UsesManualFormLayout` to lock in layout parity.

**Unchanged:** `Baseline/Models/Scan.swift`, `Baseline/Models/InBodyPayload.swift`, all other views.

---

## Task 1: Add `editingScan` + `loadForEdit` to `ScanEntryViewModel`

**Files:**
- Modify: `Baseline/ViewModels/ScanEntryViewModel.swift`
- Test: `BaselineTests/ViewModels/ScanEntryViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

Add to `BaselineTests/ViewModels/ScanEntryViewModelTests.swift` before the closing `}`:

```swift
    // MARK: - Edit Mode

    func testLoadForEdit_SeedsAllFieldsWithKgUnits() throws {
        let vm = ScanEntryViewModel(modelContext: context)

        let payload = InBodyPayload(
            weightKg: 80.0,
            skeletalMuscleMassKg: 38.0,
            bodyFatMassKg: 16.0,
            bodyFatPct: 20.0,
            totalBodyWaterL: 48.0,
            bmi: 24.0,
            basalMetabolicRate: 1800,
            intracellularWaterL: 30.0,
            extracellularWaterL: 18.0,
            dryLeanMassKg: 14.0,
            leanBodyMassKg: 62.0,
            inBodyScore: 76,
            rightArmLeanKg: 3.5,
            leftArmLeanKg: 3.4,
            trunkLeanKg: 29.0,
            rightLegLeanKg: 10.1,
            leftLegLeanKg: 10.0,
            rightArmFatKg: 0.9,
            leftArmFatKg: 0.9,
            trunkFatKg: 8.0,
            rightLegFatKg: 2.8,
            leftLegFatKg: 2.8,
            ecwTbwRatio: 0.378,
            skeletalMuscleIndex: 10.2,
            visceralFatLevel: 5,
            rightArmLeanPct: 110.0,
            leftArmLeanPct: 108.0,
            trunkLeanPct: 100.0,
            rightLegLeanPct: 102.0,
            leftLegLeanPct: 101.0,
            rightArmFatPct: 90.0,
            leftArmFatPct: 92.0,
            trunkFatPct: 110.0,
            rightLegFatPct: 95.0,
            leftLegFatPct: 96.0
        )
        let data = try JSONEncoder().encode(payload)
        let scanDate = Calendar.current.startOfDay(for: Date().addingTimeInterval(-86400))
        let scan = Scan(date: scanDate, type: .inBody, source: .ocr, payload: data)
        context.insert(scan)
        try context.save()

        vm.loadForEdit(scan: scan, payload: payload, massPref: "kg")

        XCTAssertTrue(vm.editingScan === scan)
        XCTAssertEqual(vm.currentStep, .manualEntry)
        XCTAssertEqual(vm.selectedType, .inBody)
        XCTAssertEqual(vm.selectedSource, .ocr)
        XCTAssertEqual(vm.scanDate, scanDate)
        XCTAssertEqual(vm.weightKg, "80")
        XCTAssertEqual(vm.skeletalMuscleMassKg, "38")
        XCTAssertEqual(vm.bodyFatPct, "20")
        XCTAssertEqual(vm.bmi, "24")
        XCTAssertEqual(vm.basalMetabolicRate, "1800")
        XCTAssertEqual(vm.fieldValue("rightArmLeanKg"), "3.5")
        XCTAssertEqual(vm.fieldValue("ecwTbwRatio"), "0.378")
        XCTAssertEqual(vm.fieldValue("visceralFatLevel"), "5")
    }

    func testLoadForEdit_ConvertsMassFieldsToLbWhenPrefIsLb() throws {
        let vm = ScanEntryViewModel(modelContext: context)

        let payload = InBodyPayload(
            weightKg: 80.0,
            skeletalMuscleMassKg: 38.0,
            bodyFatMassKg: 16.0,
            bodyFatPct: 20.0,
            totalBodyWaterL: 48.0,
            bmi: 24.0,
            basalMetabolicRate: 1800
        )
        let data = try JSONEncoder().encode(payload)
        let scan = Scan(date: Date(), type: .inBody, source: .manual, payload: data)
        context.insert(scan)

        vm.loadForEdit(scan: scan, payload: payload, massPref: "lb")

        // 80 kg → 176.37 lb
        let expectedLb = UnitConversion.kgToLb(80.0)
        let weightLb = try XCTUnwrap(Double(vm.weightKg))
        XCTAssertEqual(weightLb, expectedLb, accuracy: 0.1)
        // Non-mass fields stay the same
        XCTAssertEqual(vm.bodyFatPct, "20")
        XCTAssertEqual(vm.bmi, "24")
    }

    func testLoadForEdit_LeavesEmptyStringForMissingOptionals() throws {
        let vm = ScanEntryViewModel(modelContext: context)

        let payload = InBodyPayload(
            weightKg: 80.0,
            skeletalMuscleMassKg: 38.0,
            bodyFatMassKg: 16.0,
            bodyFatPct: 20.0,
            totalBodyWaterL: 48.0,
            bmi: 24.0,
            basalMetabolicRate: 1800
        )
        let data = try JSONEncoder().encode(payload)
        let scan = Scan(date: Date(), type: .inBody, source: .manual, payload: data)
        context.insert(scan)

        vm.loadForEdit(scan: scan, payload: payload, massPref: "kg")

        XCTAssertEqual(vm.fieldValue("rightArmLeanKg"), "")
        XCTAssertEqual(vm.fieldValue("ecwTbwRatio"), "")
        XCTAssertEqual(vm.fieldValue("visceralFatLevel"), "")
        XCTAssertEqual(vm.fieldValue("inBodyScore"), "")
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineTests/ScanEntryViewModelTests -quiet`

Expected: FAIL — `loadForEdit` not defined, `editingScan` property not found.

- [ ] **Step 3: Add `editingScan` property**

In `Baseline/ViewModels/ScanEntryViewModel.swift`, add after `var retryCount: Int = 0` (around line 50):

```swift
    /// When non-nil, `save()` updates this scan in place instead of inserting a new one.
    /// Set by `loadForEdit` so the same VM drives the manual form for both new and edit flows.
    var editingScan: Scan?
```

- [ ] **Step 4: Add `loadForEdit` method**

In `Baseline/ViewModels/ScanEntryViewModel.swift`, add after `init(modelContext:)` (around line 113):

```swift
    /// Seed the VM from an existing scan so the manual form renders the same
    /// layout for edit as for entry. Mass fields are converted from stored kg
    /// to the user's preferred display unit; `buildPayload()` converts back
    /// to kg on save.
    func loadForEdit(scan: Scan, payload: InBodyPayload, massPref: String) {
        self.editingScan = scan
        // `scan.scanType` / `scan.scanSource` return optionals because the
        // stored raw-string could fail to parse. Fall back to current defaults.
        self.selectedType = scan.scanType ?? .inBody
        self.selectedSource = scan.scanSource ?? .manual
        self.scanDate = scan.date
        self.currentStep = .manualEntry

        let m: (Double) -> String = { kg in
            Self.formatLoaded(massPref == "kg" ? kg : UnitConversion.kgToLb(kg))
        }
        let om: (Double?) -> String = { kg in
            guard let kg else { return "" }
            return Self.formatLoaded(massPref == "kg" ? kg : UnitConversion.kgToLb(kg))
        }
        let f: (Double) -> String = { Self.formatLoaded($0) }
        let of: (Double?) -> String = { v in
            guard let v else { return "" }
            return Self.formatLoaded(v)
        }
        let ratio: (Double?) -> String = { v in
            guard let v else { return "" }
            return String(format: "%.3f", v)
        }
        let integer: (Double?) -> String = { v in
            guard let v else { return "" }
            return String(format: "%.0f", v)
        }

        // Core (required)
        fields["weightKg"] = m(payload.weightKg)
        fields["skeletalMuscleMassKg"] = m(payload.skeletalMuscleMassKg)
        fields["bodyFatMassKg"] = m(payload.bodyFatMassKg)
        fields["bodyFatPct"] = f(payload.bodyFatPct)
        fields["totalBodyWaterL"] = f(payload.totalBodyWaterL)
        fields["bmi"] = f(payload.bmi)
        fields["basalMetabolicRate"] = f(payload.basalMetabolicRate)

        // Body Composition (optional)
        fields["intracellularWaterL"] = of(payload.intracellularWaterL)
        fields["extracellularWaterL"] = of(payload.extracellularWaterL)
        fields["dryLeanMassKg"] = om(payload.dryLeanMassKg)
        fields["leanBodyMassKg"] = om(payload.leanBodyMassKg)
        fields["inBodyScore"] = of(payload.inBodyScore)

        // ECW/TBW (3 decimal places)
        fields["ecwTbwRatio"] = ratio(payload.ecwTbwRatio)
        fields["skeletalMuscleIndex"] = of(payload.skeletalMuscleIndex)
        fields["visceralFatLevel"] = integer(payload.visceralFatLevel)

        // Segmental Lean (mass)
        fields["rightArmLeanKg"] = om(payload.rightArmLeanKg)
        fields["leftArmLeanKg"] = om(payload.leftArmLeanKg)
        fields["trunkLeanKg"] = om(payload.trunkLeanKg)
        fields["rightLegLeanKg"] = om(payload.rightLegLeanKg)
        fields["leftLegLeanKg"] = om(payload.leftLegLeanKg)

        // Segmental Lean (pct)
        fields["rightArmLeanPct"] = of(payload.rightArmLeanPct)
        fields["leftArmLeanPct"] = of(payload.leftArmLeanPct)
        fields["trunkLeanPct"] = of(payload.trunkLeanPct)
        fields["rightLegLeanPct"] = of(payload.rightLegLeanPct)
        fields["leftLegLeanPct"] = of(payload.leftLegLeanPct)

        // Segmental Fat (mass)
        fields["rightArmFatKg"] = om(payload.rightArmFatKg)
        fields["leftArmFatKg"] = om(payload.leftArmFatKg)
        fields["trunkFatKg"] = om(payload.trunkFatKg)
        fields["rightLegFatKg"] = om(payload.rightLegFatKg)
        fields["leftLegFatKg"] = om(payload.leftLegFatKg)

        // Segmental Fat (pct)
        fields["rightArmFatPct"] = of(payload.rightArmFatPct)
        fields["leftArmFatPct"] = of(payload.leftArmFatPct)
        fields["trunkFatPct"] = of(payload.trunkFatPct)
        fields["rightLegFatPct"] = of(payload.rightLegFatPct)
        fields["leftLegFatPct"] = of(payload.leftLegFatPct)
    }

    /// Formats a loaded numeric field for display — matches `ScanEditView`'s
    /// prior behavior (integer if whole, 1 decimal otherwise). Separate from
    /// `formatValue` because that one gates integer formatting on `>= 10`.
    private static func formatLoaded(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineTests/ScanEntryViewModelTests -quiet`

Expected: PASS — all three new tests and all existing `ScanEntryViewModelTests` still pass.

- [ ] **Step 6: Commit**

```bash
git add Baseline/ViewModels/ScanEntryViewModel.swift BaselineTests/ViewModels/ScanEntryViewModelTests.swift
git commit -m "$(cat <<'EOF'
feat(scan-entry): add editingScan handle and loadForEdit seed method

Lets the same view model drive both new-scan entry and edit flows so
they can share the manual form layout in a later step.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Edit-aware `save()` + conflict handling

**Files:**
- Modify: `Baseline/ViewModels/ScanEntryViewModel.swift:354-373`
- Test: `BaselineTests/ViewModels/ScanEntryViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `BaselineTests/ViewModels/ScanEntryViewModelTests.swift`:

```swift
    func testSave_InEditMode_UpdatesExistingScanInPlace() throws {
        let vm = ScanEntryViewModel(modelContext: context)

        // Create an initial scan
        let original = InBodyPayload(
            weightKg: 80.0, skeletalMuscleMassKg: 38.0, bodyFatMassKg: 16.0,
            bodyFatPct: 20.0, totalBodyWaterL: 48.0, bmi: 24.0,
            basalMetabolicRate: 1800
        )
        let data = try JSONEncoder().encode(original)
        let originalDate = Calendar.current.startOfDay(for: Date().addingTimeInterval(-86400))
        let scan = Scan(date: originalDate, type: .inBody, source: .manual, payload: data)
        context.insert(scan)
        try context.save()
        let originalId = scan.id

        vm.loadForEdit(scan: scan, payload: original, massPref: "kg")
        vm.weightKg = "85"
        vm.bodyFatPct = "18"

        try vm.save()

        let scans = try context.fetch(FetchDescriptor<Scan>())
        XCTAssertEqual(scans.count, 1, "Edit should not insert a new scan")
        XCTAssertEqual(scans.first?.id, originalId)

        if case .inBody(let updated) = try scans.first!.decoded() {
            XCTAssertEqual(updated.weightKg, 85.0)
            XCTAssertEqual(updated.bodyFatPct, 18.0)
        } else {
            XCTFail("Expected inBody payload")
        }
    }

    func testSave_InEditMode_BumpsUpdatedAt() throws {
        let vm = ScanEntryViewModel(modelContext: context)
        let payload = InBodyPayload(
            weightKg: 80.0, skeletalMuscleMassKg: 38.0, bodyFatMassKg: 16.0,
            bodyFatPct: 20.0, totalBodyWaterL: 48.0, bmi: 24.0,
            basalMetabolicRate: 1800
        )
        let data = try JSONEncoder().encode(payload)
        let scan = Scan(date: Date(), type: .inBody, source: .manual, payload: data)
        scan.updatedAt = Date(timeIntervalSince1970: 0)
        context.insert(scan)
        try context.save()

        vm.loadForEdit(scan: scan, payload: payload, massPref: "kg")
        try vm.save()

        XCTAssertGreaterThan(scan.updatedAt.timeIntervalSince1970, 1_000_000)
    }

    func testSave_InEditMode_DeletesConflictingScanOnNewDate() throws {
        let vm = ScanEntryViewModel(modelContext: context)

        let dayA = Calendar.current.startOfDay(for: Date().addingTimeInterval(-86400 * 2))
        let dayB = Calendar.current.startOfDay(for: Date().addingTimeInterval(-86400))

        let payloadA = InBodyPayload(
            weightKg: 80.0, skeletalMuscleMassKg: 38.0, bodyFatMassKg: 16.0,
            bodyFatPct: 20.0, totalBodyWaterL: 48.0, bmi: 24.0,
            basalMetabolicRate: 1800
        )
        let payloadB = InBodyPayload(
            weightKg: 82.0, skeletalMuscleMassKg: 39.0, bodyFatMassKg: 17.0,
            bodyFatPct: 21.0, totalBodyWaterL: 49.0, bmi: 25.0,
            basalMetabolicRate: 1850
        )

        let scanA = Scan(date: dayA, type: .inBody, source: .manual,
                         payload: try JSONEncoder().encode(payloadA))
        let scanB = Scan(date: dayB, type: .inBody, source: .manual,
                         payload: try JSONEncoder().encode(payloadB))
        context.insert(scanA)
        context.insert(scanB)
        try context.save()
        let scanAId = scanA.id

        // Edit scanA and move its date to dayB — should delete scanB, keep scanA
        vm.loadForEdit(scan: scanA, payload: payloadA, massPref: "kg")
        vm.scanDate = dayB
        try vm.save()

        let remaining = try context.fetch(FetchDescriptor<Scan>())
        XCTAssertEqual(remaining.count, 1, "Conflicting scan on target date should be deleted")
        XCTAssertEqual(remaining.first?.id, scanAId, "The edited scan should survive, not the conflict")
        XCTAssertEqual(remaining.first?.date, dayB)
    }

    func testSave_InEditMode_SameDateDoesNotDeleteSelf() throws {
        let vm = ScanEntryViewModel(modelContext: context)
        let payload = InBodyPayload(
            weightKg: 80.0, skeletalMuscleMassKg: 38.0, bodyFatMassKg: 16.0,
            bodyFatPct: 20.0, totalBodyWaterL: 48.0, bmi: 24.0,
            basalMetabolicRate: 1800
        )
        let day = Calendar.current.startOfDay(for: Date())
        let scan = Scan(date: day, type: .inBody, source: .manual,
                        payload: try JSONEncoder().encode(payload))
        context.insert(scan)
        try context.save()
        let scanId = scan.id

        vm.loadForEdit(scan: scan, payload: payload, massPref: "kg")
        vm.weightKg = "85" // edit a field but keep date
        try vm.save()

        let remaining = try context.fetch(FetchDescriptor<Scan>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.id, scanId)
    }

    func testExistingScanForSelectedDate_ExcludesEditingScan() throws {
        let vm = ScanEntryViewModel(modelContext: context)
        let payload = InBodyPayload(
            weightKg: 80.0, skeletalMuscleMassKg: 38.0, bodyFatMassKg: 16.0,
            bodyFatPct: 20.0, totalBodyWaterL: 48.0, bmi: 24.0,
            basalMetabolicRate: 1800
        )
        let day = Calendar.current.startOfDay(for: Date())
        let scan = Scan(date: day, type: .inBody, source: .manual,
                        payload: try JSONEncoder().encode(payload))
        context.insert(scan)
        try context.save()

        vm.loadForEdit(scan: scan, payload: payload, massPref: "kg")
        vm.scanDate = day

        XCTAssertNil(vm.existingScanForSelectedDate(),
                     "Editing scan should not flag itself as a conflict on its own date")
    }

    /// End-to-end unit round-trip: a scan stored in kg, edited under an "lb"
    /// display preference, must save back to kg with no drift. Catches the
    /// "converted twice" or "converted wrong direction" class of bugs.
    func testEditFlow_UnitRoundTrip_KgStoredLbEditedKgSaved() throws {
        UserDefaults.standard.set("lb", forKey: "weightUnit")
        defer { UserDefaults.standard.set("kg", forKey: "weightUnit") }

        let original = InBodyPayload(
            weightKg: 80.0, skeletalMuscleMassKg: 38.0, bodyFatMassKg: 16.0,
            bodyFatPct: 20.0, totalBodyWaterL: 48.0, bmi: 24.0,
            basalMetabolicRate: 1800,
            rightArmLeanKg: 3.5
        )
        let scan = Scan(date: Date(), type: .inBody, source: .manual,
                        payload: try JSONEncoder().encode(original))
        context.insert(scan)
        try context.save()

        let vm = ScanEntryViewModel(modelContext: context)
        vm.loadForEdit(scan: scan, payload: original, massPref: "lb")
        // Form field should display lb (80 kg → ~176.37 lb), but without
        // the user mutating anything, saving must round-trip back to 80 kg.
        try vm.save()

        let reloaded = try context.fetch(FetchDescriptor<Scan>()).first!
        if case .inBody(let saved) = try reloaded.decoded() {
            XCTAssertEqual(saved.weightKg, 80.0, accuracy: 0.01,
                           "Stored weight must round-trip in kg regardless of display unit")
            XCTAssertEqual(saved.skeletalMuscleMassKg, 38.0, accuracy: 0.01)
            XCTAssertEqual(saved.bodyFatMassKg, 16.0, accuracy: 0.01)
            XCTAssertEqual(saved.rightArmLeanKg ?? 0, 3.5, accuracy: 0.01)
        } else {
            XCTFail("Expected inBody payload")
        }
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineTests/ScanEntryViewModelTests -quiet`

Expected: FAIL — new tests fail because `save()` always inserts; `existingScanForSelectedDate()` doesn't exclude `editingScan`.

- [ ] **Step 3: Modify `existingScanForSelectedDate` to exclude the editing scan**

In `Baseline/ViewModels/ScanEntryViewModel.swift`, replace the existing `existingScanForSelectedDate()` method:

```swift
    /// Check if a scan already exists for the selected date.
    /// In edit mode, excludes the scan being edited so it never flags itself.
    func existingScanForSelectedDate() -> Scan? {
        let targetDate = Calendar.current.startOfDay(for: scanDate ?? Date())
        let editingId = editingScan?.id
        let descriptor = FetchDescriptor<Scan>(
            predicate: #Predicate { scan in
                scan.date == targetDate && scan.id != editingId
            }
        )
        return try? modelContext.fetch(descriptor).first
    }
```

Note: `#Predicate` handles an optional `UUID?` captured as `editingId` — when nil, the `scan.id != editingId` clause is trivially true (since scan.id is non-optional UUID, it can never equal nil), preserving original behavior for the entry flow.

- [ ] **Step 4: Modify `save()` to branch on edit mode**

In `Baseline/ViewModels/ScanEntryViewModel.swift`, replace the existing `save()` method:

```swift
    func save() throws {
        let payload = try buildPayload()
        let data = try JSONEncoder().encode(payload)
        let targetDate = Calendar.current.startOfDay(for: scanDate ?? Date())

        // Delete any OTHER scan already on the target date — excludes self in edit mode.
        if let conflict = existingScanForSelectedDate() {
            modelContext.delete(conflict)
        }

        if let editing = editingScan {
            editing.payloadData = data
            editing.date = targetDate
            editing.scanType = selectedType
            editing.scanSource = selectedSource
            editing.updatedAt = Date()
        } else {
            let scan = Scan(date: targetDate, type: selectedType, source: selectedSource, payload: data)
            modelContext.insert(scan)
        }
        try modelContext.save()
    }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BaselineTests/ScanEntryViewModelTests -quiet`

Expected: PASS — all new tests pass and `testSaveCreatesValidScan` / `testSaveThrowsWhenMissingRequiredFields` still pass.

- [ ] **Step 6: Commit**

```bash
git add Baseline/ViewModels/ScanEntryViewModel.swift BaselineTests/ViewModels/ScanEntryViewModelTests.swift
git commit -m "$(cat <<'EOF'
feat(scan-entry): edit-aware save() updates in place and excludes self from conflict check

When editingScan is non-nil, save() now updates the existing Scan
(payload, date, type, source, updatedAt) and deletes any OTHER scan
on the target date. existingScanForSelectedDate() excludes the scan
being edited so it never reports itself as a conflict.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Swap formHeader title in edit mode

**Files:**
- Modify: `Baseline/Views/Body/ScanEntryFlow.swift:819-867` (manualFormStep) and `:871-895` (formHeader)

- [ ] **Step 1: Update `manualFormStep` to pass an edit-aware title**

In `Baseline/Views/Body/ScanEntryFlow.swift`, replace the `formHeader` line in `manualFormStep` (line 823):

From:

```swift
                formHeader(title: "New Scan", vm: vm)
```

To:

```swift
                formHeader(title: vm.editingScan == nil ? "New Scan" : "Edit Scan", vm: vm)
```

- [ ] **Step 2: Verify `ScanEntryFlow` still compiles**

Run: `xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`

Expected: BUILD SUCCEEDED. (The three `ScanEntrySnapshotTests` are currently skipped per issue #10 while the UI iterates pre-beta — they would have exercised this change visually but the pattern is gated behind a manual regen ritual at beta.)

- [ ] **Step 3: Commit**

```bash
git add Baseline/Views/Body/ScanEntryFlow.swift
git commit -m "$(cat <<'EOF'
feat(scan-entry): manual form header switches to "Edit Scan" when editing

Sets up the next step — ScanEditView re-hosting ScanEntryFlow to
reuse the manual form layout.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Collapse `ScanEditView` into a thin wrapper

**Files:**
- Modify: `Baseline/Views/Body/ScanDetailView.swift:268-755`

- [ ] **Step 1: Replace the whole `ScanEditView` struct with a wrapper**

In `Baseline/Views/Body/ScanDetailView.swift`, replace everything from `// MARK: - Scan Edit View` (line 268) through the end of the `ScanEditView` struct (the closing brace on line 755) with:

```swift
// MARK: - Scan Edit View

/// Edit sheet for an existing scan. Renders the same manual form used for new
/// scans by seeding a `ScanEntryViewModel` with the scan's payload and letting
/// `ScanEntryFlow` drive the UI. Unit conversion, save, and overwrite handling
/// all live in the view model so entry and edit can never visually drift.
struct ScanEditView: View {
    @Environment(\.modelContext) private var modelContext

    let scan: Scan
    let payload: InBodyPayload

    @State private var vm: ScanEntryViewModel?

    var body: some View {
        Group {
            if let vm {
                ScanEntryFlow(viewModel: vm)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if vm == nil {
                let pref = UserDefaults.standard.string(forKey: "weightUnit") ?? "lb"
                let newVM = ScanEntryViewModel(modelContext: modelContext)
                newVM.loadForEdit(scan: scan, payload: payload, massPref: pref)
                vm = newVM
            }
        }
    }
}
```

- [ ] **Step 2: Build the app to verify compilation**

Run: `xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`

Expected: BUILD SUCCEEDED. Swift will flag any leftover references to removed helpers (`editableDate`, `editFormFields`, etc.).

- [ ] **Step 3: Manual smoke test — Edit flow renders the unified layout**

Open the app in the iOS Simulator (iPhone 17 Pro):

```bash
xcrun simctl boot 07D86D44-EE5B-40F7-8F39-FFD48B2011DC 2>/dev/null
open -a Simulator
xcodebuild build -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData
xcrun simctl install 07D86D44-EE5B-40F7-8F39-FFD48B2011DC build/DerivedData/Build/Products/Debug-iphonesimulator/Baseline.app
xcrun simctl launch 07D86D44-EE5B-40F7-8F39-FFD48B2011DC com.cadre.baseline
```

Then:
1. Open Body tab → History → tap an existing scan → ellipsis → Edit.
2. Confirm the edit sheet now shows the same sections/rows/date chip as the "Enter manually" flow under New Scan.
3. Confirm the title reads "Edit Scan".
4. Change a value, tap Save — confirm the history updates and no duplicate scan is inserted.
5. Change the scan date to a day with another existing scan — confirm the overwrite alert fires and Save removes the other one.

Note any visual regressions. If the segmental tables or section labels look off, stop and diagnose — do not proceed.

- [ ] **Step 4: Commit**

```bash
git add Baseline/Views/Body/ScanDetailView.swift
git commit -m "$(cat <<'EOF'
refactor(scan-edit): unify layout by wrapping ScanEntryFlow

ScanEditView drops ~485 lines of duplicated form code and becomes a
thin wrapper that seeds a ScanEntryViewModel from the existing payload
and renders ScanEntryFlow in its manual-entry step. Edit and new-scan
entry now share one layout and can never visually drift.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Full verification

> **Note:** An earlier draft of this plan included a `testScanEdit_UsesManualFormLayout` snapshot test. That has been **deferred to issue #10** (re-enable view snapshots at beta) because (a) all view-level snapshots are currently skipped pre-beta due to simulator rendering drift, and (b) once `ScanEditView` literally renders via `ScanEntryFlow`, layout parity is code-level guaranteed — a snapshot doesn't add signal. When issue #10 is addressed at beta, add the edit-variant snapshot alongside the other view snapshots.

**Files:** none modified.

- [ ] **Step 1: Run the entire test suite**

Run: `xcodebuild test -project Baseline.xcodeproj -scheme Baseline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`

Expected: PASS — all BaselineTests, including snapshot tests, pass. No regressions.

- [ ] **Step 2: Manual smoke test — new-scan entry still works**

In the simulator:
1. Body tab → plus button → InBody 570 → Continue → Enter manually.
2. Confirm the form renders unchanged (title "New Scan", same sections, same styling).
3. Fill required fields, Save. Confirm a new scan appears in history.

- [ ] **Step 3: Manual smoke test — edit flow**

Repeat the Task 4 Step 3 smoke test in full. Change values, change dates, trigger an overwrite, and cancel out of the sheet. All behaviors should match the pre-refactor edit flow.

- [ ] **Step 4: Review git diff**

Run: `git log --oneline main..HEAD`

Expected: 4 commits (one per Tasks 1-4) plus the pre-refactor cleanup commit. All messages clear and scoped.

Run: `git diff --stat main..HEAD`

Expected: net reduction of ~400 lines (the lost ScanEditView body, minus the new wrapper and VM additions).

---

## Self-Review Checklist

- [x] Spec coverage: three differences identified (header, sections, segmental rows). All three resolved by rendering both flows through `ScanEntryFlow.manualFormStep`.
- [x] No placeholders — every step has runnable code or commands.
- [x] Type consistency: `loadForEdit`, `editingScan`, `existingScanForSelectedDate`, `save()`, `ScanEditView` names match across tasks.
- [x] Snapshot strategy: view-level snapshot parity deferred to issue #10 (re-enable at beta); code-level parity is guaranteed because `ScanEditView` renders through `ScanEntryFlow`'s manual form directly.
- [x] Rollback safety: each task commits independently. If Task 4's manual test reveals a visual regression, the earlier tasks (VM changes + tests) remain valuable groundwork and can ship behind a feature flag or be reverted with a single `git reset`.
