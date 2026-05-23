import XCTest

@MainActor
final class SmokeNavigationUITests: BaseUITestCase {
    func testLaunchesAndShowsNow() {
        // App defaults to the Now tab (AppState.selectedTab = .now).
        // The weigh-in button is the primary CTA on that screen.
        XCTAssertTrue(app.buttons[A11yID.Now.weighInButton].waitForExistence(timeout: 10))
    }

    func testNavigatesAllTabs() {
        tapTab(A11yID.TabBar.trends)
        XCTAssertTrue(app.buttons[A11yID.Trends.metricPicker].waitForExistence(timeout: 5))

        tapTab(A11yID.TabBar.body)
        XCTAssertTrue(app.buttons[A11yID.Body.scanButton].waitForExistence(timeout: 5))

        tapTab(A11yID.TabBar.now)
        XCTAssertTrue(app.buttons[A11yID.Now.weighInButton].waitForExistence(timeout: 5))
    }

    func testPushesSettingsAndHistoryFromNow() {
        tapTab(A11yID.TabBar.now)
        app.buttons[A11yID.Now.settingsButton].tap()

        // Settings.unitToggle is a SegmentedToggle (custom HStack), not a UISwitch.
        // Query directly via otherElements first; fall back to descendants(matching:) in case the
        // HStack surfaces under a different element type, then to the navigation bar title text.
        let unitToggle = app.otherElements[A11yID.Settings.unitToggle].firstMatch
        let unitToggleFallback = app.descendants(matching: .any)
            .matching(identifier: A11yID.Settings.unitToggle).firstMatch
        let settingsTitle = app.staticTexts["Settings"]
        XCTAssertTrue(
            unitToggle.waitForExistence(timeout: 5)
                || unitToggleFallback.exists
                || settingsTitle.waitForExistence(timeout: 5),
            "Settings screen should appear (unit toggle or nav bar)"
        )
        goBack()

        app.buttons[A11yID.Now.historyButton].tap()
        // SwiftUI List with .insetGrouped may surface as collectionView, table, or otherElement.
        let historyID = A11yID.History.list
        XCTAssertTrue(
            app.otherElements[historyID].waitForExistence(timeout: 5)
            || app.collectionViews[historyID].exists
            || app.tables[historyID].exists,
            "History list should appear"
        )
    }
}
