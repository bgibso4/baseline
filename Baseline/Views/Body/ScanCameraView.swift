import AVFoundation
import PhotosUI
import SwiftUI
import UIKit
import Vision

/// Custom camera view with live document detection and guide overlay.
///
/// On device: AVCaptureSession with back camera, real-time VNDetectRectanglesRequest,
/// guide overlay with corner brackets that turn green when a document is detected.
///
/// On simulator: Falls back to PHPickerViewController (photo library).
struct ScanCameraView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        #if targetEnvironment(simulator)
        return SimulatorPickerController(onCapture: onCapture, onCancel: onCancel)
        #else
        return ScanCameraViewController(onCapture: onCapture, onCancel: onCancel)
        #endif
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {}
}

// MARK: - Camera View Controller (Device)

#if !targetEnvironment(simulator)
private final class ScanCameraViewController: UIViewController,
    AVCaptureVideoDataOutputSampleBufferDelegate,
    AVCapturePhotoCaptureDelegate
{
    private let onCapture: (UIImage) -> Void
    private let onCancel: () -> Void

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let guideOverlay = GuideOverlayView()

    private var lastDetectionTime: CFTimeInterval = 0
    private var documentDetected = false

    init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        self.onCapture = onCapture
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupPreview()
        setupOverlay()
        setupControls()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        guideOverlay.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }

    // MARK: - Setup

    private func setupCamera() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        // Photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        // Video data output for detection
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.baseline.scan.detection"))
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        session.commitConfiguration()
    }

    private func setupPreview() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
    }

    private func setupOverlay() {
        guideOverlay.frame = view.bounds
        guideOverlay.backgroundColor = .clear
        guideOverlay.isOpaque = false
        view.addSubview(guideOverlay)
    }

    private func setupControls() {
        // Close button (top-left)
        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        let closeConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: closeConfig), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 16
        closeButton.clipsToBounds = true
        closeButton.addAction(UIAction { [weak self] _ in
            self?.onCancel()
        }, for: .touchUpInside)
        view.addSubview(closeButton)

        // Hint label (above shutter)
        let hintPill = PaddedLabel()
        hintPill.translatesAutoresizingMaskIntoConstraints = false
        hintPill.text = "Align sheet within frame"
        hintPill.font = .systemFont(ofSize: 13, weight: .semibold)
        hintPill.textColor = .white
        hintPill.textAlignment = .center
        hintPill.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        hintPill.layer.cornerRadius = 16
        hintPill.clipsToBounds = true
        hintPill.tag = 100
        view.addSubview(hintPill)

        // Shutter button (bottom center)
        let shutterButton = UIButton(type: .custom)
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.backgroundColor = .white
        shutterButton.layer.cornerRadius = 35
        shutterButton.layer.borderWidth = 4
        shutterButton.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        shutterButton.addAction(UIAction { [weak self] _ in
            self?.capturePhoto()
        }, for: .touchUpInside)
        view.addSubview(shutterButton)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),

            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            shutterButton.widthAnchor.constraint(equalToConstant: 70),
            shutterButton.heightAnchor.constraint(equalToConstant: 70),

            hintPill.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintPill.bottomAnchor.constraint(equalTo: shutterButton.topAnchor, constant: -16),
        ])
    }

    // MARK: - Capture

    private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        onCapture(image)
    }

    // MARK: - Document Detection

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        guard now - lastDetectionTime >= 0.2 else { return }
        lastDetectionTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectRectanglesRequest { [weak self] request, _ in
            let detected = !(request.results?.isEmpty ?? true)
            DispatchQueue.main.async {
                self?.updateDetectionState(detected)
            }
        }
        request.minimumConfidence = 0.6
        request.minimumAspectRatio = 0.5
        request.maximumAspectRatio = 0.9
        request.maximumObservations = 1

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }

    private func updateDetectionState(_ detected: Bool) {
        guard detected != documentDetected else { return }
        documentDetected = detected
        guideOverlay.documentDetected = detected

        if let hintLabel = view.viewWithTag(100) as? UILabel {
            hintLabel.text = detected ? "Good \u{2014} tap to capture" : "Align sheet within frame"
        }
    }
}
#endif

