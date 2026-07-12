import SwiftUI

/// Primary CTA used across onboarding pages — mirrors the Weigh In button
/// treatment. accentButton (#606E85) rather than accent (#6B7B94) because
/// white-on-accent is only 4.3:1, below WCAG AA for normal text.
/// Shadow intentionally omitted (flatter surface context on onboarding).
struct OnboardingPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(CadreTypography.buttonLabel)
                .tracking(0.3)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(CadreColors.accentButton)
                )
        }
    }
}

/// Quiet secondary action ("Skip") — no fill, secondary text, full-width
/// tap target.
struct OnboardingGhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(CadreTypography.buttonLabel)
                .foregroundStyle(CadreColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
        }
    }
}

#Preview {
    ZStack {
        GradientBackground(center: .top)
        VStack(spacing: 8) {
            OnboardingPrimaryButton(title: "Get started", action: {})
            OnboardingGhostButton(title: "Skip for now", action: {})
        }
        .padding(.horizontal, 22)
    }
    .preferredColorScheme(.dark)
}
