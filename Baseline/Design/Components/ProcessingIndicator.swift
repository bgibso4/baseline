import SwiftUI

/// On-brand replacement for the system `ProgressView()` spinner. A 270°
/// arc with a gradient fading into transparency rotates continuously —
/// echoes the Now-screen arc motif so long-running operations (scan OCR,
/// data load) feel like part of the app rather than a system fallback.
///
/// Respects `accessibilityReduceMotion`: the arc stays still and its
/// opacity pulses instead of spinning, so there's still visible feedback
/// that work is in flight without any sustained motion.
struct ProcessingIndicator: View {
    var size: CGFloat = 48
    var lineWidth: CGFloat = 4

    @State private var rotation: Double = 0
    @State private var pulse: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [
                        CadreColors.accent.opacity(0.05),
                        CadreColors.accent
                    ]),
                    center: .center,
                    startAngle: .degrees(0),
                    endAngle: .degrees(270)
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .opacity(pulse)
            .onAppear {
                if reduceMotion {
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                        pulse = 0.45
                    }
                } else {
                    withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
            }
    }
}

#Preview {
    ProcessingIndicator()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
}
