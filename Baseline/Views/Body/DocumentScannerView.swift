import SwiftUI
import VisionKit

/// Wraps Apple's VNDocumentCameraViewController for SwiftUI.
struct DocumentScannerView: UIViewControllerRepresentable {
    var onScan: (VNDocumentCameraScan) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: (VNDocumentCameraScan) -> Void
        let onCancel: () -> Void

        init(onScan: @escaping (VNDocumentCameraScan) -> Void, onCancel: @escaping () -> Void) {
            self.onScan = onScan
            self.onCancel = onCancel
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            guard scan.pageCount > 0 else {
                onCancel()
                return
            }
            #if DEBUG
            print("[DocumentScannerView] Captured \(scan.pageCount) page(s)")
            #endif
            onScan(scan)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            #if DEBUG
            print("[DocumentScannerView] Camera error: \(error)")
            #endif
            onCancel()
        }
    }
}
