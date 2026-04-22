import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Name Edit

/// Sub-screen 01: Name text input with Cancel/Save nav bar.
struct NameEditView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: SettingsViewModel
    @State private var draft: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            GradientBackground(center: .top)

            VStack(alignment: .leading, spacing: 0) {
                // Text input card with accent border
                HStack {
                    TextField("", text: $draft)
                        .font(.custom("Exo 2", size: 18).weight(.semibold))
                        .foregroundStyle(CadreColors.textPrimary)
                        .tint(CadreColors.accent)
                        .autocorrectionDisabled()
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            viewModel.name = draft.trimmingCharacters(in: .whitespaces)
                            dismiss()
                        }

                    if !draft.isEmpty {
                        Button {
                            draft = ""
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(CadreColors.bg)
                                .frame(width: 20, height: 20)
                                .background(CadreColors.textTertiary, in: Circle())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(CadreColors.card, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(CadreColors.accent, lineWidth: 1)
                )
                .padding(.horizontal, 22)
                .padding(.top, 20)

                Text("Your name appears on widgets and export files.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(CadreColors.textTertiary)
                    .padding(.horizontal, 22)
                    .padding(.top, 10)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CadreColors.textSecondary)
            }
            ToolbarItem(placement: .principal) {
                Text("Name")
                    .font(.custom("Exo 2", size: 16).weight(.bold))
                    .foregroundStyle(CadreColors.textPrimary)
                    .tracking(-0.2)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    viewModel.name = draft.trimmingCharacters(in: .whitespaces)
                    dismiss()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CadreColors.accent)
            }
        }
        .toolbarBackground(CadreColors.bgGradientCenter, for: .navigationBar)
        .onAppear { draft = viewModel.name }
    }
}

// MARK: - Height Picker

/// Sub-screen 02: Dual wheel pickers (ft + in) or single cm picker.
struct HeightPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: SettingsViewModel

    @State private var draftFeet: Int = 5
    @State private var draftInches: Int = 10
    @State private var draftCm: Int = 170

    private var isMetric: Bool { viewModel.lengthUnit == "cm" }

    var body: some View {
        ZStack {
            GradientBackground(center: .top)

            VStack(spacing: 0) {
                if isMetric {
                    Picker("Centimeters", selection: $draftCm) {
                        ForEach(100...250, id: \.self) { cm in
                            Text("\(cm) cm")
                                .foregroundStyle(CadreColors.textPrimary)
                                .tag(cm)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 200)
                    .padding(.top, 16)
                } else {
                    HStack(spacing: 16) {
                        VStack(spacing: 8) {
                            Text("FEET")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.4)
                                .foregroundStyle(CadreColors.textTertiary)
                            Picker("Feet", selection: $draftFeet) {
                                ForEach(3...8, id: \.self) { ft in
                                    Text("\(ft)")
                                        .foregroundStyle(CadreColors.textPrimary)
                                        .tag(ft)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80, height: 180)
                        }

                        VStack(spacing: 8) {
                            Text("INCHES")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.4)
                                .foregroundStyle(CadreColors.textTertiary)
                            Picker("Inches", selection: $draftInches) {
                                ForEach(0...11, id: \.self) { inches in
                                    Text("\(inches)")
                                        .foregroundStyle(CadreColors.textPrimary)
                                        .tag(inches)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80, height: 180)
                        }
                    }
                    .padding(.top, 16)
                }

                Text("Used for BMR and SMI calculations on InBody scans.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(CadreColors.textTertiary)
                    .padding(.top, 20)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CadreColors.textSecondary)
            }
            ToolbarItem(placement: .principal) {
                Text("Height")
                    .font(.custom("Exo 2", size: 16).weight(.bold))
                    .foregroundStyle(CadreColors.textPrimary)
                    .tracking(-0.2)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if isMetric {
                        viewModel.heightCm = draftCm
                    } else {
                        viewModel.heightFeet = draftFeet
                        viewModel.heightInches = draftInches
                    }
                    dismiss()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CadreColors.accent)
            }
        }
        .toolbarBackground(CadreColors.bgGradientCenter, for: .navigationBar)
        .onAppear {
            draftFeet = viewModel.heightFeet > 0 ? viewModel.heightFeet : 5
            draftInches = viewModel.heightInches
            draftCm = viewModel.heightCm > 0 ? viewModel.heightCm : 170
        }
    }
}

