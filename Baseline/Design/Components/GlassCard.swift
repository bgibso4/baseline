import SwiftUI

/// Applies a translucent "glass" card treatment: semi-transparent fill
/// with a thin bright border. Use on views that sit over `GradientBackground`
/// so the gradient bleeds through subtly.
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = CadreRadius.md

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(CadreColors.cardGlass)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(CadreColors.cardBorder, lineWidth: 1)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = CadreRadius.md) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}
