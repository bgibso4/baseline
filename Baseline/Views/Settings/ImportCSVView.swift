import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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

                        Text(
                            "Weights, measurements, or scans. " +
                            "Pick a file exported from Baseline or one that matches the same format."
                        )
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
        .accessibilityIdentifier(A11yID.Settings.importChooseFile)
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

    private func strategyButton(
        label: String, detail: String, isSelected: Bool, action: @escaping () -> Void
    ) -> some View {
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
            Log.data.error("CSV import: fileImporter failed", err)
            errorMessage = "Couldn't open the file: \(err.localizedDescription)"
            return

        case .success(let urls):
            guard let url = urls.first else {
                Log.data.warning("CSV import: fileImporter returned no URL")
                return
            }
            Log.data.info("CSV import: picked file \(url.lastPathComponent)")

            // fileImporter returns a security-scoped URL. Bracket every
            // read with start/stop calls to keep the sandbox happy.
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped { url.stopAccessingSecurityScopedResource() }
            }

            // iCloud Drive files may not be downloaded locally yet — nudge
            // the coordinator to materialize the file before we try to read.
            if FileManager.default.isUbiquitousItem(at: url) {
                try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            }

            let data: Data
            do {
                data = try Data(contentsOf: url, options: [.uncached])
            } catch {
                Log.data.error("CSV import: failed to read file", error)
                errorMessage = "Couldn't read the file. \(error.localizedDescription)"
                return
            }
            Log.data.info("CSV import: read \(data.count) bytes")

            guard let csv = String(data: data, encoding: .utf8) else {
                Log.data.error("CSV import: file is not valid UTF-8")
                errorMessage = "The file isn't valid UTF-8 text. Try re-exporting."
                return
            }

            parseCSV(csv)
        }
    }

    private func parseCSV(_ csv: String) {
        let byteCount = csv.lengthOfBytes(using: .utf8)
        let lineCount = csv.reduce(into: 0) { count, ch in
            if ch == "\n" { count += 1 }
        }
        Log.data.info("CSV import: parsing \(byteCount) bytes, ~\(lineCount) lines")

        // Dump the raw header + detected format so we can diagnose a
        // format-detection failure without guessing.
        let firstLine = csv.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? ""
        Log.data.info("CSV import: header raw='\(firstLine.prefix(200))'")
        if let detected = CSVFormat.detect(from: csv) {
            Log.data.info("CSV import: detected format=\(detected.rawValue)")
        } else {
            Log.data.warning("CSV import: no format detected")
        }

        switch CSVImporter.parseAny(csv) {
        case .success(let result):
            parsed = result
            Log.data.info("CSV import: parsed \(result.rowCount) rows, \(result.issues.count) issues," +
                " format=\(result.format.rawValue)")
            for issue in result.issues.prefix(5) {
                Log.data.warning("CSV import: line \(issue.line): \(issue.reason)")
            }

        case .failure(.unknownFormat):
            Log.data.error("CSV import: unknown format for header '\(firstLine.prefix(200))'")
            errorMessage = "This file's header doesn't match any recognised format."
            parsed = nil

        case .failure(.parseFailed(.emptyFile)):
            Log.data.error("CSV import: parse reports empty file")
            errorMessage = "The file appears to be empty."
            parsed = nil

        case .failure(.parseFailed(.missingRequiredColumns(let missing))):
            Log.data.error("CSV import: missing required columns: \(missing.joined(separator: ", "))")
            errorMessage = "Missing required column(s): \(missing.joined(separator: ", "))."
            parsed = nil
        }
    }

    private func runImport() {
        guard let parsed else {
            Log.data.warning("CSV import: runImport called with nil parsed state")
            return
        }
        Log.data.info("CSV import: starting import, rows=\(parsed.rowCount), strategy=\(conflictStrategyName)")

        let result = CSVImporter.importAny(parsed, context: modelContext, conflictStrategy: conflictStrategy)
        outcome = result

        Log.data.info("CSV import: done, inserted=\(result.inserted) overwritten=\(result.overwritten)" +
            " skipped=\(result.skipped) failed=\(result.failed)")

        // Clear the preview so the user can't double-import the same rows.
        self.parsed = nil
    }

    private var conflictStrategyName: String {
        switch conflictStrategy {
        case .skip: return "skip"
        case .overwrite: return "overwrite"
        }
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
