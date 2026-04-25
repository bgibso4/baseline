import SwiftUI
import SwiftData
import HealthKit
import UIKit

/// Settings screen — 7 grouped sections matching `settings-v1-2026-04-05.html`.
///
/// Navigation: pushed from gear icon on NowView. Each row either pushes a
/// sub-screen, toggles inline, or opens an external link.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var vm: SettingsViewModel
    @State private var showDeleteConfirmation = false
    @State private var healthKitStatus: HKAuthorizationStatus = .notDetermined
    #if DEBUG
    @State private var showLoadConfirm = false
    @State private var showClearConfirm = false
    #endif

    init(viewModel: SettingsViewModel? = nil) {
        self._vm = State(initialValue: viewModel ?? SettingsViewModel())
    }

    var body: some View {
        ZStack {
            GradientBackground(center: .top)

            ScrollView {
                VStack(spacing: 0) {
                    profileSection
                    unitsSection
                    appearanceSection
                    dataSection
                    healthSection
                    aboutSection
                    resetSection
                    #if DEBUG
                    developerSection
                    #endif
                }
                .padding(.bottom, CadreSpacing.xl)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CadreColors.bgGradientCenter, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Settings")
                    .font(.custom("Exo 2", size: 17, relativeTo: .headline).weight(.bold))
                    .foregroundStyle(CadreColors.textPrimary)
                    .tracking(-0.2)
            }
        }
        .confirmationDialog(
            "Delete all data?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete everything", role: .destructive) {
                vm.deleteAllData(modelContext: modelContext)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This is permanent. Your data cannot be recovered.")
        }
        #if DEBUG
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
        #endif
        .onAppear(perform: refreshHealthKitStatus)
    }

    // MARK: - HealthKit Status

    /// Query the write-auth status for a representative type we actually save
    /// (bodyMass). HealthKit deliberately won't tell you *read* status, but
    /// write status is accurate and mirrors the user's consent.
    private func refreshHealthKitStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            healthKitStatus = .sharingDenied // treat as unavailable for the UI
            return
        }
        healthKitStatus = HKHealthStore().authorizationStatus(for: HKQuantityType(.bodyMass))
    }

    private func handleHealthRowTap() {
        switch healthKitStatus {
        case .notDetermined:
            Task {
                await HealthKitManager.requestAuthorizationIfNeeded()
                await MainActor.run { refreshHealthKitStatus() }
            }
        case .sharingDenied:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        default:
            break
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        SettingsSectionView(title: "PROFILE") {
            NavigationLink {
                NameEditView(viewModel: vm)
            } label: {
                SettingsRow(
                    icon: "person",
                    label: "Name",
                    value: vm.name.isEmpty ? nil : vm.name,
                    style: .push
                )
            }
            SettingsDivider()
            NavigationLink {
                HeightPickerView(viewModel: vm)
            } label: {
                SettingsRow(
                    icon: "arrow.up.and.down",
                    label: "Height",
                    value: vm.heightDisplay.isEmpty ? nil : vm.heightDisplay,
                    style: .push
                )
            }
            SettingsDivider()
            NavigationLink {
                BirthdayPickerView(viewModel: vm)
            } label: {
                SettingsRow(
                    icon: "clock",
                    label: "Age",
                    value: vm.ageDisplay.isEmpty ? nil : vm.ageDisplay,
                    style: .push
                )
            }
            SettingsDivider()
            NavigationLink {
                GenderPickerView(viewModel: vm)
            } label: {
                SettingsRow(
                    icon: "person",
                    label: "Gender",
                    value: vm.genderDisplay.isEmpty ? nil : vm.genderDisplay,
                    style: .push
                )
            }
        }
    }

    // MARK: - Units Section

    private var unitsSection: some View {
        SettingsSectionView(title: "UNITS") {
            HStack(spacing: 14) {
                SettingsRowIcon(systemName: "equal", tint: .accent)
                Text("Weight")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CadreColors.textPrimary)
                    .tracking(-0.1)
                Spacer()
                SegmentedToggle(
                    options: ["lb", "kg"],
                    selection: Binding(
                        get: { vm.weightUnit },
                        set: { vm.weightUnit = $0 }
                    )
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            SettingsDivider()

            HStack(spacing: 14) {
                SettingsRowIcon(systemName: "ruler", tint: .accent)
                Text("Measurements")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CadreColors.textPrimary)
                    .tracking(-0.1)
                Spacer()
                SegmentedToggle(
                    options: ["in", "cm"],
                    selection: Binding(
                        get: { vm.lengthUnit },
                        set: { vm.lengthUnit = $0 }
                    )
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        SettingsSectionView(title: "APPEARANCE") {
            NavigationLink {
                ThemePickerView(viewModel: vm)
            } label: {
                SettingsRow(
                    icon: "moon.fill",
                    label: "Theme",
                    value: vm.theme.displayName,
                    style: .push
                )
            }
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        SettingsSectionView(title: "DATA") {
            NavigationLink {
                ExportCSVView(viewModel: vm)
            } label: {
                SettingsRow(
                    icon: "arrow.down.doc",
                    label: "Export to CSV",
                    value: nil,
                    style: .action
                )
            }
            SettingsDivider()
            NavigationLink {
                ImportCSVView()
            } label: {
                SettingsRow(
                    icon: "arrow.up.doc",
                    label: "Import from CSV",
                    value: nil,
                    style: .action
                )
            }
        }
    }

    // MARK: - Health Section

    @ViewBuilder
    private var healthSection: some View {
        if HKHealthStore.isHealthDataAvailable() {
            SettingsSectionView(title: "HEALTH") {
                Button(action: handleHealthRowTap) {
                    HStack(spacing: 14) {
                        SettingsRowIcon(
                            systemName: healthKitIcon,
                            tint: healthKitIconTint
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Health")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(CadreColors.textPrimary)
                                .tracking(-0.1)
                            Text(healthKitSubtitle)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(CadreColors.textTertiary)
                        }
                        Spacer()
                        Text(healthKitStatusLabel)
                            .font(.system(size: 10, weight: .bold))
                            .textCase(.uppercase)
                            .tracking(0.4)
                            .foregroundStyle(healthKitStatusColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                healthKitStatusColor.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 5)
                            )
                        if healthKitStatus != .sharingAuthorized {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(CadreColors.textTertiary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(healthKitStatus == .sharingAuthorized)
            }
        }
    }

    private var healthKitIcon: String {
        switch healthKitStatus {
        case .sharingAuthorized: return "heart.fill"
        case .sharingDenied: return "heart.slash"
        default: return "heart"
        }
    }

    private var healthKitIconTint: SettingsIconTint {
        switch healthKitStatus {
        case .sharingAuthorized: return .success
        case .sharingDenied: return .danger
        default: return .accent
        }
    }

    private var healthKitStatusLabel: String {
        switch healthKitStatus {
        case .sharingAuthorized: return "Connected"
        case .sharingDenied: return "Denied"
        default: return "Not set"
        }
    }

    private var healthKitStatusColor: Color {
        switch healthKitStatus {
        case .sharingAuthorized: return CadreColors.success
        case .sharingDenied: return CadreColors.danger
        default: return CadreColors.textSecondary
        }
    }

    private var healthKitSubtitle: String {
        switch healthKitStatus {
        case .sharingAuthorized: return "Baseline is syncing to Apple Health."
        case .sharingDenied: return "Tap to enable in Settings."
        default: return "Tap to allow Baseline to write your metrics."
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        SettingsSectionView(title: "ABOUT") {
            SettingsRow(
                icon: "info.circle",
                label: "Version",
                value: vm.versionString,
                style: .info
            )
            SettingsDivider()
            Link(destination: URL(string: "https://baseline.app/privacy")!) {
                SettingsRow(
                    icon: "shield",
                    label: "Privacy Policy",
                    value: nil,
                    style: .externalLink
                )
            }
            SettingsDivider()
            Link(destination: URL(string: "https://baseline.app/terms")!) {
                SettingsRow(
                    icon: "doc.text",
                    label: "Terms of Service",
                    value: nil,
                    style: .externalLink
                )
            }
        }
    }

    // MARK: - Reset Section

    private var resetSection: some View {
        SettingsSectionView(title: "RESET") {
            Button {
                showDeleteConfirmation = true
            } label: {
                SettingsRow(
                    icon: "trash",
                    label: "Delete all data",
                    value: nil,
                    style: .danger
                )
            }
        }
    }

    // MARK: - Developer Section (DEBUG only)

    #if DEBUG
    private var developerSection: some View {
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

            Text("Debug build only. Load realistic sample data to preview the app.")
                .font(.system(size: 11))
                .foregroundStyle(CadreColors.textTertiary)
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 4)
        }
    }
    #endif
}

// MARK: - Supporting Components

/// Row display style determines trailing accessory.
enum SettingsRowStyle {
    case push
    /// Push row that is an action (no "Not set" fallback when value is nil).
    case action
    case info
    case externalLink
    case danger
    case badge(String)
}

/// Tint override for row icons.
enum SettingsIconTint {
    case accent
    case secondary
    case success
    case danger
}

/// Reusable settings row — icon + label + optional value + trailing accessory.
struct SettingsRow: View {
    let icon: String
    let label: String
    let value: String?
    let style: SettingsRowStyle
    var iconTint: SettingsIconTint = .accent

    var body: some View {
        HStack(spacing: 14) {
            SettingsRowIcon(systemName: icon, tint: iconTint)

            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(style.labelColor)
                .tracking(-0.1)

            Spacer()

            // Value or trailing accessory
            switch style {
            case .push:
                if let value {
                    Text(value)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CadreColors.textSecondary)
                } else {
                    Text("Not set")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CadreColors.textTertiary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CadreColors.textTertiary)

            case .action:
                if let value {
                    Text(value)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CadreColors.textSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CadreColors.textTertiary)

            case .info:
                if let value {
                    Text(value)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CadreColors.textSecondary)
                }

            case .externalLink:
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CadreColors.textTertiary)

            case .danger:
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CadreColors.danger.opacity(0.6))

            case .badge(let text):
                Text(text)
                    .font(.system(size: 10, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .foregroundStyle(CadreColors.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(CadreColors.cardElevated, in: RoundedRectangle(cornerRadius: 5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

private extension SettingsRowStyle {
    var labelColor: Color {
        switch self {
        case .danger: return CadreColors.danger
        default: return CadreColors.textPrimary
        }
    }
}

/// 28pt rounded-rect icon container matching the mockup `.row .row-icon`.
struct SettingsRowIcon: View {
    let systemName: String
    var tint: SettingsIconTint = .accent

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(tint.color)
            .frame(width: 28, height: 28)
            .background(CadreColors.cardElevated, in: RoundedRectangle(cornerRadius: 8))
    }
}

private extension SettingsIconTint {
    var color: Color {
        switch self {
        case .accent: return CadreColors.accent
        case .secondary: return Color(hex: "B89968")
        case .success: return Color(hex: "8FA880")
        case .danger: return CadreColors.danger
        }
    }
}

/// Section container with uppercase label and glass card background.
struct SettingsSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(CadreColors.textTertiary)
                .textCase(.uppercase)
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                content
            }
            .clipShape(RoundedRectangle(cornerRadius: CadreRadius.md))
            .glassCard()
            .padding(.horizontal, 16)
        }
    }
}

/// Thin divider matching `.divider` mockup token.
struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(CadreColors.divider)
            .frame(height: 0.5)
            .padding(.leading, 50) // icon width (28) + gap (14) + inner padding (8)
    }
}

/// Inline segmented toggle for lb/kg, in/cm.
struct SegmentedToggle: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 1) {
            ForEach(options, id: \.self) { option in
                Text(option)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selection == option ? .white : CadreColors.textSecondary)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selection == option ? CadreColors.accent : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { selection = option }
            }
        }
        .padding(2)
        .background(CadreColors.cardElevated, in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: [WeightEntry.self, Scan.self, Measurement.self, SyncState.self], inMemory: true)
}
