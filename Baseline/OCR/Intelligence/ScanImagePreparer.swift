import UIKit

/// Gets a scanned page into the pixel format the on-device model accepts.
enum ScanImagePreparer {

    /// Redraws the page as 8-bit sRGB with its orientation applied.
    ///
    /// Camera captures are often extended-range; the model's image input
    /// cannot build a pixel buffer from those and then sees nothing at all.
    /// Returns `nil` for an image with no pixels.
    static func standardRangeImage(from image: UIImage) -> CGImage? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.preferredRange = .standard
        format.opaque = true
        let redrawn = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return redrawn.cgImage
    }
}
