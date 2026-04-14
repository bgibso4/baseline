import SwiftUI

struct GoalCard: View {
    let goal: Goal?
    let currentValue: Double?
    let unit: String
    let onSetGoal: () -> Void
    let onManageGoal: () -> Void

    var body: some View {
        if let goal {
            activeCard(goal: goal)
        } else {
            emptyCard
        }
    }

    // MARK: - Empty State

    private var emptyCard: some View {
        Button(action: onSetGoal) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: CadreRadius.sm)
                        .fill(CadreColors.cardElevated)
                        .frame(width: 32, height: 32)
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CadreColors.accent)
                }
                Text("Set a goal")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(CadreColors.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: CadreRadius.md)
                    .stroke(
                        CadreColors.divider,
                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Active State

    private func activeCard(goal: Goal) -> some View {
        let current = currentValue ?? goal.startValue
        let progressValue = goal.progress(currentValue: current)
        let remaining = goal.remaining(currentValue: current)

        return VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                if let targetDate = goal.targetDate {
                    Text("GOAL \u{00B7} by \(goalDateLabel(targetDate))")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(CadreColors.accent)
                } else {
                    Text("GOAL")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(CadreColors.accent)
                }
                Spacer()
                Button(action: onManageGoal) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CadreColors.textSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            // Value row: current → target
            HStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(formatValue(current))
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
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

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
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            // Footer
            HStack {
                Text(remaining > 0 ? "\(formatValue(remaining)) \(unit) to go" : "Goal reached!")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(CadreColors.textSecondary)

                Spacer()

                if let days = goal.daysRemaining {
                    Text("\(days) days left")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(CadreColors.textTertiary)
                } else {
                    Text(String(format: "%.0f%%", progressValue * 100))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(CadreColors.textTertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: CadreRadius.md)
                .fill(CadreColors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: CadreRadius.md)
                        .stroke(CadreColors.divider, lineWidth: 1)
                )
        )
    }

    // MARK: - Helpers

    private func formatValue(_ value: Double) -> String {
        if value == value.rounded() && value >= 10 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private func goalDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
