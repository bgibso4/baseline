import SwiftUI
import SwiftData

/// Settings screen — 7 grouped sections matching `settings-v1-2026-04-05.html`.
///
/// Navigation: pushed from gear icon on NowView. Each row either pushes a
/// sub-screen, toggles inline, or opens an external link.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var vm: SettingsViewModel
    @State private var showDeleteConfirmation = false

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
                    SettingsHealthSection()
                    aboutSection
                    resetSection
                    #if DEBUG
                    SettingsDeveloperSection()
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
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(CadreColors.textPrimary)
                    .tracking(-0.1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer()
                SegmentedToggle(
                    options: ["lb", "kg"],
                    selection: Binding(
                        get: { vm.weightUnit },
                        set: { vm.weightUnit = $0 }
                    )
                )
                .accessibilityIdentifier(A11yID.Settings.unitToggle)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            SettingsDivider()

            HStack(spacing: 14) {
                SettingsRowIcon(systemName: "ruler", tint: .accent)
                Text("Measurements")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(CadreColors.textPrimary)
                    .tracking(-0.1)
                    // lineLimit + minimumScaleFactor prevent the "text clipped"
                    // predictive DT audit failure at large Dynamic Type sizes.
                    // 0.6 allows sufficient scale-down given the SegmentedToggle
                    // occupies roughly half the available HStack width.
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer()
                SegmentedToggle(
                    options: ["in", "cm"],
                    selection: Binding(
                        get: { vm.lengthUnit },
                        set: { vm.lengthUnit = $0 }
                    )
                )
                .accessibilityIdentifier(A11yID.Settings.lengthToggle)
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
            .accessibilityIdentifier(A11yID.Settings.exportCSV)
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
            .accessibilityIdentifier(A11yID.Settings.importCSV)
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
            Link(destination: URL(string: "https://bgibso4.github.io/baseline/privacy/")!) {
                SettingsRow(
                    icon: "shield",
                    label: "Privacy Policy",
                    value: nil,
                    style: .externalLink
                )
            }
            .accessibilityIdentifier(A11yID.Settings.privacyLink)
            SettingsDivider()
            Link(destination: URL(string: "https://bgibso4.github.io/baseline/terms/")!) {
                SettingsRow(
                    icon: "doc.text",
                    label: "Terms of Service",
                    value: nil,
                    style: .externalLink
                )
            }
            .accessibilityIdentifier(A11yID.Settings.termsLink)
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
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: [WeightEntry.self, Scan.self, Measurement.self, SyncState.self], inMemory: true)
}
