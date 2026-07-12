import SwiftUI

/// Page 1 of onboarding — warm, conversational welcome. Left-aligned per the
/// approved mock (variant C); sets expectations up front: short, optional,
/// skippable. Copy reflects the post-audit scope (name → greeting), not the
/// mock's original "scan accuracy" subline.
struct OnboardingWelcomeView: View {
    let onGetStarted: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            EKGMark()
                .stroke(CadreColors.accentLight,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .frame(width: 54, height: 30)
                .padding(.bottom, 24)
                .accessibilityHidden(true)

            Text("Let's set\nyou up.")
                .font(.custom("Exo 2", size: 34, relativeTo: .largeTitle).weight(.bold))
                .tracking(-0.6)
                .lineSpacing(2)
                .foregroundStyle(CadreColors.textPrimary)

            Text("Baseline can greet you by name. It takes a few seconds — and you can skip it.")
                .font(.subheadline)
                .lineSpacing(4)
                .foregroundStyle(CadreColors.textSecondary)
                .padding(.top, 16)

            Spacer()

            OnboardingPrimaryButton(title: "Get started", action: onGetStarted)
                .accessibilityIdentifier(A11yID.Onboarding.getStarted)
            OnboardingGhostButton(title: "Skip for now", action: onSkip)
                .accessibilityIdentifier(A11yID.Onboarding.skipForNow)
                .padding(.top, 8)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 14)
    }
}

#Preview {
    ZStack {
        GradientBackground(center: .top)
        OnboardingWelcomeView(onGetStarted: {}, onSkip: {})
    }
    .preferredColorScheme(.dark)
}
