import SwiftUI
import TipKit

/// Step 2 of the scan-entry flow — pick how to get values into the app:
/// camera-scan a printout (OCR) or type the values manually.
struct InputMethodStep: View {
    let vm: ScanEntryViewModel
    private let multiPhotoTip = MultiPhotoTip()

    var body: some View {
        VStack(spacing: 0) {
            ScanFlowPushHeader(title: "New Scan", subtitle: "Step 2 of 2") {
                vm.goBack()
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("How do you want to enter it?")
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.4)
                    .foregroundStyle(CadreColors.textPrimary)
                    .padding(.horizontal, CadreSpacing.sheetHorizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                TipView(multiPhotoTip)
                    .padding(.horizontal, CadreSpacing.sheetHorizontal)
                    .padding(.bottom, 4)

                VStack(spacing: 12) {
                    methodCard(
                        icon: "camera",
                        title: "Scan printout",
                        description: "Auto-reads values from your InBody printout.",
                        hint: "Multiple photos improve accuracy"
                    ) {
                        vm.selectMethod(camera: true)
                    }

                    methodCard(
                        icon: "square.and.pencil",
                        title: "Enter manually",
                        description: "Type the values from your printout yourself."
                    ) {
                        vm.selectMethod(camera: false)
                    }
                    .accessibilityIdentifier(A11yID.ScanEntry.manualEntryButton)
                }
                .padding(.horizontal, CadreSpacing.sheetHorizontal)
                .padding(.top, 20)
            }

            Spacer()
        }
    }

    private func methodCard(
        icon: String, title: String, description: String, hint: String? = nil, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(CadreColors.accent)
                    .frame(width: 44, height: 44)
                    .background(CadreColors.cardElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .tracking(-0.2)
                        .foregroundStyle(CadreColors.textPrimary)
                    Text(description)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CadreColors.textTertiary)
                        .lineSpacing(2)
                    if let hint {
                        HStack(spacing: 4) {
                            Image(systemName: "lightbulb.min")
                                .font(.system(size: 10, weight: .medium))
                            Text(hint)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(CadreColors.accent.opacity(0.7))
                        .padding(.top, 2)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CadreColors.textTertiary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .background(CadreColors.card)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(CadreColors.divider, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
