import SwiftUI

/// Sub-screen 03: Graphical DatePicker with computed age card below.
struct BirthdayPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: SettingsViewModel
    @State private var draftDate: Date = Calendar.current.date(
        byAdding: .year, value: -30, to: Date()
    )!

    private var computedAge: Int {
        Calendar.current.dateComponents([.year], from: draftDate, to: Date()).year ?? 0
    }

    var body: some View {
        ZStack {
            GradientBackground(center: .top)

            VStack(spacing: 0) {
                DatePicker(
                    "Birthday",
                    selection: $draftDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(CadreColors.accent)
                .colorScheme(.dark)
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .labelsHidden()

                // Computed age card
                HStack {
                    Text("CURRENT AGE")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(CadreColors.textTertiary)
                        .textCase(.uppercase)
                    Spacer()
                    Text("\(computedAge) years")
                        .font(.custom("Exo 2", size: 20, relativeTo: .title3).weight(.bold))
                        .foregroundStyle(CadreColors.textPrimary)
                        .tracking(-0.2)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(CadreColors.card, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 22)
                .padding(.top, 16)

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
                Text("Birthday")
                    .font(.custom("Exo 2", size: 16, relativeTo: .headline).weight(.bold))
                    .foregroundStyle(CadreColors.textPrimary)
                    .tracking(-0.2)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    viewModel.birthday = draftDate
                    dismiss()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CadreColors.accent)
            }
        }
        .toolbarBackground(CadreColors.bgGradientCenter, for: .navigationBar)
        .onAppear {
            if let existing = viewModel.birthday {
                draftDate = existing
            }
        }
    }
}
