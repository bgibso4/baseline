import SwiftUI

/// 270° arc (from 135° bottom-left, sweeping clockwise to 45° bottom-right) with
/// a filled segment showing `fraction` (0...1) of the range, plus an endpoint
/// dot. Label content sits centered inside the arc.
///
/// The arc animates like a physical gauge needle: sweeps from 0 on first
/// appear, and eases to new values when `fraction` changes. Smooth motion
/// requires `ArcShape` and `ArcEndpointShape` to be Animatable — without
/// that, SwiftUI can't interpolate the Path and the arc jumps between
/// frames even with an `.animation()` modifier in the call site.
///
/// Visual target: `docs/mockups/today-APPROVED-variant-a-2026-04-04.html`.
struct ArcIndicatorView<Content: View>: View {
    let fraction: Double?
    @ViewBuilder let content: () -> Content

    // Matches mockup: 290 × 248 SVG, radius 145, center at (145, 145)
    private let size = CGSize(width: 290, height: 248)
    private let radius: CGFloat = 145
    private let strokeWidth: CGFloat = 7
    // Arc spans 270°, from 135° (bottom-left) clockwise to 45° (bottom-right)
    private let startAngle = Angle.degrees(135)
    private let sweep: Double = 270

    /// The sweep the arc is currently rendering. Drives both the stroke
    /// and the endpoint dot so they stay synchronized frame-by-frame.
    @State private var displaySweep: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let gaugeAnimation: Animation = .spring(duration: 1.5, bounce: 0.12)

    var body: some View {
        ZStack {
            // Background arc (full 270° track)
            ArcShape(startAngle: startAngle, sweepDegrees: sweep, radius: radius)
                .stroke(CadreColors.divider, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))

            // Progress arc + endpoint dot, driven by the same animatable sweep
            if fraction != nil {
                ArcShape(startAngle: startAngle, sweepDegrees: displaySweep, radius: radius)
                    .stroke(CadreColors.accent, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                    .animation(reduceMotion ? nil : gaugeAnimation, value: displaySweep)

                // Outer dot (accent, 18pt diameter → 9pt radius)
                ArcEndpointShape(startAngle: startAngle, sweepDegrees: displaySweep, radius: radius, dotRadius: 9)
                    .fill(CadreColors.accent)
                    .animation(reduceMotion ? nil : gaugeAnimation, value: displaySweep)

                // Inner dot (textPrimary, 7pt diameter → 3.5pt radius)
                ArcEndpointShape(startAngle: startAngle, sweepDegrees: displaySweep, radius: radius, dotRadius: 3.5)
                    .fill(CadreColors.textPrimary)
                    .animation(reduceMotion ? nil : gaugeAnimation, value: displaySweep)
            }

            // Center content
            content()
                .position(x: size.width / 2, y: radius)
        }
        .frame(width: size.width, height: size.height)
        .onAppear {
            displaySweep = sweep * (fraction ?? 0)
        }
        .onChange(of: fraction) { _, newValue in
            displaySweep = sweep * (newValue ?? 0)
        }
    }
}

/// Arc drawn from `startAngle`, sweeping clockwise by `sweepDegrees` around the
/// view's top-center (x = width/2, y = radius).
///
/// Animatable: exposing `sweepDegrees` via `animatableData` is what lets
/// SwiftUI re-invoke `path(in:)` with interpolated values each frame —
/// the difference between a gauge needle sweeping and a line snapping.
struct ArcShape: Shape, Animatable {
    let startAngle: Angle
    var sweepDegrees: Double
    let radius: CGFloat

    var animatableData: Double {
        get { sweepDegrees }
        set { sweepDegrees = newValue }
    }

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

/// A filled dot positioned at the tip of an arc with the given sweep.
/// Shares the `sweepDegrees` input with `ArcShape` so the dot tracks the
/// arc's end point frame-by-frame while animating — without this, the
/// dot would chord straight between old and new positions, cutting
/// through the interior of the arc instead of riding along it.
struct ArcEndpointShape: Shape, Animatable {
    let startAngle: Angle
    var sweepDegrees: Double
    let radius: CGFloat
    let dotRadius: CGFloat

    var animatableData: Double {
        get { sweepDegrees }
        set { sweepDegrees = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.width / 2, y: radius)
        let angle = startAngle + .degrees(sweepDegrees)
        let x = center.x + radius * CGFloat(cos(angle.radians))
        let y = center.y + radius * CGFloat(sin(angle.radians))
        var path = Path()
        path.addArc(
            center: CGPoint(x: x, y: y),
            radius: dotRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(360),
            clockwise: false
        )
        return path
    }
}
