import SwiftUI

/// Sub-screen 04: Single-select list. Tapping a row selects + saves.
struct GenderPickerView: View {
    let viewModel: SettingsViewModel

    var body: some View {
        ZStack {
            GradientBackground(center: .top)

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    ForEach(Gender.allCases) { option in
                        if option != Gender.allCases.first {
                            Rectangle()
                                .fill(CadreColors.divider)
                                .frame(height: 0.5)
                        }
                        Button {
                            viewModel.gender = option
                        } label: {
                            HStack {
                                Text(option.displayName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(CadreColors.textPrimary)
                                Spacer()
                                if viewModel.gender == option {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(CadreColors.accent)
                                }
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                    }
                }
                .padding(.top, 12)

                Text(
                    "Used for BMR estimation and other gender-aware metric calculations. You can change this any time."
                )
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(CadreColors.textTertiary)
                    .padding(.horizontal, 22)
                    .padding(.top, 18)

                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Gender")
                    .font(.custom("Exo 2", size: 17, relativeTo: .headline).weight(.bold))
                    .foregroundStyle(CadreColors.textPrimary)
                    .tracking(-0.2)
            }
        }
        .toolbarBackground(CadreColors.bgGradientCenter, for: .navigationBar)
    }
}
