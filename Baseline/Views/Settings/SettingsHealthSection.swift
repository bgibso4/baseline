import SwiftUI
import HealthKit
import UIKit

/// Apple Health section of the Settings screen. Shown only on devices where
/// HealthKit is available. Owns its own auth-status state and queries it on
/// appear; tapping the row prompts for permission (or deep-links to system
/// Settings if the user previously denied).
struct SettingsHealthSection: View {
    @State private var healthKitStatus: HKAuthorizationStatus = .notDetermined

    @ViewBuilder
    var body: some View {
        if HKHealthStore.isHealthDataAvailable() {
            SettingsSectionView(title: "HEALTH") {
                Button(action: handleHealthRowTap) {
                    HStack(spacing: 14) {
                        SettingsRowIcon(
                            systemName: healthKitIcon,
                            tint: healthKitIconTint
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Health")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(CadreColors.textPrimary)
                                .tracking(-0.1)
                            Text(healthKitSubtitle)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(CadreColors.textTertiary)
                        }
                        Spacer()
                        Text(healthKitStatusLabel)
                            // .caption (12pt) passes DT audit; .caption2 (11pt) with
                            // weight modifier causes false-positive tool failure.
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .tracking(0.4)
                            .foregroundStyle(healthKitStatusColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                healthKitStatusColor.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 5)
                            )
                        if healthKitStatus != .sharingAuthorized {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(CadreColors.textTertiary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(healthKitStatus == .sharingAuthorized)
            }
            .onAppear(perform: refreshHealthKitStatus)
        }
    }

    /// Query the write-auth status for a representative type we actually save
    /// (bodyMass). HealthKit deliberately won't tell you *read* status, but
    /// write status is accurate and mirrors the user's consent.
    private func refreshHealthKitStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            healthKitStatus = .sharingDenied // treat as unavailable for the UI
            return
        }
        healthKitStatus = HKHealthStore().authorizationStatus(for: HKQuantityType(.bodyMass))
    }

    private func handleHealthRowTap() {
        switch healthKitStatus {
        case .notDetermined:
            Task {
                await HealthKitManager.requestAuthorizationIfNeeded()
                await MainActor.run { refreshHealthKitStatus() }
            }
        case .sharingDenied:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        default:
            break
        }
    }

    private var healthKitIcon: String {
        switch healthKitStatus {
        case .sharingAuthorized: return "heart.fill"
        case .sharingDenied: return "heart.slash"
        default: return "heart"
        }
    }

    private var healthKitIconTint: SettingsIconTint {
        switch healthKitStatus {
        case .sharingAuthorized: return .success
        case .sharingDenied: return .danger
        default: return .accent
        }
    }

    private var healthKitStatusLabel: String {
        switch healthKitStatus {
        case .sharingAuthorized: return "Connected"
        case .sharingDenied: return "Denied"
        default: return "Not set"
        }
    }

    private var healthKitStatusColor: Color {
        switch healthKitStatus {
        case .sharingAuthorized: return CadreColors.success
        case .sharingDenied: return CadreColors.danger
        default: return CadreColors.textSecondary
        }
    }

    private var healthKitSubtitle: String {
        switch healthKitStatus {
        case .sharingAuthorized: return "Baseline is syncing to Apple Health."
        case .sharingDenied: return "Tap to enable in Settings."
        default: return "Tap to allow Baseline to write your metrics."
        }
    }
}
