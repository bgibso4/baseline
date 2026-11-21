import UIKit

/// Gets a scanned page into the pixel format the on-device model accepts.
enum ScanImagePreparer {

    /// The page height the model's accuracy was measured at. The scan flow can
    /// hand over a page several times this size, which the model reads worse.
    static let longestSide: CGFloat = 2400

    /// Redraws the page as 8-bit sRGB with its orientation applied, no larger
    /// than `longestSide` pixels.
    ///
    /// Camera captures are often extended-range; the model's image input
    /// cannot build a pixel buffer from those and then sees nothing at all.
    /// Returns `nil` for an image with no pixels.
    static func standardRangeImage(from image: UIImage) -> CGImage? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        let pixels = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let shrink = min(1, longestSide / max(pixels.width, pixels.height))
        let size = CGSize(width: (pixels.width * shrink).rounded(), height: (pixels.height * shrink).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        format.opaque = true
        let redrawn = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return redrawn.cgImage
    }
}
