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
        // `.accessibilityIdentifier` on a plain HStack creates an otherElement but
        // it may need to be queried via descendants(matching:) if not directly in
        // app.otherElements. We verify Settings loaded by waiting for any element
        // carrying the identifier, falling back to the navigation bar title.
        let unitToggle = app.descendants(matching: .any).matching(identifier: A11yID.Settings.unitToggle).firstMatch
        let settingsNavBar = app.navigationBars["Settings"]
        XCTAssertTrue(
            unitToggle.waitForExistence(timeout: 5) || settingsNavBar.waitForExistence(timeout: 5),
            "Settings screen should appear (unit toggle or nav bar)"
        )
        app.navigationBars.buttons.element(boundBy: 0).tap() // back

        app.buttons[A11yID.Now.historyButton].tap()
        // SwiftUI List with .insetGrouped may surface as collectionView, table, or otherElement.
        // We also try descendants(matching:) for any element type bearing the identifier.
        let historyList = app.descendants(matching: .any).matching(identifier: A11yID.History.list).firstMatch
        XCTAssertTrue(
            historyList.waitForExistence(timeout: 5)
            || app.collectionViews[A11yID.History.list].exists
            || app.tables[A11yID.History.list].exists
            || app.otherElements[A11yID.History.list].exists,
            "History list should appear"
        )
    }
}
