import UIKit
import Vision
import CoreImage

enum DocumentCorrector {

    /// Detect document edges and apply perspective correction.
    /// Falls back to the original image if no document is detected.
    static func correctPerspective(_ image: UIImage) async -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let request = VNDetectDocumentSegmentationRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return image
        }

        guard let result = request.results?.first,
              let detectedDocument = result as? VNRectangleObservation else {
            return image
        }

        return applyPerspectiveCorrection(to: image, using: detectedDocument) ?? image
    }

    /// Crop a normalized rect (0–1 coordinate space) from an image.
    static func cropRegion(_ image: UIImage, normalizedRect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        let cropRect = CGRect(
            x: normalizedRect.origin.x * w,
            y: normalizedRect.origin.y * h,
            width: normalizedRect.width * w,
            height: normalizedRect.height * h
        )
        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - Private

    private static func applyPerspectiveCorrection(
        to image: UIImage,
        using observation: VNRectangleObservation
    ) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let imageSize = ciImage.extent.size

        func denormalize(_ point: CGPoint) -> CIVector {
            CIVector(x: point.x * imageSize.width, y: point.y * imageSize.height)
        }

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(denormalize(observation.topLeft), forKey: "inputTopLeft")
        filter.setValue(denormalize(observation.topRight), forKey: "inputTopRight")
        filter.setValue(denormalize(observation.bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(denormalize(observation.bottomRight), forKey: "inputBottomRight")

        guard let output = filter.outputImage else { return nil }
        let context = CIContext()
        guard let cgOutput = context.createCGImage(output, from: output.extent) else { return nil }

        let resultImage = UIImage(cgImage: cgOutput)
        if resultImage.size.width > resultImage.size.height {
            return UIImage(cgImage: cgOutput, scale: 1.0, orientation: .right)
        }
        return resultImage
    }
}
