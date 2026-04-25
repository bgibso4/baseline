import SwiftUI

/// Shared empty-state scaffold — icon tile + title + body + optional CTA.
/// Used wherever a screen shows "nothing to display yet" so the tone and
/// layout stay consistent across History, Trends, Scans, Body sections,
/// and the scan-decode failure state.
///
/// Every call site decides its own spacing around the card; the card
/// itself centers its content and caps text width so long copy wraps
/// naturally on large Dynamic Type settings.
struct EmptyStateCard: View {
    let systemImage: String
    let title: String
    let message: String
    var ctaLabel: String? = nil
    var ctaAction: (() -> Void)? = nil
    var iconTint: Color = CadreColors.textSecondary

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(CadreColors.cardElevated)
                    .frame(width: 52, height: 52)
                Image(systemName: systemImage)
                    .font(CadreTypography.scaled(size: 22, weight: .medium))
                    .foregroundStyle(iconTint)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(CadreTypography.scaled(size: 15, weight: .semibold))
                    .tracking(-0.1)
                    .foregroundStyle(CadreColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(CadreTypography.scaled(size: 12, weight: .medium))
                    .foregroundStyle(CadreColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
                    .lineSpacing(2)
            }

            if let ctaLabel, let ctaAction {
                Button(action: ctaAction) {
                    Text(ctaLabel)
                        .font(CadreTypography.scaled(size: 13, weight: .semibold))
                        .tracking(0.2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(CadreColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

#Preview {
    ZStack {
        CadreColors.bg.ignoresSafeArea()
        EmptyStateCard(
            systemImage: "chart.xyaxis.line",
            title: "No data yet",
            message: "Log a weigh-in to start building your trend.",
            ctaLabel: "Log Weigh-In",
            ctaAction: {}
        )
    }
    .preferredColorScheme(.dark)
}
