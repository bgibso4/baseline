import SwiftUI

/// Bottom-sheet metric picker for the Trends tab.
///
/// Replaces the overlay dropdown. Groups metrics by category, supports a
/// compare toggle (secondary metric selection), and only shows metrics
/// that have recorded data.
struct MetricPickerSheet: View {
    @Binding var selectedMetric: TrendMetric
    @Binding var compareEnabled: Bool
    @Binding var secondaryMetric: TrendMetric?
    @Binding var previousPeriod: PreviousPeriodType?
    let availableMetrics: [TrendMetric]
    var onDismiss: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    private let sheetBg = Color(red: 28/255, green: 28/255, blue: 34/255)
    private let secondary = Color(hex: "B89968") // --secondary from design tokens (dusty secondary)

    /// Drives a content-level lift-in when the sheet presents. The system
    /// sheet chrome handles the card slide-up; this adds a layered spring
    /// on the inner content so the picker reads as "settling into place"
    /// rather than arriving fully-formed.
    @State private var contentPresented: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            sheetHandle
            compareToggleRow
            divider

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(TrendMetricGroup.allCases, id: \.self) { group in
                        let groupMetrics = availableMetrics.filter { $0.group == group }
                        if !groupMetrics.isEmpty {
                            sectionLabel(group.rawValue)
                            ForEach(groupMetrics, id: \.self) { metric in
                                metricRow(metric)
                            }
                        }
                    }

                    // Compare-only sections
                    if compareEnabled {
                        divider
                            .padding(.vertical, 4)

                        sectionLabel("Previous Period")
                        compareOptionRow(period: .lastMonth, icon: "calendar")
                        compareOptionRow(period: .lastYear, icon: "calendar.badge.clock")

                        sectionLabel("Program")
                        programRow
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .background(sheetBg)
        .opacity(contentPresented ? 1 : 0)
        .scaleEffect(contentPresented ? 1 : 0.96, anchor: .top)
        .offset(y: contentPresented ? 0 : 12)
        .onAppear {
            if reduceMotion {
                contentPresented = true
                return
            }
            withAnimation(.spring(duration: 0.55, bounce: 0.22).delay(0.08)) {
                contentPresented = true
            }
        }
    }

    // MARK: - Drag handle

    private var sheetHandle: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(CadreColors.textTertiary)
            .frame(width: 36, height: 5)
            .padding(.top, 10)
            .padding(.bottom, 14)
    }

    // MARK: - Compare toggle (sticky)

    private var compareToggleRow: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(CadreColors.cardElevated)
                    .frame(width: 26, height: 26)
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CadreColors.textSecondary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Compare")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CadreColors.textPrimary)
                Text(compareEnabled ? "Primary is locked \u{2014} tap others to compare" : "Overlay a second metric")
                    .font(.system(size: 10))
                    .foregroundStyle(CadreColors.textTertiary)
            }
            Spacer()
            Toggle("", isOn: $compareEnabled)
                .labelsHidden()
                .tint(CadreColors.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    // MARK: - Metric row

    private func metricRow(_ metric: TrendMetric) -> some View {
        let isPrimary = metric == selectedMetric
        let isSecondary = compareEnabled && metric == secondaryMetric

        return Button {
            Haptics.selection()
            if compareEnabled {
                // Primary is locked in compare mode; tap sets secondary
                if !isPrimary {
                    previousPeriod = nil // Clear period when picking a metric
                    secondaryMetric = metric
                    onDismiss?()
                    dismiss()
                }
            } else {
                selectedMetric = metric
                onDismiss?()
                dismiss()
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isPrimary ? CadreColors.accent.opacity(0.15)
                              : isSecondary ? secondary.opacity(0.15)
                              : CadreColors.cardElevated)
                        .frame(width: 26, height: 26)
                    Image(systemName: metric.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isPrimary ? CadreColors.accent
                                         : isSecondary ? secondary
                                         : CadreColors.textSecondary)
                }
                Text(metric.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CadreColors.textPrimary)
                Spacer()
                if isPrimary {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CadreColors.accent)
                } else if isSecondary {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isPrimary ? CadreColors.accent.opacity(0.06)
                          : isSecondary ? secondary.opacity(0.06)
                          : Color.clear)
            )
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(compareEnabled && isPrimary)
        .opacity(compareEnabled && isPrimary ? 0.7 : 1.0)
    }

    // MARK: - Section label

    private func sectionLabel(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(CadreColors.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    // MARK: - Compare option rows

    private func compareOptionRow(period: PreviousPeriodType, icon: String) -> some View {
        let isActive = previousPeriod == period
        return Button {
            Haptics.selection()
            // Clear secondary metric when picking a period
            secondaryMetric = nil
            previousPeriod = period
            onDismiss?()
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(isActive ? secondary : CadreColors.textSecondary)
                    .frame(width: 26)
                Text(period.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CadreColors.textPrimary)
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isActive ? secondary.opacity(0.06) : Color.clear)
            )
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var programRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "flag")
                .font(.system(size: 12))
                .foregroundStyle(CadreColors.textTertiary)
                .frame(width: 26)
            Text("Apex phases")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CadreColors.textTertiary)
            Spacer()
            Text("Soon")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(CadreColors.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(CadreColors.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .opacity(0.35)
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }
}