// MARK: - Birthday Picker

/// Sub-screen 03: Graphical DatePicker with computed age card below.
struct BirthdayPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: SettingsViewModel
    @State private var draftDate: Date = Calendar.current.date(
        byAdding: .year, value: -30, to: Date()
    )!

    private var computedAge: Int {
        Calendar.current.dateComponents([.year], from: draftDate, to: Date()).year ?? 0
    }

    var body: some View {
        ZStack {
            GradientBackground(center: .top)

            VStack(spacing: 0) {
                DatePicker(
                    "Birthday",
                    selection: $draftDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(CadreColors.accent)
                .colorScheme(.dark)
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .labelsHidden()

                // Computed age card
                HStack {
                    Text("CURRENT AGE")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(CadreColors.textTertiary)
                        .textCase(.uppercase)
                    Spacer()
                    Text("\(computedAge) years")
                        .font(.custom("Exo 2", size: 20).weight(.bold))
                        .foregroundStyle(CadreColors.textPrimary)
                        .tracking(-0.2)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(CadreColors.card, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 22)
                .padding(.top, 16)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CadreColors.textSecondary)
            }
            ToolbarItem(placement: .principal) {
                Text("Birthday")
                    .font(.custom("Exo 2", size: 16).weight(.bold))
                    .foregroundStyle(CadreColors.textPrimary)
                    .tracking(-0.2)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    viewModel.birthday = draftDate
                    dismiss()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CadreColors.accent)
            }
        }
        .toolbarBackground(CadreColors.bgGradientCenter, for: .navigationBar)
        .onAppear {
            if let existing = viewModel.birthday {
                draftDate = existing
            }
        }
    }
}

// MARK: - Gender Picker

/// Sub-screen 04: Single-select list. Tapping a row selects + saves.
struct GenderPickerView: View {
    let viewModel: SettingsViewModel

