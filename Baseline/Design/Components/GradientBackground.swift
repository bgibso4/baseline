import SwiftUI

/// Subtle radial gradient background that replaces flat `CadreColors.bg`.
///
/// Adds depth with a barely-visible dusty-blue glow radiating from a
/// configurable anchor point. The effect is intentionally understated —
/// perceptible as "not flat" without reading as an obvious gradient.
struct GradientBackground: View {
    var center: UnitPoint = .top

    var body: some View {
        RadialGradient(
            colors: [
                CadreColors.bgGradientCenter,
                CadreColors.bgGradientEdge
            ],
            center: center,
            startRadius: 0,
            endRadius: 600
        )
        .ignoresSafeArea()
    }
}
