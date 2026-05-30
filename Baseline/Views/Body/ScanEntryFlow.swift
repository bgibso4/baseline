import SwiftUI
import SwiftData
import TipKit

/// Multi-step scan entry flow — 5 screens driven by `ScanEntryViewModel`.
///
/// Visual target: `docs/mockups/scan-entry-flow-2026-04-05.html`
///
/// Flow: Scan Type -> Input Method -> (Camera -> Review) OR Manual Entry -> Save.
/// In v1, only InBody 570 is supported.
struct ScanEntryFlow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let injectedVM: ScanEntryViewModel?
    @State private var vm: ScanEntryViewModel?
    @FocusState private var isFieldFocused: Bool

    init(viewModel: ScanEntryViewModel? = nil) {
        self.injectedVM = viewModel
    }

    private var resolvedVM: ScanEntryViewModel? {
        vm ?? injectedVM
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground(center: .top)
                    .contentShape(Rectangle())
                    .onTapGesture { isFieldFocused = false }

                if let vm = resolvedVM {
                    // AnyView breaks the type metadata chain — without it, the
                    // combined type of all 5 steps causes a stack overflow in
                    // Swift's type decoder on ARM devices.
                    switch vm.currentStep {
                    case .selectType:
                        AnyView(ScanTypeStep(vm: vm, onClose: { dismiss() }))
                    case .selectMethod:
                        AnyView(InputMethodStep(vm: vm))
                    case .camera:
                        AnyView(CameraStep(vm: vm))
                    case .review:
                        AnyView(ScanReviewForm(
                            vm: vm,
                            mode: .review,
                            onClose: { dismiss() },
                            focusBinding: $isFieldFocused
                        ))
                    case .manualEntry:
                        AnyView(ScanReviewForm(
                            vm: vm,
                            mode: .manual,
                            onClose: { dismiss() },
                            focusBinding: $isFieldFocused
                        ))
                    }
                }
            }
        }
        .onAppear {
            if injectedVM == nil, vm == nil {
                vm = ScanEntryViewModel(modelContext: modelContext)
            }
        }
        // Surface scan-save failures. Without this, `performSave` writes
        // the error into the VM and nothing displays it — the user taps
        // Save, nothing happens, and their scan is lost silently.
        .alert(
            "Couldn't Save Scan",
            isPresented: Binding(
                get: { resolvedVM?.errorMessage != nil },
                set: { if !$0 { resolvedVM?.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                resolvedVM?.errorMessage = nil
            }
        } message: {
            Text(resolvedVM?.errorMessage ?? "Something went wrong while saving. Try again.")
        }
    }
}

#Preview {
    ScanEntryFlow()
        .modelContainer(for: [Scan.self, Measurement.self], inMemory: true)
        .preferredColorScheme(.dark)
}
