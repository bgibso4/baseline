import SwiftUI

/// The Baseline EKG mark as a strokable shape. Geometry matches the approved
/// onboarding mock's 100×56 viewBox (flat baseline → spike → dip → recovery):
/// `docs/mockups/onboarding-welcome-APPROVED-variant-c-2026-06-08.html`.
struct EKGMark: Shape {
    /// Polyline control points in the mock's 100×56 coordinate space.
    private static let points: [CGPoint] = [
        CGPoint(x: 2, y: 34), CGPoint(x: 30, y: 34), CGPoint(x: 38, y: 34),
        CGPoint(x: 44, y: 14), CGPoint(x: 52, y: 46), CGPoint(x: 60, y: 26),
        CGPoint(x: 66, y: 34), CGPoint(x: 98, y: 34)
    ]

    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 100
        let scaleY = rect.height / 56
        let scaled = Self.points.map {
            CGPoint(x: rect.minX + $0.x * scaleX, y: rect.minY + $0.y * scaleY)
        }
        var path = Path()
        path.move(to: scaled[0])
        for point in scaled.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

#Preview {
    EKGMark()
        .stroke(CadreColors.accentLight,
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        .frame(width: 108, height: 60)
        .padding()
        .background(CadreColors.bg)
}
