#if DEBUG
import SwiftUI
import SwiftData

/// DEBUG-only Developer section — load realistic sample data or wipe
/// everything for preview/testing. The whole file is `#if DEBUG`-gated so it
/// doesn't reach release builds.
struct SettingsDeveloperSection: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showLoadConfirm = false
    @State private var showClearConfirm = false

    var body: some View {
        SettingsSectionView(title: "DEVELOPER") {
            Button {
                showLoadConfirm = true
            } label: {
                SettingsRow(
                    icon: "flask",
                    label: "Load Test Data",
                    value: nil,
                    style: .action
                )
            }
            SettingsDivider()
            Button {
                showClearConfirm = true
            } label: {
                SettingsRow(
                    icon: "xmark.bin",
                    label: "Clear All Data",
                    value: nil,
                    style: .danger
                )
            }
            SettingsDivider()
            Button {
                // Clearing the flag flips BaselineApp's @AppStorage-driven
                // root back to OnboardingFlow immediately.
                UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
            } label: {
                SettingsRow(
                    icon: "sparkles",
                    label: "Show Onboarding Again",
                    value: nil,
                    style: .action
                )
            }
            .accessibilityIdentifier(A11yID.Settings.showOnboardingAgain)

            Text("Debug build only. Load realistic sample data to preview the app.")
                .font(.caption)
                .foregroundStyle(CadreColors.textTertiary)
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 4)
        }
        .confirmationDialog(
            "Load test data?",
            isPresented: $showLoadConfirm,
            titleVisibility: .visible
        ) {
            Button("Load Test Data") {
                TestDataSeeder.seed(context: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will replace all existing data with sample entries.")
        }
        .confirmationDialog(
            "Clear all data?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear Everything", role: .destructive) {
                TestDataSeeder.clearAll(context: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all weight entries, scans, and measurements.")
        }
    }
}
#endif
