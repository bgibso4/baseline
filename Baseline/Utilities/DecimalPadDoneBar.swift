import SwiftUI
import UIKit

/// Workaround for SwiftUI bug: `.toolbar(placement: .keyboard)` doesn't show
/// with `.decimalPad` or `.numberPad` keyboard types (FB11423458, unfixed since iOS 15).
///
/// Uses UIKit's native `inputAccessoryView` so the Done bar looks identical to
/// the system keyboard toolbar used by text keyboards.
///
/// Call `DecimalPadDoneBar.install()` once at app launch.
enum DecimalPadDoneBar {

    private static var observer: Any?

    static func install() {
        observer = NotificationCenter.default.addObserver(
            forName: UITextField.textDidBeginEditingNotification,
            object: nil, queue: .main
        ) { note in
            guard let tf = note.object as? UITextField,
                  isNumericKeyboard(tf.keyboardType) else { return }
            guard tf.inputAccessoryView == nil || tf.inputAccessoryView is UIToolbar else { return }
            tf.inputAccessoryView = makeToolbar()
            tf.reloadInputViews()
        }
    }

    private static func isNumericKeyboard(_ type: UIKeyboardType) -> Bool {
        switch type {
        case .decimalPad, .numberPad, .phonePad: return true
        default: return false
        }
    }

    private static func makeToolbar() -> UIToolbar {
        let color = UIColor(CadreColors.accent)
        let bar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        bar.isTranslucent = true
        bar.tintColor = color
        bar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
        bar.setShadowImage(UIImage(), forToolbarPosition: .any)
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(
            title: "Done",
            style: .plain,
            target: nil,
            action: #selector(UIResponder.resignFirstResponder)
        )
        done.tintColor = color
        done.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: color
        ], for: .normal)
        bar.items = [spacer, done]
        return bar
    }
}
