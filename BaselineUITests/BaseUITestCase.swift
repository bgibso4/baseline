import XCTest

@MainActor
class BaseUITestCase: XCTestCase {
    var app: XCUIApplication!

    /// Default wait used for element existence checks.
    static let defaultTimeout: TimeInterval = 5

    /// Override per subclass to pick the seed fixture.
    var seedProfile: SeedProfile { .populated }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-UITestSeed", seedProfile.rawValue]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// Pop the current pushed screen via the leading nav-bar button.
    /// Assumes a standard pushed screen whose back button is the first nav-bar button.
    func goBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    /// Tap the tab bar item for the given identifier.
    ///
    /// SwiftUI's `.accessibilityIdentifier()` on a tab content view does NOT
    /// propagate to the tab bar button in XCTest — the buttons only expose
    /// their visible label text. We therefore match by the tab's display
    /// label via an explicit map, falling back to a direct identifier lookup
    /// in case the behaviour changes in a future OS version.
    func tapTab(_ identifier: String) {
        let byLabel = app.tabBars.firstMatch.buttons[tabLabel(for: identifier)]
        if byLabel.waitForExistence(timeout: Self.defaultTimeout) {
            byLabel.tap(); return
        }
        let byID = app.buttons[identifier]
        if byID.exists { byID.tap(); return }
        XCTFail("Tab \(identifier) not found by label or identifier")
    }

    /// Map a tab A11yID constant to its visible display label.
    /// Using an explicit map avoids locale-dependent `.capitalized` derivation.
    private func tabLabel(for identifier: String) -> String {
        switch identifier {
        case A11yID.TabBar.trends: return "Trends"
        case A11yID.TabBar.now: return "Now"
        case A11yID.TabBar.body: return "Body"
        default: return identifier
        }
    }
}
