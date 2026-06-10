import SwiftUI

/// First-launch onboarding container — paged Welcome → Name flow.
/// `BaselineApp` presents this instead of `MainTabView` until the
/// "hasCompletedOnboarding" flag is set. The flag is written by
/// `OnboardingViewModel` (any exit path) and observed by the app root via
/// @AppStorage, which is what swaps this flow out — there is no explicit
/// dismiss here.
struct OnboardingFlow: View {
    private enum Page {
        case welcome
        case name
    }

    @State private var viewModel = OnboardingViewModel()
    @State private var page: Page = .welcome

    var body: some View {
        ZStack {
            GradientBackground(center: .top)

            switch page {
            case .welcome:
                OnboardingWelcomeView(
                    onGetStarted: {
                        withAnimation(.snappy) { page = .name }
                    },
                    onSkip: { viewModel.complete() }
                )
                .transition(.move(edge: .leading).combined(with: .opacity))
            case .name:
                OnboardingNameView(viewModel: viewModel)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    OnboardingFlow()
}
