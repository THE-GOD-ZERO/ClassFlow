import SwiftUI
import UIKit

// Observe attempted interactive dismissal without writing draft state to the store.
@MainActor
struct DraftDismissGuard: UIViewControllerRepresentable {
    let dirty: Bool
    let onAttempt: () -> Void
    func makeUIViewController(context: Context) -> Observer { Observer() }
    func updateUIViewController(_ controller: Observer, context: Context) {
        controller.dirty = dirty
        controller.onAttempt = onAttempt
        controller.install()
    }
    final class Observer: UIViewController, UIAdaptivePresentationControllerDelegate {
        var dirty = false
        var onAttempt: () -> Void = {}
        private weak var previousDelegate: (any UIAdaptivePresentationControllerDelegate)?
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); install() }
        func install() {
            // SwiftUI installs the hosting controller after the representable is created.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                var host: UIViewController = self
                while let parent = host.parent { host = parent }
                guard let presentation = host.presentationController else { return }
                if presentation.delegate !== self {
                    self.previousDelegate = presentation.delegate
                    presentation.delegate = self
                }
            }
        }
        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
            !dirty && (previousDelegate?.presentationControllerShouldDismiss?(presentationController) ?? true)
        }
        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) { onAttempt() }
        func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
            previousDelegate?.presentationControllerWillDismiss?(presentationController)
        }
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            // Preserve SwiftUI's presentation binding/lifecycle when a clean sheet is swiped away.
            previousDelegate?.presentationControllerDidDismiss?(presentationController)
        }
    }
}

@MainActor
struct DraftExitModifier: ViewModifier {
    let dirty: Bool
    @Binding var confirming: Bool
    let discard: () -> Void
    func body(content: Content) -> some View {
        content
            .interactiveDismissDisabled(dirty)
            .background(DraftDismissGuard(dirty: dirty) { confirming = true })
            .confirmationDialog("放弃更改？", isPresented: $confirming, titleVisibility: .visible) {
                Button("放弃", role: .destructive, action: discard)
                Button("继续编辑", role: .cancel) {}
            } message: { Text("未保存的更改将丢失。") }
    }
}
