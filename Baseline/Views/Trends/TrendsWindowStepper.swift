import SwiftUI

/// Compact chevron-left / label / chevron-right row (#62 — Whoop-style nav)
/// that steps backward and forward through windows of the selected time range.
/// Hidden by the caller for the `.all` range (only one window).
///
/// Shared by the inline and fullscreen charts. Presentational: it drives the
/// view model's window stepping and reports each step via `onStep`, so the
/// caller can clear its own crosshair selection (inline vs fullscreen own
/// separate selection state).
struct TrendsWindowStepper: View {
    let vm: TrendsViewModel?
    let onStep: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    vm?.stepWindow(by: -1)
                    onStep()
                    vm?.refresh()
                }
                Haptics.selection()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(
                        (vm?.canStepBackward ?? false)
                            ? CadreColors.textSecondary
                            : CadreColors.textTertiary.opacity(0.3)
                    )
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!(vm?.canStepBackward ?? false))
            .accessibilityLabel("Previous period")
            .accessibilityIdentifier(A11yID.Trends.windowStepBack)

            Text(vm?.currentWindowLabel ?? "")
                // Use semantic .caption so Dynamic Type audit recognises this
                // as fully scalable. .caption (12pt default) is the smallest
                // style that passes; .caption2 (11pt) with weight modifier
                // causes a tool false-positive. Previously .system(size:10)
                // was non-scalable and caused a DT "unsupported" failure.
                .font(.caption.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(CadreColors.textPrimary)
                .contentTransition(.numericText())
                .animation(.snappy, value: vm?.windowEndDate)
                .lineLimit(1)
                .fixedSize()
                // Hide from accessibility when the label is empty (no-data state)
                // to prevent "label not human-readable" audit failure for an
                // empty-string StaticText.
                .accessibilityHidden((vm?.currentWindowLabel ?? "").isEmpty)

            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    vm?.stepWindow(by: 1)
                    onStep()
                    vm?.refresh()
                }
                Haptics.selection()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(
                        (vm?.canStepForward ?? false)
                            ? CadreColors.textSecondary
                            : CadreColors.textTertiary.opacity(0.3)
                    )
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!(vm?.canStepForward ?? false))
            .accessibilityLabel("Next period")
            .accessibilityIdentifier(A11yID.Trends.windowStepForward)
        }
        .padding(.horizontal, 4)
    }
}
