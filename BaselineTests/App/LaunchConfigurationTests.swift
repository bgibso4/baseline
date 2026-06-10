import XCTest
@testable import Baseline

final class LaunchConfigurationTests: XCTestCase {
    func testDefaultsWhenNoArgsOrEnv() {
        let config = LaunchConfiguration(arguments: ["/path/to/app"], environment: [:])
        XCTAssertFalse(config.isUITesting)
        XCTAssertFalse(config.shouldDisableAnimations)
    }

    func testUITestModeFlag() {
        let config = LaunchConfiguration(arguments: ["app", "-UITestMode"], environment: [:])
        XCTAssertTrue(config.isUITesting)
        XCTAssertTrue(config.shouldDisableAnimations)
        XCTAssertEqual(config.seedProfile, .populated, "UI-testing defaults to populated when no seed given")
    }

    func testSeedProfileParsing() {
        XCTAssertEqual(
            LaunchConfiguration(arguments: ["app", "-UITestMode", "-UITestSeed", "empty"], environment: [:]).seedProfile,
            .empty
        )
        XCTAssertEqual(
            LaunchConfiguration(arguments: ["app", "-UITestMode", "-UITestSeed", "goalActive"], environment: [:]).seedProfile,
            .goalActive
        )
    }

    func testUnknownSeedFallsBackToPopulated() {
        let config = LaunchConfiguration(arguments: ["app", "-UITestMode", "-UITestSeed", "bogus"], environment: [:])
        XCTAssertEqual(config.seedProfile, .populated)
    }

    func testUnitTestEnvDisablesAnimationsWithoutUITestMode() {
        let config = LaunchConfiguration(
            arguments: ["app"],
            environment: ["XCTestConfigurationFilePath": "/tmp/x.xctest"]
        )
        XCTAssertFalse(config.isUITesting, "Unit-test env is not UI testing")
        XCTAssertTrue(config.shouldDisableAnimations)
    }

    func testForceOnboardingFlagDefaultsToFalse() {
        let config = LaunchConfiguration(arguments: ["app", "-UITestMode"], environment: [:])
        XCTAssertFalse(config.forceOnboarding)
    }

    func testForceOnboardingFlagParsed() {
        let config = LaunchConfiguration(
            arguments: ["app", "-UITestMode", "-UITestShowOnboarding"], environment: [:])
        XCTAssertTrue(config.forceOnboarding)
    }
}
