import SwiftUI

/// Sub-screen 06: API URL + API Key fields, test connection, status banner.
/// Stub in v1 — sync engine is Tasks 22-23.
struct CadreSyncView: View {
    let viewModel: SettingsViewModel
    @State private var apiURL: String = ""
    @State private var apiKey: String = ""
    @State private var showKey = false

    var body: some View {
        ZStack {
            GradientBackground(center: .top)

            VStack(alignment: .leading, spacing: 0) {
                // API URL
                VStack(alignment: .leading, spacing: 6) {
                    Text("API URL")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(CadreColors.textTertiary)
                        .textCase(.uppercase)
                    TextField("", text: $apiURL)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CadreColors.textPrimary)
                        .tint(CadreColors.accent)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(CadreColors.card, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(CadreColors.divider, lineWidth: 1)
                        )
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)

                // API Key
                VStack(alignment: .leading, spacing: 6) {
                    Text("API KEY")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(CadreColors.textTertiary)
                        .textCase(.uppercase)
                    HStack(spacing: 10) {
                        Group {
                            if showKey {
                                TextField("", text: $apiKey)
                            } else {
                                SecureField("", text: $apiKey)
                            }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CadreColors.textPrimary)
                        .tint(CadreColors.accent)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(CadreColors.textTertiary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(CadreColors.card, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(CadreColors.divider, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)

                // Test connection button (stub)
                Button {
                    // Stub — no-op until Tasks 22-23
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(CadreColors.accent)
                        Text("Test connection")
                            .font(.custom("Exo 2", size: 14, relativeTo: .body).weight(.semibold))
                            .foregroundStyle(CadreColors.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(CadreColors.card, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(CadreColors.divider, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)

                Text(
                    "Pushes weight, scan, and measurement data to the Cadre D1 backend. " +
                    "Used for cross-app analytics with Apex."
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
                Text("Cadre Sync")
                    .font(.custom("Exo 2", size: 17, relativeTo: .headline).weight(.bold))
                    .foregroundStyle(CadreColors.textPrimary)
                    .tracking(-0.2)
            }
        }
        .toolbarBackground(CadreColors.bgGradientCenter, for: .navigationBar)
        .onAppear {
            apiURL = viewModel.syncAPIURL
            apiKey = viewModel.syncAPIKey
        }
        .onDisappear {
            viewModel.syncAPIURL = apiURL
            viewModel.syncAPIKey = apiKey
        }
    }
}
