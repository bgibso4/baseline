import SwiftUI
import UIKit

/// UIViewControllerRepresentable wrapping UIImagePickerController for camera capture.
///
/// On simulator where camera is unavailable, displays a placeholder message.
/// TODO v2: Replace with custom camera UI featuring dashed guide frame with accent corner brackets.
struct CameraView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            return makePlaceholderController()
        }

        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }

    // MARK: - Simulator Placeholder

    private func makePlaceholderController() -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 40, weight: .light)
        let iconView = UIImageView(image: UIImage(systemName: "camera.slash", withConfiguration: iconConfig))
        iconView.tintColor = UIColor(white: 0.35, alpha: 1)

        let label = UILabel()
        label.text = "Camera not available on simulator"
        label.textColor = UIColor(white: 0.35, alpha: 1)
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textAlignment = .center

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        cancelButton.tintColor = UIColor(red: 0.42, green: 0.48, blue: 0.58, alpha: 1) // accent
        let cancelAction = onCancel
        cancelButton.addAction(UIAction { _ in
            cancelAction()
        }, for: .touchUpInside)

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(cancelButton)
        stack.setCustomSpacing(24, after: label)

        vc.view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor),
        ])

        return vc
    }
}
