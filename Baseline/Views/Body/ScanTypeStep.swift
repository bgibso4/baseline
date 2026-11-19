import SwiftUI

/// Step 1 of the scan-entry flow — pick which kind of body-composition device
/// produced the printout. Only InBody 570 is supported today; the card layout
/// already reads as a list so further devices slot in as new cards.
struct ScanTypeStep: View {
    let vm: ScanEntryViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScanFlowPushHeader(title: "New Scan", subtitle: "Step 1 of 2", backAction: onClose)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Intro text
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What type of scan?")
                            .font(.system(size: 22, weight: .bold))
                            .tracking(-0.4)
                            .foregroundStyle(CadreColors.textPrimary)
                        Text("Each machine records a different set of metrics.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CadreColors.textTertiary)
                    }
                    .padding(.horizontal, CadreSpacing.sheetHorizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                    // InBody 570 card (pre-selected)
                    scanTypeCard(
                        icon: "570",
                        name: "InBody 570",
                        description: "Body comp \u{00B7} segmental lean \u{00B7} water analysis",
                        isSelected: vm.selectedType == .inBody
                    )
                    .padding(.horizontal, CadreSpacing.sheetHorizontal)
                }
            }

            // Continue button at bottom
            ScanFlowContinueButton(label: "Continue") {
                vm.selectType(.inBody)
            }
        }
    }

    private func scanTypeCard(icon: String, name: String, description: String, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            // Icon
            Text(icon)
                .font(.system(size: 10, weight: .bold, design: .default))
                .tracking(-0.2)
                .foregroundStyle(CadreColors.accent)
                .frame(width: 36, height: 36)
                .background(isSelected ? CadreColors.accent.opacity(0.2) : CadreColors.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.1)
                    .foregroundStyle(CadreColors.textPrimary)
                Text(description)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(CadreColors.textTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(isSelected ? CadreColors.cardElevated : CadreColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? CadreColors.accent : CadreColors.divider, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
