import Foundation
import Observation

/// Drives the first-launch onboarding flow: holds the name draft and performs
/// the completion writes. Views stay logic-free; tests inject a scratch
/// UserDefaults suite. `BaselineApp` observes "hasCompletedOnboarding" via
/// @AppStorage, so writing the flag here is what dismisses the flow.
@Observable
final class OnboardingViewModel {
    private let defaults: UserDefaults

    var draftName: String = ""

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// "Continue" on the name page: persist a non-empty trimmed name, then finish.
    /// A blank draft behaves exactly like Skip — no empty-string name is stored.
    func completeSavingName() {
        let trimmed = draftName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            defaults.set(trimmed, forKey: "userName")
        }
        complete()
    }

    /// Any skip path: finish without writing a name.
    func complete() {
        defaults.set(true, forKey: "hasCompletedOnboarding")
    }
}
