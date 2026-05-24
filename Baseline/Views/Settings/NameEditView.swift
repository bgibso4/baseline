import SwiftUI

/// Sub-screen 01: Name text input with Cancel/Save nav bar.
struct NameEditView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: SettingsViewModel
    @State private var draft: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            GradientBackground(center: .top)

            VStack(alignment: .leading, spacing: 0) {
                // Text input card with accent border
                HStack {
                    TextField("", text: $draft)
                        .font(.custom("Exo 2", size: 18, relativeTo: .headline).weight(.semibold))
                        .foregroundStyle(CadreColors.textPrimary)
                        .tint(CadreColors.accent)
                        .autocorrectionDisabled()
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            viewModel.name = draft.trimmingCharacters(in: .whitespaces)
                            dismiss()
                        }

                    if !draft.isEmpty {
                        Button {
                            draft = ""
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(CadreColors.bg)
                                .frame(width: 20, height: 20)
                                .background(CadreColors.textTertiary, in: Circle())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(CadreColors.card, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(CadreColors.accent, lineWidth: 1)
                )
                .padding(.horizontal, 22)
                .padding(.top, 20)

                Text("Your name appears on widgets and export files.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(CadreColors.textTertiary)
                    .padding(.horizontal, 22)
                    .padding(.top, 10)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CadreColors.textSecondary)
            }
            ToolbarItem(placement: .principal) {
                Text("Name")
                    .font(.custom("Exo 2", size: 16, relativeTo: .headline).weight(.bold))
                    .foregroundStyle(CadreColors.textPrimary)
                    .tracking(-0.2)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    viewModel.name = draft.trimmingCharacters(in: .whitespaces)
                    dismiss()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CadreColors.accent)
            }
        }
        .toolbarBackground(CadreColors.bgGradientCenter, for: .navigationBar)
        .onAppear { draft = viewModel.name }
    }
}
