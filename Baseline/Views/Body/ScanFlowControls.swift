import SwiftUI

/// Top navigation header used by the scan-flow steps: a chevron-back button
/// on the left, a centered title + step subtitle, and an invisible spacer
/// on the right to keep the title centered.
struct ScanFlowPushHeader: View {
    let title: String
    let subtitle: String
    let backAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: backAction) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CadreColors.textPrimary)
                    .frame(width: 30, height: 30)
                    .background(CadreColors.cardElevated)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .tracking(-0.2)
                    .foregroundStyle(CadreColors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(CadreColors.textTertiary)
            }

            Spacer()

            // Invisible spacer for centering
            Color.clear
                .frame(width: 30, height: 30)
        }
        .padding(.horizontal, CadreSpacing.sheetHorizontal)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
}

/// Full-width primary action button used to advance between scan-flow steps.
struct ScanFlowContinueButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .tracking(0.3)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(CadreColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .accessibilityIdentifier(A11yID.ScanEntry.continueButton)
        .padding(.horizontal, CadreSpacing.sheetHorizontal)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
}
