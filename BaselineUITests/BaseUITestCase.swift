import XCTest

@MainActor
class BaseUITestCase: XCTestCase {
    var app: XCUIApplication!

    /// Override per subclass to pick the seed fixture.
    var seedProfile: String { "populated" }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-UITestSeed", seedProfile]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// Tap the tab bar item for the given identifier.
    ///
    /// SwiftUI's `.accessibilityIdentifier()` on a tab content view does NOT
    /// propagate to the tab bar button in XCTest — the buttons only expose
    /// their visible label text. We therefore match by the tab's display
    /// label ("Trends", "Now", "Body") derived from the last path component
    /// of the A11yID constant (e.g. "tab.trends" → "Trends"), falling back
    /// to a direct identifier lookup in case the behaviour changes in a
    /// future OS version.
    func tapTab(_ identifier: String) {
        // Derive the human-readable label from the identifier string.
        // e.g. "tab.trends" → "Trends", "tab.now" → "Now"
        let label = identifier.split(separator: ".").last.map { $0.capitalized } ?? identifier

        let tabBar = app.tabBars.firstMatch
        let byLabel = tabBar.buttons[label]
        let byID = app.buttons[identifier]

        if byLabel.waitForExistence(timeout: 5) {
            byLabel.tap()
        } else if byID.waitForExistence(timeout: 5) {
            byID.tap()
        } else {
            XCTFail("Tab '\(identifier)' (label: '\(label)') not found in tab bar")
        }
    }
}
