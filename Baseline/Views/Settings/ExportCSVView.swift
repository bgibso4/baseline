import SwiftUI
import SwiftData

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
                                .font(.custom("Exo 2", size: 14, relativeTo: .body).weight(.semibold))
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
                    .font(.custom("Exo 2", size: 17, relativeTo: .headline).weight(.bold))
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
