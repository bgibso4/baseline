import SwiftUI
import UIKit

// MARK: - Landscape Hosting (forces landscape orientation for fullscreen chart)

struct LandscapeHostingController<Content: View>: UIViewControllerRepresentable {
    let content: Content

    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        LandscapeHostingVC(rootView: content)
    }

    func updateUIViewController(_ uiViewController: UIHostingController<Content>, context: Context) {
        uiViewController.rootView = content
    }
}

private class LandscapeHostingVC<Content: View>: UIHostingController<Content> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .landscape
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        .landscapeRight
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        BaselineAppDelegate.allowLandscape = true
        setNeedsUpdateOfSupportedInterfaceOrientations()
        requestRotation(to: .landscape)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        BaselineAppDelegate.allowLandscape = false
        requestRotation(to: .portrait)
    }

    private func requestRotation(to mask: UIInterfaceOrientationMask) {
        let scene = view.window?.windowScene
            ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        scene?.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
    }
}
