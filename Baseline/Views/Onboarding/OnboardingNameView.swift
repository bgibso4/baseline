import SwiftUI

/// Page 2 of onboarding — optional name entry. Input card mirrors
/// `NameEditView`'s treatment. All exits (Continue, Skip, keyboard Done)
/// complete onboarding via the view model; a blank Continue behaves like Skip.
struct OnboardingNameView: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What should we call you?")
                .font(.custom("Exo 2", size: 28, relativeTo: .title).weight(.bold))
                .tracking(-0.5)
                .foregroundStyle(CadreColors.textPrimary)
                .padding(.top, 32)

            Text("Shown in your greeting on the Now screen.")
                .font(.subheadline)
                .foregroundStyle(CadreColors.textSecondary)
                .padding(.top, 10)

            TextField("Your name", text: $viewModel.draftName)
                .font(.custom("Exo 2", size: 18, relativeTo: .headline).weight(.semibold))
                .foregroundStyle(CadreColors.textPrimary)
                .tint(CadreColors.accent)
                .autocorrectionDisabled()
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit { viewModel.completeSavingName() }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(CadreColors.card, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(CadreColors.accent, lineWidth: 1)
                )
                .padding(.top, 28)
                .accessibilityIdentifier(A11yID.Onboarding.nameField)

            Spacer()

            OnboardingPrimaryButton(title: "Continue") {
                viewModel.completeSavingName()
            }
            .accessibilityIdentifier(A11yID.Onboarding.continueButton)
            OnboardingGhostButton(title: "Skip") {
                viewModel.complete()
            }
            .accessibilityIdentifier(A11yID.Onboarding.skipName)
            .padding(.top, 8)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 14)
        .onAppear { isFocused = true }
    }
}

#Preview {
    ZStack {
        GradientBackground(center: .top)
        OnboardingNameView(viewModel: OnboardingViewModel())
    }
    .preferredColorScheme(.dark)
}
