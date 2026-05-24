import XCTest

/// UI test for the manual scan-entry happy path.
///
/// Real flow (5 steps):
///   1. selectType  — "New Scan / Step 1 of 2", InBody 570 pre-selected, tap "Continue"
///   2. selectMethod — "New Scan / Step 2 of 2", tap "Enter manually" card
///   3. manualEntry  — long form; fill the 7 required fields (canSave gate),
///                     tap Save → fullScreenCover dismisses → Body tab reappears.
///
/// canSave requires all seven to be non-empty:
///   weightKg, skeletalMuscleMassKg, bodyFatMassKg, bodyFatPct,
///   totalBodyWaterL, bmi, basalMetabolicRate.
/// Only weightKg and bodyFatPct had A11yIDs previously; five more were added
/// (additive-only) to allow the test to fill all required fields.
@MainActor
final class ScanEntryFlowUITests: BaseUITestCase {

    func testManualScanEntrySaves() {
        tapTab(A11yID.TabBar.body)

        // Tap the scan affordance (+ button in the Body Composition section header).
        let scanBtn = app.buttons[A11yID.Body.scanButton]
        XCTAssertTrue(scanBtn.waitForExistence(timeout: Self.defaultTimeout))
        scanBtn.tap()

        // ── Step 1: selectType ───────────────────────────────────────────────
        // InBody 570 is pre-selected. Tap "Continue" to proceed.
        let continueBtn = app.buttons[A11yID.ScanEntry.continueButton]
        XCTAssertTrue(continueBtn.waitForExistence(timeout: Self.defaultTimeout))
        continueBtn.tap()

        // ── Step 2: selectMethod ─────────────────────────────────────────────
        let manual = app.buttons[A11yID.ScanEntry.manualEntryButton]
        XCTAssertTrue(manual.waitForExistence(timeout: Self.defaultTimeout))
        manual.tap()

        // ── Step 5: manualEntry form ─────────────────────────────────────────
        // Fill all seven required fields so canSave becomes true.

        fillField(A11yID.ScanEntry.weightField, value: "190")
        fillField(A11yID.ScanEntry.skeletalMuscleMassField, value: "85")
        fillField(A11yID.ScanEntry.bodyFatMassField, value: "30")
        fillField(A11yID.ScanEntry.bodyFatField, value: "18.5")
        fillField(A11yID.ScanEntry.totalBodyWaterField, value: "110")
        fillField(A11yID.ScanEntry.bmiField, value: "24.5")
        fillField(A11yID.ScanEntry.basalMetabolicRateField, value: "1800")

        // Save — may show an overwrite alert if a scan already exists for today.
        let saveBtn = app.buttons[A11yID.ScanEntry.save]
        XCTAssertTrue(saveBtn.waitForExistence(timeout: Self.defaultTimeout))
        saveBtn.tap()

        // Handle the "Replace Existing Scan?" alert if the seed has a today entry.
        let replaceBtn = app.buttons["Replace"].firstMatch
        if replaceBtn.waitForExistence(timeout: 3) {
            replaceBtn.tap()
        }

        // fullScreenCover dismisses → scan affordance on Body tab reappears.
        XCTAssertTrue(
            app.buttons[A11yID.Body.scanButton].waitForExistence(timeout: Self.defaultTimeout),
            "Expected to return to Body tab after saving a scan"
        )
    }

    // MARK: - Helpers

    /// Tap a text field by its accessibility identifier and type the given text.
    /// Scrolls to reveal the field before tapping when it is offscreen.
    private func fillField(_ identifier: String, value: String) {
        let field = app.textFields[identifier]
        if !field.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(
            field.waitForExistence(timeout: Self.defaultTimeout),
            "Text field '\(identifier)' not found"
        )
        field.tap()
        field.typeText(value)
    }
}
