import SwiftUI
import SwiftData

/// Full scan history list — reverse chronological, swipe to delete.
///
/// Row layout per design decisions: date block (day + month-year) on left,
/// scan type (InBody 570) as title, 3 key metrics (BF / Muscle / BMI) inline.
struct ScanHistoryView: View {
    let scans: [Scan]
    let onDelete: (Scan) -> Void
    let decodedPayload: (Scan) -> ScanContent?

    var body: some View {
        ZStack {
            CadreColors.bg.ignoresSafeArea()

            if scans.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(scans, id: \.id) { scan in
                        NavigationLink {
                            ScanDetailView(scan: scan, onDelete: onDelete)
                        } label: {
                            scanRow(scan)
                        }
                        .listRowBackground(CadreColors.card)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            onDelete(scans[index])
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Scans")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Row

    private func scanRow(_ scan: Scan) -> some View {
        HStack(spacing: 14) {
            // Date block
            dateBlock(scan.date)

            VStack(alignment: .leading, spacing: 4) {
                Text(scanTypeLabel(scan))
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.1)
                    .foregroundStyle(CadreColors.textPrimary)

                if let content = decodedPayload(scan) {
                    metricsRow(content)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private func dateBlock(_ date: Date) -> some View {
        let cal = Calendar.current
        let day = cal.component(.day, from: date)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        let monthYear = formatter.string(from: date)

        return VStack(spacing: 2) {
            Text("\(day)")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(CadreColors.textPrimary)
            Text(monthYear)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(CadreColors.textTertiary)
        }
        .frame(width: 56)
    }

    private func scanTypeLabel(_ scan: Scan) -> String {
        switch scan.scanType {
        case .inBody: return "InBody 570"
        case .none: return "Scan"
        }
    }

    private func metricsRow(_ content: ScanContent) -> some View {
        switch content {
        case .inBody(let p):
            let smm = UnitConversion.formattedMass(p.skeletalMuscleMassKg)
            return HStack(spacing: 12) {
                metricBadge("BF", value: String(format: "%.1f%%", p.bodyFatPct))
                metricBadge("SMM", value: smm.text)
                metricBadge("BMI", value: String(format: "%.1f", p.bmi))
            }
        }
    }

    private func metricBadge(_ label: String, value: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(CadreColors.textTertiary)
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(CadreColors.textSecondary)
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(CadreColors.textTertiary)
            Text("No scans yet")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CadreColors.textTertiary)
        }
    }
}
