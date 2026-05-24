import SwiftUI

/// Sub-screen 05: Dark only in v1. Light + System show "Soon" badge.
struct ThemePickerView: View {
    let viewModel: SettingsViewModel

    var body: some View {
        ZStack {
            GradientBackground(center: .top)

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    ForEach(AppTheme.allCases) { option in
                        if option != AppTheme.allCases.first {
                            Rectangle()
                                .fill(CadreColors.divider)
                                .frame(height: 0.5)
                        }
                        HStack {
                            Text(option.displayName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(
                                    option.isAvailable ? CadreColors.textPrimary : CadreColors.textTertiary
                                )
                            Spacer()
                            if option.isAvailable && viewModel.theme == option {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(CadreColors.accent)
                            }
                            if !option.isAvailable {
                                Text("Soon")
                                    .font(.system(size: 9, weight: .bold))
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                    .foregroundStyle(CadreColors.textTertiary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(CadreColors.cardElevated, in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard option.isAvailable else { return }
                            viewModel.theme = option
                        }
                    }
                }
                .padding(.top, 12)

                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Theme")
                    .font(.custom("Exo 2", size: 17, relativeTo: .headline).weight(.bold))
                    .foregroundStyle(CadreColors.textPrimary)
                    .tracking(-0.2)
            }
        }
        .toolbarBackground(CadreColors.bgGradientCenter, for: .navigationBar)
    }
}
