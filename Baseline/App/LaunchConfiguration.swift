import Foundation

/// Deterministic seed datasets selectable from the launch arguments.
enum SeedProfile: String {
    case empty
    case populated
    case goalActive
}

/// Parses launch arguments and environment once into typed test-mode flags.
/// `current` is the process-wide value; tests construct their own instances.
struct LaunchConfiguration {
    let isUITesting: Bool
    let seedProfile: SeedProfile
    let shouldDisableAnimations: Bool
    /// UI-test override: present onboarding even though `-UITestMode`
    /// normally suppresses it. Used only by OnboardingFlowUITests.
    let forceOnboarding: Bool

    init(arguments: [String], environment: [String: String]) {
        let uiTesting = arguments.contains("-UITestMode")
        self.isUITesting = uiTesting
        self.forceOnboarding = arguments.contains("-UITestShowOnboarding")

        // -UITestSeed <value>; default to .populated under UI testing.
        var profile: SeedProfile = .populated
        if let idx = arguments.firstIndex(of: "-UITestSeed"),
           idx + 1 < arguments.count,
           let parsed = SeedProfile(rawValue: arguments[idx + 1]) {
            profile = parsed
        }
        self.seedProfile = profile

        let unitTesting = environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
        self.shouldDisableAnimations = uiTesting || unitTesting
    }

    static let current = LaunchConfiguration(
        arguments: ProcessInfo.processInfo.arguments,
        environment: ProcessInfo.processInfo.environment
    )
}
