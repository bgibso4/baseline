import SwiftUI

/// Bottom sheet that appears when tapping ··· on the active goal card.
/// Offers Edit, Mark Complete, and Abandon actions.
struct GoalManageSheet: View {
    @Environment(\.dismiss) private var dismiss

    let goal: Goal
    let currentValue: Double
    let unit: String
    let onEdit: () -> Void
    let onComplete: () -> Void
    let onAbandon: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("GOAL")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(CadreColors.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)

            // Progress summary
            progressSummary
                .padding(.horizontal, 20)
                .padding(.bottom, 24)

            // Action buttons
            VStack(spacing: 8) {
                editButton
                completeButton
                abandonButton
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Progress Summary

    private var progressSummary: some View {
        let progressValue = goal.progress(currentValue: currentValue)
        let remaining = goal.remaining(currentValue: currentValue)

        return VStack(spacing: 10) {
            // Current → target value row
            HStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(formatValue(currentValue))
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.5)
                        .foregroundStyle(CadreColors.textPrimary)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(CadreColors.textSecondary)
                    }
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CadreColors.textTertiary)
                    .padding(.horizontal, 8)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(formatValue(goal.targetValue))
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.5)
                        .foregroundStyle(CadreColors.accent)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(CadreColors.textSecondary)
                    }
                }

                Spacer()
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(CadreColors.cardElevated)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(CadreColors.accent)
                        .frame(width: geo.size.width * progressValue, height: 4)
                }
            }
            .frame(height: 4)

            // Footer: X to go + Started date
            HStack {
                Text(remaining > 0 ? "\(formatValue(remaining)) \(unit) to go" : "Goal reached!")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(CadreColors.textSecondary)

                Spacer()

                Text("Started \(startedLabel(goal.startDate))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(CadreColors.textTertiary)
            }
        }
    }

    // MARK: - Action Buttons

    private var editButton: some View {
        Button {
            dismiss()
            onEdit()
        } label: {
            Text("Edit Goal")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(CadreColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var completeButton: some View {
        Button {
            dismiss()
            onComplete()
        } label: {
            Text("Mark Complete")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CadreColors.positive)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(CadreColors.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(CadreColors.divider, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var abandonButton: some View {
        Button {
            dismiss()
            onAbandon()
        } label: {
            Text("Abandon Goal")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(CadreColors.negative)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func formatValue(_ value: Double) -> String {
        if value == value.rounded() && value >= 10 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private func startedLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
