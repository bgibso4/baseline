import SwiftUI

/// Detail view for a single scan — shows all decoded payload fields grouped by category.
struct ScanDetailView: View {
    let scan: Scan

    private var content: ScanContent? {
        try? scan.decoded()
    }

    var body: some View {
        ZStack {
            CadreColors.bg.ignoresSafeArea()

            if let content {
                ScrollView {
                    VStack(spacing: 0) {
                        switch content {
                        case .inBody(let payload):
                            inBodySections(payload)
                        }
                    }
                    .padding(.bottom, CadreSpacing.xl)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(CadreColors.textTertiary)
                    Text("Unable to decode scan")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CadreColors.textTertiary)
                }
            }
        }
        .navigationTitle(scanTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CadreColors.bg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var scanTitle: String {
        switch scan.scanType {
        case .inBody: return "InBody 570"
        case .none: return "Scan"
        }
    }

    // MARK: - InBody Sections

    @ViewBuilder
    private func inBodySections(_ p: InBodyPayload) -> some View {
        // Date header
        VStack(spacing: 4) {
            Text(DateFormatting.fullDate(scan.date))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(CadreColors.textSecondary)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)

        detailSection("Core") {
            detailRow("Weight", value: fmt(p.weightKg), unit: "kg")
            detailRow("Skeletal Muscle Mass", value: fmt(p.skeletalMuscleMassKg), unit: "kg")
            detailRow("Body Fat Mass", value: fmt(p.bodyFatMassKg), unit: "kg")
            detailRow("Body Fat", value: fmt(p.bodyFatPct), unit: "%")
            detailRow("Total Body Water", value: fmt(p.totalBodyWaterL), unit: "L")
            detailRow("BMI", value: fmt(p.bmi), unit: "")
            detailRow("Basal Metabolic Rate", value: String(format: "%.0f", p.basalMetabolicRate), unit: "kcal")
        }

        detailSection("Body Composition") {
            optionalRow("Intracellular Water", value: p.intracellularWaterL, unit: "L")
            optionalRow("Extracellular Water", value: p.extracellularWaterL, unit: "L")
            optionalRow("Dry Lean Mass", value: p.dryLeanMassKg, unit: "kg")
            optionalRow("Lean Body Mass", value: p.leanBodyMassKg, unit: "kg")
            optionalRow("InBody Score", value: p.inBodyScore, unit: "")
        }

        detailSection("Segmental Lean") {
            optionalRow("Right Arm", value: p.rightArmLeanKg, unit: "kg")
            optionalRow("Left Arm", value: p.leftArmLeanKg, unit: "kg")
            optionalRow("Trunk", value: p.trunkLeanKg, unit: "kg")
            optionalRow("Right Leg", value: p.rightLegLeanKg, unit: "kg")
            optionalRow("Left Leg", value: p.leftLegLeanKg, unit: "kg")
        }

        detailSection("Segmental Fat") {
            optionalRow("Right Arm", value: p.rightArmFatKg, unit: "kg")
            optionalRow("Left Arm", value: p.leftArmFatKg, unit: "kg")
            optionalRow("Trunk", value: p.trunkFatKg, unit: "kg")
            optionalRow("Right Leg", value: p.rightLegFatKg, unit: "kg")
            optionalRow("Left Leg", value: p.leftLegFatKg, unit: "kg")
        }
    }

    // MARK: - Section & Row Helpers

    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(CadreColors.textTertiary)
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                content()
            }
            .background(CadreColors.card, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
    }

    private func detailRow(_ label: String, value: String, unit: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CadreColors.textSecondary)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(CadreColors.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CadreColors.textTertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private func optionalRow(_ label: String, value: Double?, unit: String) -> some View {
        if let value {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(CadreColors.divider)
                    .frame(height: 0.5)
                detailRow(label, value: fmt(value), unit: unit)
            }
        }
    }

    private func fmt(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
