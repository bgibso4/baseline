import XCTest

/// UI test for the CSV import flow.
///
/// Real flow:
///   Settings is pushed from NowView's gear toolbar button. "Import from CSV"
///   is a NavigationLink (A11yID.Settings.importCSV) that pushes ImportCSVView
///   — a fully in-app screen (not a system picker). The screen has a nav bar
///   titled "Import" and a "Choose CSV file" button (A11yID.Settings.importChooseFile)
///   that triggers a system fileImporter sheet. We stop at the in-app screen
///   and assert the "Choose CSV file" button is present — deterministic without
///   driving the system document picker.
///
///   Full CSV row-import logic is already covered by CSVImporterTests (logic suite).
@MainActor
final class CSVImportFlowUITests: BaseUITestCase {
    override var seedProfile: SeedProfile { .empty }

    func testImportAffordancePresentsPicker() {
        tapTab(A11yID.TabBar.now)

        // Open Settings from NowView's toolbar gear button.
        let settingsBtn = app.buttons[A11yID.Now.settingsButton]
        XCTAssertTrue(settingsBtn.waitForExistence(timeout: Self.defaultTimeout))
        settingsBtn.tap()

        // Tap the "Import from CSV" NavigationLink in the DATA section.
        let importLink = app.buttons[A11yID.Settings.importCSV]
        XCTAssertTrue(
            importLink.waitForExistence(timeout: Self.defaultTimeout),
            "Import from CSV row should be visible in Settings"
        )
        importLink.tap()

        // ImportCSVView is now pushed. The nav bar title is rendered via a
        // ToolbarItem(placement: .principal) Text view — XCUITest doesn't index
        // that into navigationBars["Import"]. Instead assert on the screen's
        // primary CTA button, which only exists on the import screen.
        let chooseFileBtn = app.buttons[A11yID.Settings.importChooseFile]
        XCTAssertTrue(
            chooseFileBtn.waitForExistence(timeout: Self.defaultTimeout),
            "'Choose CSV file' button should be visible on the Import screen"
        )
    }
}