    var body: some View {
        ZStack {
            GradientBackground(center: .top)

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    ForEach(Gender.allCases) { option in
                        if option != Gender.allCases.first {
                            Rectangle()
                                .fill(CadreColors.divider)
                                .frame(height: 0.5)
                        }
                        Button {
                            viewModel.gender = option
                        } label: {
                            HStack {
                                Text(option.displayName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(CadreColors.textPrimary)
                                Spacer()
                                if viewModel.gender == option {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(CadreColors.accent)
                                }
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                    }
                }
                .padding(.top, 12)

                Text("Used for BMR estimation and other gender-aware metric calculations. You can change this any time.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(CadreColors.textTertiary)
                    .padding(.horizontal, 22)
                    .padding(.top, 18)

                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Gender")
                    .font(.custom("Exo 2", size: 17).weight(.bold))
                    .foregroundStyle(CadreColors.textPrimary)
                    .tracking(-0.2)
            }
        }
        .toolbarBackground(CadreColors.bgGradientCenter, for: .navigationBar)
    }
}

// MARK: - Theme Picker

/// Sub-screen 05: Dark only in v1. Light + System show "Soon" badge.
struct ThemePickerView: View {
    let viewModel: SettingsViewModel

    var body: some View {
        ZStack {
            GradientBackground(center: .top)

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    ForEach(AppTheme.allCases) { option in
                        if option != AppTheme.allCases.first {
                            Rectangle()
                                .fill(CadreColors.divider)
                                .frame(height: 0.5)
                        }
                        HStack {
                            Text(option.displayName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(option.isAvailable ? CadreColors.textPrimary : CadreColors.textTertiary)
                            Spacer()
                            if option.isAvailable && viewModel.theme == option {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(CadreColors.accent)
                            }
                            if !option.isAvailable {
                                Text("Soon")
                                    .font(.system(size: 9, weight: .bold))
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                    .foregroundStyle(CadreColors.textTertiary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(CadreColors.cardElevated, in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard option.isAvailable else { return }
                            viewModel.theme = option
                        }
                    }
                }
                .padding(.top, 12)

                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Theme")
                    .font(.custom("Exo 2", size: 17).weight(.bold))
                    .foregroundStyle(CadreColors.textPrimary)
                    .tracking(-0.2)
            }
        }
        .toolbarBackground(CadreColors.bgGradientCenter, for: .navigationBar)
    }
}

// MARK: - Cadre Sync

/// Sub-screen 06: API URL + API Key fields, test connection, status banner.
/// Stub in v1 — sync engine is Tasks 22-23.
struct CadreSyncView: View {
    let viewModel: SettingsViewModel
    @State private var apiURL: String = ""
    @State private var apiKey: String = ""
    @State private var showKey = false

    var body: some View {
        ZStack {
            GradientBackground(center: .top)

            VStack(alignment: .leading, spacing: 0) {
                // API URL
                VStack(alignment: .leading, spacing: 6) {
                    Text("API URL")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(CadreColors.textTertiary)
                        .textCase(.uppercase)
                    TextField("", text: $apiURL)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CadreColors.textPrimary)
                        .tint(CadreColors.accent)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(CadreColors.card, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(CadreColors.divider, lineWidth: 1)
                        )
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)

                // API Key
                VStack(alignment: .leading, spacing: 6) {
                    Text("API KEY")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(CadreColors.textTertiary)
                        .textCase(.uppercase)
                    HStack(spacing: 10) {
                        Group {
                            if showKey {
                                TextField("", text: $apiKey)
                            } else {
                                SecureField("", text: $apiKey)
                            }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CadreColors.textPrimary)
                        .tint(CadreColors.accent)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(CadreColors.textTertiary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(CadreColors.card, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(CadreColors.divider, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)

                // Test connection button (stub)
                Button {
                    // Stub — no-op until Tasks 22-23
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(CadreColors.accent)
                        Text("Test connection")
                            .font(.custom("Exo 2", size: 14).weight(.semibold))
                            .foregroundStyle(CadreColors.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(CadreColors.card, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(CadreColors.divider, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)

                Text("Pushes weight, scan, and measurement data to the Cadre D1 backend. Used for cross-app analytics with Apex.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(CadreColors.textTertiary)
                    .padding(.horizontal, 22)
                    .padding(.top, 18)

                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Cadre Sync")
                    .font(.custom("Exo 2", size: 17).weight(.bold))
                    .foregroundStyle(CadreColors.textPrimary)
                    .tracking(-0.2)
            }
        }
        .toolbarBackground(CadreColors.bgGradientCenter, for: .navigationBar)
        .onAppear {
            apiURL = viewModel.syncAPIURL
            apiKey = viewModel.syncAPIKey
        }
        .onDisappear {
            viewModel.syncAPIURL = apiURL
            viewModel.syncAPIKey = apiKey
        }
    }
}

// MARK: - Export CSV

/// Sub-screen 07: Export CSV files for weights, measurements, and scans.
struct ExportCSVView: View {
    let viewModel: SettingsViewModel
    @Environment(\.modelContext) private var modelContext

    @State private var includeWeights = true
    @State private var includeMeasurements = true
    @State private var includeScans = true

    private var exportItems: [ExportItem] {
        var items: [ExportItem] = []
        if includeWeights {
            let csv = CSVExporter.exportWeights(context: modelContext)
            items.append(ExportItem(filename: "baseline-weights.csv", content: csv))
        }
        if includeMeasurements {
            let csv = CSVExporter.exportMeasurements(context: modelContext)
            items.append(ExportItem(filename: "baseline-measurements.csv", content: csv))
        }
        if includeScans {
            let csv = CSVExporter.exportScans(context: modelContext)
            items.append(ExportItem(filename: "baseline-scans.csv", content: csv))
        }
        return items
    }

    var body: some View {
        ZStack {
            GradientBackground(center: .top)

            VStack(spacing: 0) {
                // Hero icon + title
                VStack(spacing: 14) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(CadreColors.accent)
                        .frame(width: 56, height: 56)
                        .background(CadreColors.card, in: RoundedRectangle(cornerRadius: 16))

                    Text("Export your data")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(CadreColors.textPrimary)
                        .tracking(-0.2)

                    Text("Generate CSV files of your history. Pick what to include.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CadreColors.textTertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }
                .padding(.top, 24)
                .padding(.bottom, 8)

                // Toggles
                VStack(spacing: 0) {
                    exportToggle("Weights", isOn: $includeWeights)
                    Rectangle().fill(CadreColors.divider).frame(height: 0.5)
                    exportToggle("Measurements", isOn: $includeMeasurements)
                    Rectangle().fill(CadreColors.divider).frame(height: 0.5)
                    exportToggle("Scans", isOn: $includeScans)
                }
                .background(CadreColors.card, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 22)
                .padding(.top, 20)

                // Share button
                if !exportItems.isEmpty {
                    let urls = exportItems.compactMap { $0.temporaryFileURL() }
                    ShareLink(items: urls) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .medium))
                            Text("Export \(exportItems.count) file\(exportItems.count == 1 ? "" : "s")")
                                .font(.custom("Exo 2", size: 14).weight(.semibold))
                        }
                        .foregroundStyle(CadreColors.bg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(CadreColors.accent, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 24)
                }

                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Export")
                    .font(.custom("Exo 2", size: 17).weight(.bold))
                    .foregroundStyle(CadreColors.textPrimary)
                    .tracking(-0.2)
            }
        }
        .toolbarBackground(CadreColors.bgGradientCenter, for: .navigationBar)
    }

    private func exportToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CadreColors.textPrimary)
        }
        .tint(CadreColors.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

/// Helper for creating temporary CSV files for sharing.
private struct ExportItem {
    let filename: String
    let content: String

    func temporaryFileURL() -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}

// MARK: - Import CSV

/// Sub-screen 07b: Import CSV files for weights, measurements, and scans.
///
/// Flow: tap "Choose file" → system file picker → parse + preview → pick
/// conflict strategy → tap "Import N rows" → outcome summary. Routes each
/// row through the same persistence + HK-mirror path as single-entry saves
/// so imported data gets UUID-tagged HealthKit samples automatically.
struct ImportCSVView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var showingFileImporter = false
    @State private var parsed: ParsedImport?
    @State private var conflictStrategy: ConflictStrategy = .skip
    @State private var outcome: ImportOutcome?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            GradientBackground(center: .top)

            ScrollView {
                VStack(spacing: 0) {
                    // Hero icon + title
                    VStack(spacing: 14) {
                        Image(systemName: "arrow.up.doc")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(CadreColors.accent)
                            .frame(width: 56, height: 56)
                            .background(CadreColors.card, in: RoundedRectangle(cornerRadius: 16))

                        Text("Import from CSV")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(CadreColors.textPrimary)
                            .tracking(-0.2)

                        Text("Weights, measurements, or scans. Pick a file exported from Baseline or one that matches the same format.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CadreColors.textTertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 8)

                    // Choose-file button (primary call-to-action when
                    // nothing has been parsed yet; a secondary pick-again
                    // row when a file is loaded).
                    if parsed == nil {
                        chooseFileButton
                            .padding(.horizontal, 22)
                            .padding(.top, 24)
                    }

                    // Preview card (shown after parse).
                    if let parsed {
                        previewCard(for: parsed)
                            .padding(.horizontal, 22)
                            .padding(.top, 20)

                        strategyPicker
                            .padding(.horizontal, 22)
                            .padding(.top, 16)

                        importButton(rowCount: parsed.rowCount)
                            .padding(.horizontal, 22)
                            .padding(.top, 20)

                        Button("Pick a different file") { showingFileImporter = true }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(CadreColors.textTertiary)
                            .padding(.top, 12)
                    }

                    // Outcome summary (shown after import).
                    if let outcome {
                        outcomeCard(outcome)
                            .padding(.horizontal, 22)
                            .padding(.top, 20)
                    }

                    // Error (bad header, unreadable file, etc.).
                    if let errorMessage {
                        errorCard(errorMessage)
                            .padding(.horizontal, 22)
                            .padding(.top, 20)
                    }
                }
                .padding(.bottom, CadreSpacing.xl)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Import")
                    .font(.custom("Exo 2", size: 17, relativeTo: .headline).weight(.bold))
                    .foregroundStyle(CadreColors.textPrimary)
                    .tracking(-0.2)
            }
        }
        .toolbarBackground(CadreColors.bgGradientCenter, for: .navigationBar)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFilePick(result: result)
        }
    }

    // MARK: - Subviews

    private var chooseFileButton: some View {
        Button {
            // Reset any prior state.
            parsed = nil
            outcome = nil
            errorMessage = nil
            showingFileImporter = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 14, weight: .medium))
                Text("Choose CSV file")
                    .font(.custom("Exo 2", size: 14, relativeTo: .body).weight(.semibold))
            }
            .foregroundStyle(CadreColors.bg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(CadreColors.accent, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func previewCard(for parsed: ParsedImport) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            previewRow(label: "Format", value: parsed.format.displayName)
            Rectangle().fill(CadreColors.divider).frame(height: 0.5)
            previewRow(label: "Rows ready", value: "\(parsed.rowCount)")
            if !parsed.issues.isEmpty {
                Rectangle().fill(CadreColors.divider).frame(height: 0.5)
                previewRow(label: "Rows skipped", value: "\(parsed.issues.count)", valueColor: CadreColors.danger)

                // Show up to the first three issue reasons so users know
                // what they'll lose. Anything beyond that is collapsed.
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(parsed.issues.prefix(3).enumerated()), id: \.offset) { _, issue in
                        Text("Line \(issue.line): \(issue.reason)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(CadreColors.textTertiary)
                    }
                    if parsed.issues.count > 3 {
                        Text("+ \(parsed.issues.count - 3) more")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(CadreColors.textTertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .background(CadreColors.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func previewRow(label: String, value: String, valueColor: Color = CadreColors.textPrimary) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(CadreColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var strategyPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("IF A ROW ALREADY EXISTS FOR THAT DAY")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(CadreColors.textTertiary)
                .textCase(.uppercase)

            HStack(spacing: 10) {
                strategyButton(
                    label: "Skip",
                    detail: "Keep existing",
                    isSelected: conflictStrategy == .skip,
                    action: { conflictStrategy = .skip }
                )
                strategyButton(
                    label: "Overwrite",
                    detail: "Replace existing",
                    isSelected: conflictStrategy == .overwrite,
                    action: { conflictStrategy = .overwrite }
                )
            }
        }
    }

    private func strategyButton(label: String, detail: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? CadreColors.bg : CadreColors.textPrimary)
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? CadreColors.bg.opacity(0.8) : CadreColors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isSelected ? CadreColors.accent : CadreColors.card,
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.clear : CadreColors.divider, lineWidth: 1)
            )
        }
    }

    private func importButton(rowCount: Int) -> some View {
        Button {
            runImport()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 14, weight: .medium))
                Text("Import \(rowCount) row\(rowCount == 1 ? "" : "s")")
                    .font(.custom("Exo 2", size: 14, relativeTo: .body).weight(.semibold))
            }
            .foregroundStyle(rowCount == 0 ? CadreColors.textTertiary : CadreColors.bg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                rowCount == 0 ? CadreColors.card : CadreColors.accent,
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .disabled(rowCount == 0)
    }

    private func outcomeCard(_ outcome: ImportOutcome) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            previewRow(label: "Inserted", value: "\(outcome.inserted)")
            if outcome.overwritten > 0 {
                Rectangle().fill(CadreColors.divider).frame(height: 0.5)
                previewRow(label: "Overwritten", value: "\(outcome.overwritten)")
            }
            if outcome.skipped > 0 {
                Rectangle().fill(CadreColors.divider).frame(height: 0.5)
                previewRow(label: "Skipped", value: "\(outcome.skipped)")
            }
            if outcome.failed > 0 {
                Rectangle().fill(CadreColors.divider).frame(height: 0.5)
                previewRow(label: "Failed", value: "\(outcome.failed)", valueColor: CadreColors.danger)
            }
        }
        .background(CadreColors.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func errorCard(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CadreColors.danger)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(CadreColors.textPrimary)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(CadreColors.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(CadreColors.danger.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func handleFilePick(result: Result<[URL], Error>) {
        errorMessage = nil
        outcome = nil

        switch result {
        case .failure(let err):
            errorMessage = "Couldn't open the file: \(err.localizedDescription)"
            return
        case .success(let urls):
            guard let url = urls.first else { return }
            // fileImporter returns a security-scoped URL. We must bracket
            // every read with start/stop calls to keep the sandbox happy.
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped { url.stopAccessingSecurityScopedResource() }
            }
            guard let data = try? Data(contentsOf: url),
                  let csv = String(data: data, encoding: .utf8) else {
                errorMessage = "The file is empty or not valid UTF-8 text."
                return
            }
            parseCSV(csv)
        }
    }

    private func parseCSV(_ csv: String) {
        switch CSVImporter.parseAny(csv) {
        case .success(let result):
            parsed = result
        case .failure(.unknownFormat):
            errorMessage = "This file's header doesn't match any Baseline format. Check that it matches the CSVs from Export."
            parsed = nil
        case .failure(.parseFailed(let err)):
            errorMessage = "Parse failed: \(err)"
            parsed = nil
        }
    }

    private func runImport() {
        guard let parsed else { return }
        outcome = CSVImporter.importAny(parsed, context: modelContext, conflictStrategy: conflictStrategy)
        // Clear the preview so the user can't double-import the same rows.
        self.parsed = nil
    }
}

private extension CSVFormat {
    var displayName: String {
        switch self {
        case .weights: return "Weights"
        case .measurements: return "Measurements"
        case .scans: return "Scans"
        }
    }
}

// MARK: - About Cadre

/// Sub-screen 08: Cadre ecosystem overview.
struct AboutCadreView: View {
    var body: some View {
        ZStack {
            GradientBackground(center: .top)

            ScrollView {
                VStack(spacing: 0) {
                    // Hero: logo + name + desc
                    VStack(spacing: 0) {
                        Text("C")
                            .font(.custom("Exo 2", size: 36).weight(.heavy))
                            .foregroundStyle(CadreColors.accent)
                            .tracking(-1)
                            .frame(width: 72, height: 72)
                            .background(
                                LinearGradient(
                                    colors: [CadreColors.cardElevated, CadreColors.divider],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 20)
                            )
                            .padding(.bottom, 16)

                        Text("Cadre")
                            .font(.custom("Exo 2", size: 22).weight(.heavy))
                            .foregroundStyle(CadreColors.textPrimary)
                            .tracking(-0.4)

                        Text("An ecosystem of tools for serious training. Your data, your format, your control.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CadreColors.textTertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                            .padding(.top, 8)
                    }
                    .padding(.top, 30)
                    .padding(.bottom, 16)

                    // App list
                    VStack(spacing: 0) {
                        appRow(letter: "B", name: "Baseline", description: "Weight + body comp tracking", color: CadreColors.accent, badge: "This app", badgeStyle: .current)
                        Rectangle().fill(CadreColors.divider).frame(height: 0.5)
                        appRow(letter: "A", name: "Apex", description: "Strength training logger", color: Color(hex: "B89968"), badge: "Sibling", badgeStyle: .normal)
                        Rectangle().fill(CadreColors.divider).frame(height: 0.5)
                        appRow(letter: "D", name: "Dashboard", description: "Cross-app analytics", color: Color(hex: "8A8278"), badge: "Soon", badgeStyle: .normal)
                    }
                    .background(CadreColors.card, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                }
                .padding(.bottom, CadreSpacing.xl)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("About Cadre")
                    .font(.custom("Exo 2", size: 17).weight(.bold))
                    .foregroundStyle(CadreColors.textPrimary)
                    .tracking(-0.2)
            }
        }
        .toolbarBackground(CadreColors.bgGradientCenter, for: .navigationBar)
    }

    private enum BadgeStyle { case current, normal }

    private func appRow(
        letter: String,
        name: String,
        description: String,
        color: Color,
        badge: String,
        badgeStyle: BadgeStyle
    ) -> some View {
        HStack(spacing: 12) {
            Text(letter)
                .font(.custom("Exo 2", size: 18).weight(.heavy))
                .foregroundStyle(color)
                .tracking(-0.3)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(CadreColors.textPrimary)
                    .tracking(-0.1)
                Text(description)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(CadreColors.textTertiary)
            }

            Spacer()

            Text(badge)
                .font(.system(size: 9, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(badgeStyle == .current ? CadreColors.accent : CadreColors.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    (badgeStyle == .current ? CadreColors.accent.opacity(0.18) : CadreColors.cardElevated),
                    in: RoundedRectangle(cornerRadius: 4)
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