// MARK: - Guide Overlay View

private final class GuideOverlayView: UIView {
    var documentDetected = false {
        didSet { setNeedsDisplay() }
    }

    private let guideWidth: CGFloat = 240
    private let guideHeight: CGFloat = 340
    private let verticalOffset: CGFloat = -40
    private let bracketLength: CGFloat = 28
    private let bracketLineWidth: CGFloat = 3

    private let accentColor = UIColor(red: 0.42, green: 0.48, blue: 0.58, alpha: 1) // #6B7B94
    private let detectedColor = UIColor(red: 0.298, green: 0.686, blue: 0.314, alpha: 1) // #4CAF50

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let centerX = bounds.midX
        let centerY = bounds.midY + verticalOffset
        let guideRect = CGRect(
            x: centerX - guideWidth / 2,
            y: centerY - guideHeight / 2,
            width: guideWidth,
            height: guideHeight
        )

        let color = documentDetected ? detectedColor : accentColor

        // Dashed inner rectangle (solid when detected)
        ctx.setStrokeColor(color.withAlphaComponent(0.5).cgColor)
        ctx.setLineWidth(1)
        if documentDetected {
            ctx.setLineDash(phase: 0, lengths: [])
        } else {
            ctx.setLineDash(phase: 0, lengths: [6, 4])
        }
        ctx.stroke(guideRect)

        // Corner brackets
        ctx.setLineDash(phase: 0, lengths: [])
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(bracketLineWidth)
        ctx.setLineCap(.round)

        let minX = guideRect.minX
        let minY = guideRect.minY
        let maxX = guideRect.maxX
        let maxY = guideRect.maxY
        let bl = bracketLength

        // Top-left
        ctx.move(to: CGPoint(x: minX, y: minY + bl))
        ctx.addLine(to: CGPoint(x: minX, y: minY))
        ctx.addLine(to: CGPoint(x: minX + bl, y: minY))
        ctx.strokePath()

        // Top-right
        ctx.move(to: CGPoint(x: maxX - bl, y: minY))
        ctx.addLine(to: CGPoint(x: maxX, y: minY))
        ctx.addLine(to: CGPoint(x: maxX, y: minY + bl))
        ctx.strokePath()

        // Bottom-left
        ctx.move(to: CGPoint(x: minX, y: maxY - bl))
        ctx.addLine(to: CGPoint(x: minX, y: maxY))
        ctx.addLine(to: CGPoint(x: minX + bl, y: maxY))
        ctx.strokePath()

        // Bottom-right
        ctx.move(to: CGPoint(x: maxX - bl, y: maxY))
        ctx.addLine(to: CGPoint(x: maxX, y: maxY))
        ctx.addLine(to: CGPoint(x: maxX, y: maxY - bl))
        ctx.strokePath()
    }
}

// MARK: - Padded Label

private final class PaddedLabel: UILabel {
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + 24, height: size.height + 12)
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.insetBy(dx: 12, dy: 6))
    }
}

// MARK: - Simulator Fallback (PHPicker)

#if targetEnvironment(simulator)
private final class SimulatorPickerController: UIViewController, PHPickerViewControllerDelegate {
    private let onCapture: (UIImage) -> Void
    private let onCancel: () -> Void

    init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        self.onCapture = onCapture
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Only present if we haven't already
        guard presentedViewController == nil else { return }

        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else {
            onCancel()
            return
        }

        provider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
            DispatchQueue.main.async {
                if let uiImage = image as? UIImage {
                    self?.onCapture(uiImage)
                } else {
                    self?.onCancel()
                }
            }
        }
    }
}
#endif
