import SwiftUI

/// Step 3 of the scan-entry flow — live camera preview that hands captured
/// images off to the view model for OCR. Overlays a processing indicator
/// while the scan is being parsed.
struct CameraStep: View {
    let vm: ScanEntryViewModel

    var body: some View {
        ZStack {
            DocumentScannerView(
                onScan: { scan in
                    Task {
                        await vm.processScan(scan)
                    }
                },
                onCancel: {
                    vm.goBack()
                }
            )
            .ignoresSafeArea()

            if vm.isProcessing {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProcessingIndicator(size: 56, lineWidth: 5)
                    Text("Reading scan...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CadreColors.textPrimary)
                }
            }
        }
    }
}
