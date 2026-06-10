import XCTest

/// End-to-end onboarding walk. -UITestShowOnboarding forces the flow under
/// UI testing AND clears the completion flag + name at launch (see
/// BaselineApp.init), so each test starts from a clean first-launch state.
@MainActor
final class OnboardingFlowUITests: BaseUITestCase {
    override var extraLaunchArguments: [String] { ["-UITestShowOnboarding"] }

    func testCompleteOnboardingWithNameLandsOnMainTabs() {
        let getStarted = app.buttons[A11yID.Onboarding.getStarted]
        XCTAssertTrue(getStarted.waitForExistence(timeout: Self.defaultTimeout),
                      "Welcome page should present on forced-onboarding launch")
        getStarted.tap()

        let nameField = app.textFields[A11yID.Onboarding.nameField]
        XCTAssertTrue(nameField.waitForExistence(timeout: Self.defaultTimeout))
        nameField.tap()
        nameField.typeText("Ben")
        app.buttons[A11yID.Onboarding.continueButton].tap()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: Self.defaultTimeout),
                      "Completing onboarding should land on the main tab bar")
    }

    func testSkipForNowLandsOnMainTabs() {
        let skip = app.buttons[A11yID.Onboarding.skipForNow]
        XCTAssertTrue(skip.waitForExistence(timeout: Self.defaultTimeout))
        skip.tap()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: Self.defaultTimeout),
                      "Skipping onboarding should land on the main tab bar")
    }

    func testSkipOnNamePageLandsOnMainTabs() {
        let getStarted = app.buttons[A11yID.Onboarding.getStarted]
        XCTAssertTrue(getStarted.waitForExistence(timeout: Self.defaultTimeout))
        getStarted.tap()

        let skipName = app.buttons[A11yID.Onboarding.skipName]
        XCTAssertTrue(skipName.waitForExistence(timeout: Self.defaultTimeout))
        skipName.tap()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: Self.defaultTimeout),
                      "Skipping on the name page should land on the main tab bar")
    }
}
