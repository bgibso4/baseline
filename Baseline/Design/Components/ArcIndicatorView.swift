import SwiftUI

/// 270° arc (from 135° bottom-left, sweeping clockwise to 45° bottom-right) with
/// a filled segment showing `fraction` (0...1) of the range, plus an endpoint
/// dot. Label content sits centered inside the arc.
///
/// Visual target: `docs/mockups/today-APPROVED-variant-a-2026-04-04.html`.
/// Reused by the Now screen and (future) Task 28 widgets; lives in
/// Design/Components alongside SparklineView.
struct ArcIndicatorView<Content: View>: View {
    let fraction: Double?
    @ViewBuilder let content: () -> Content

    // Matches mockup: 290 × 248 SVG, radius 145, center at (145, 145)
    private let size = CGSize(width: 290, height: 248)
    private let radius: CGFloat = 145
    private let strokeWidth: CGFloat = 7
    // Arc spans 270°, from 135° (bottom-left) clockwise to 45° (bottom-right)
    // i.e. start at 135°, sweep 270° clockwise.
    private let startAngle = Angle.degrees(135)
    private let sweep: Double = 270

    var body: some View {
        ZStack {
            // Background arc
            ArcShape(startAngle: startAngle, sweepDegrees: sweep, radius: radius)
                .stroke(CadreColors.divider, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))

            // Progress arc
            if let fraction {
                ArcShape(startAngle: startAngle, sweepDegrees: sweep * fraction, radius: radius)
                    .stroke(CadreColors.accent, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))

                // Endpoint dot
                endpointDot(at: fraction)
            }

            // Center content
            content()
                .position(x: size.width / 2, y: radius)
        }
        .frame(width: size.width, height: size.height)
    }

    private func endpointDot(at fraction: Double) -> some View {
        let angle = startAngle + .degrees(sweep * fraction)
        let center = CGPoint(x: size.width / 2, y: radius)
        let x = center.x + radius * CGFloat(cos(angle.radians))
        let y = center.y + radius * CGFloat(sin(angle.radians))
        return ZStack {
            Circle()
                .fill(CadreColors.accent)
                .frame(width: 18, height: 18)
            Circle()
                .fill(CadreColors.textPrimary)
                .frame(width: 7, height: 7)
        }
        .position(x: x, y: y)
    }
}

/// Arc drawn from `startAngle`, sweeping clockwise by `sweepDegrees` around the
/// view's top-center (x = width/2, y = radius). Matches the SVG arc convention
/// used in the approved mockup.
struct ArcShape: Shape {
    let startAngle: Angle
    let sweepDegrees: Double
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.width / 2, y: radius)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: startAngle + .degrees(sweepDegrees),
            clockwise: false
        )
        return path
    }
}
