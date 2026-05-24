import SwiftUI

/// Sub-screen 02: Dual wheel pickers (ft + in) or single cm picker.
struct HeightPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: SettingsViewModel

    @State private var draftFeet: Int = 5
    @State private var draftInches: Int = 10
    @State private var draftCm: Int = 170

    private var isMetric: Bool { viewModel.lengthUnit == "cm" }

    var body: some View {
        ZStack {
            GradientBackground(center: .top)

            VStack(spacing: 0) {
                if isMetric {
                    Picker("Centimeters", selection: $draftCm) {
                        ForEach(100...250, id: \.self) { cm in
                            Text("\(cm) cm")
                                .foregroundStyle(CadreColors.textPrimary)
                                .tag(cm)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 200)
                    .padding(.top, 16)
                } else {
                    HStack(spacing: 16) {
                        VStack(spacing: 8) {
                            Text("FEET")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.4)
                                .foregroundStyle(CadreColors.textTertiary)
                            Picker("Feet", selection: $draftFeet) {
                                ForEach(3...8, id: \.self) { ft in
                                    Text("\(ft)")
                                        .foregroundStyle(CadreColors.textPrimary)
                                        .tag(ft)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80, height: 180)
                        }

                        VStack(spacing: 8) {
                            Text("INCHES")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.4)
                                .foregroundStyle(CadreColors.textTertiary)
                            Picker("Inches", selection: $draftInches) {
                                ForEach(0...11, id: \.self) { inches in
                                    Text("\(inches)")
                                        .foregroundStyle(CadreColors.textPrimary)
                                        .tag(inches)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80, height: 180)
                        }
                    }
                    .padding(.top, 16)
                }

                Text("Used for BMR and SMI calculations on InBody scans.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(CadreColors.textTertiary)
                    .padding(.top, 20)

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
                Text("Height")
                    .font(.custom("Exo 2", size: 16, relativeTo: .headline).weight(.bold))
                    .foregroundStyle(CadreColors.textPrimary)
                    .tracking(-0.2)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if isMetric {
                        viewModel.heightCm = draftCm
                    } else {
                        viewModel.heightFeet = draftFeet
                        viewModel.heightInches = draftInches
                    }
                    dismiss()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CadreColors.accent)
            }
        }
        .toolbarBackground(CadreColors.bgGradientCenter, for: .navigationBar)
        .onAppear {
            draftFeet = viewModel.heightFeet > 0 ? viewModel.heightFeet : 5
            draftInches = viewModel.heightInches
            draftCm = viewModel.heightCm > 0 ? viewModel.heightCm : 170
        }
    }
}
