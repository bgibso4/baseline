import SwiftUI
import UIKit

struct GoalReachedOverlay: View {
    let targetValue: Double
    let startValue: Double
    let unit: String
    let startDate: Date
    let onNewGoal: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                // Emoji
                Text("🎯")
                    .font(CadreTypography.scaled(size: 48, weight: .regular))
                    .padding(.bottom, 12)
                    .accessibilityHidden(true)

                // Title
                Text("Goal Reached!")
                    .font(CadreTypography.scaled(size: 22, weight: .bold))
                    .foregroundStyle(CadreColors.textPrimary)
                    .padding(.bottom, 8)
                    .accessibilityAddTraits(.isHeader)

                // Target
                Text("Target: \(formatValue(targetValue)) \(unit)")
                    .font(CadreTypography.scaled(size: 15, weight: .medium))
                    .foregroundStyle(CadreColors.accent)
                    .padding(.bottom, 4)

                // Started at
                Text("Started at \(formatValue(startValue)) \(unit) on \(formattedDate(startDate))")
                    .font(CadreTypography.scaled(size: 13, weight: .regular))
                    .foregroundStyle(CadreColors.textSecondary)
                    .padding(.bottom, 28)

                // Set New Goal button
                Button(action: onNewGoal) {
                    Text("Set New Goal")
                        .font(CadreTypography.scaled(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(CadreColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 16)

                // Dismiss link
                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(CadreTypography.scaled(size: 15, weight: .regular))
                        .foregroundStyle(CadreColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(28)
            .background(CadreColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(CadreColors.divider, lineWidth: 1))
            .padding(.horizontal, 28)
        }
        // VoiceOver: announce arrival on appear so users hear the
        // celebration without having to manually explore the screen.
        .onAppear {
            UIAccessibility.post(
                notification: .announcement,
                argument: "Goal reached. Target \(formatValue(targetValue)) \(unit)."
            )
        }
    }

    // MARK: - Helpers

    private func formatValue(_ value: Double) -> String {
        if value == value.rounded() && value >= 10 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    GoalReachedOverlay(
        targetValue: 185.0,
        startValue: 200.2,
        unit: "lb",
        startDate: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(),
        onNewGoal: {},
        onDismiss: {}
    )
}
