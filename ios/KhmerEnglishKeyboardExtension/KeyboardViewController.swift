import UIKit

final class KeyboardViewController: UIInputViewController {
    private var language: KeyboardMode = .khmer
    private var page: KeyboardPage = .normal

    // Gesture state for "change language by swipe" behavior.
    private var swipeStartPoint: CGPoint?
    private weak var langKeyButton: KeyboardKeyButton?
    private var langSwipeGestureRecognizer: UIPanGestureRecognizer?
    private var didSwipeToggleLanguage = false

    private lazy var rootStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.distribution = .fillEqually
        stack.alignment = .fill
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(white: 0.98, alpha: 1.0)
        view.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            rootStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            rootStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
        ])
        rebuildKeyboard()
    }

    private func rebuildKeyboard() {
        // Remove arranged subviews.
        for sub in rootStack.arrangedSubviews {
            rootStack.removeArrangedSubview(sub)
            sub.removeFromSuperview()
        }

        let layout = KeyboardLayouts.layout(language: language, page: page)

        langKeyButton = nil
        langSwipeGestureRecognizer = nil

        for row in layout.rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.alignment = .fill
            rowStack.distribution = .fillEqually
            rowStack.spacing = 6

            for key in row.keys {
                let btn = KeyboardKeyButton(key: key, onAction: { [weak self] key, action in
                    self?.handleKey(key, action: action)
                })
                btn.heightAnchor.constraint(equalToConstant: 44).isActive = true

                if key.code == KeyCodes.modeChange {
                    langKeyButton = btn

                    // Attach swipe recognition ONLY to the language key to avoid
                    // interfering with normal taps on other keys.
                    let pan = UIPanGestureRecognizer(target: self, action: #selector(handleSwipeGesture(_:)))
                    langSwipeGestureRecognizer = pan
                    btn.addGestureRecognizer(pan)
                }

                rowStack.addArrangedSubview(btn)
            }

            rootStack.addArrangedSubview(rowStack)
        }
    }

    private func handleKey(_ key: KeyboardKey, action: KeyboardKeyAction) {
        let outputCode: Int = {
            switch action {
            case .longPress:
                return key.longPressCode ?? key.code
            case .tap, .repeatTick:
                return key.code
            }
        }()

        let wasShiftPage = (page == .shift)

        // Special control keys.
        switch outputCode {
        case KeyCodes.modeChange:
            // Avoid double-toggle: a swipe might end with a tap-up as well.
            if action == .tap, didSwipeToggleLanguage {
                didSwipeToggleLanguage = false
                return
            }
            toggleLanguage()
            return
        case KeyCodes.switchNextInputMode:
            return
        case KeyCodes.shift:
            page = .shift
            rebuildKeyboard()
            return
        case KeyCodes.unshift:
            page = .normal
            rebuildKeyboard()
            return
        case KeyCodes.abc:
            page = .normal
            rebuildKeyboard()
            return
        case KeyCodes.sym:
            page = .symbol
            rebuildKeyboard()
            return
        case KeyCodes.symUnshift:
            page = .symbol
            rebuildKeyboard()
            return
        case KeyCodes.symShift:
            page = .symbolShift
            rebuildKeyboard()
            return
        case KeyCodes.numberShift:
            page = .number
            rebuildKeyboard()
            return
        case KeyCodes.delete:
            deleteBackward()
            return
        case KeyCodes.done:
            insertText("\n")
            return
        case KeyCodes.space:
            insertText(" ")
            return
        default:
            break
        }

        // Insert text for all remaining codes.
        guard let textToInsert = outputString(for: outputCode) else { return }
        insertText(textToInsert)

        // Kotlin resets keyboard page back to NORMAL after a SHIFT-page key press.
        if wasShiftPage {
            page = .normal
            rebuildKeyboard()
        }
    }

    private func outputString(for code: Int) -> String? {
        // Khmer long-press combinations from Android's `R2KhmerService.onKey(...)`.
        switch code {
        case KeyCodes.am:
            return "ាំ"
        case KeyCodes.om:
            return "ុំ"
        case KeyCodes.os:
            return "ោះ"
        case KeyCodes.asVowel:
            return "េះ"
        case KeyCodes.ors:
            return "ុះ"
        case KeyCodes.ies:
            return "ិះ"
        default:
            break
        }

        guard code >= 0, let scalar = UnicodeScalar(code) else { return nil }
        return String(scalar)
    }

    private func insertText(_ text: String) {
        textDocumentProxy.insertText(text)
    }

    private func deleteBackward() {
        textDocumentProxy.deleteBackward()
    }

    private func toggleLanguage() {
        language = (language == .khmer) ? .english : .khmer
        rebuildKeyboard()
    }

    @objc private func handleSwipeGesture(_ gr: UIPanGestureRecognizer) {
        let velocity = gr.velocity(in: view)
        let velocityX = velocity.x
        let velocityY = velocity.y

        switch gr.state {
        case .began:
            swipeStartPoint = gr.location(in: view)
            return
        case .ended, .cancelled:
            break
        default:
            return
        }

        guard let start = swipeStartPoint else { return }
        let end = gr.location(in: view)

        let distanceX = end.x - start.x
        let distanceY = end.y - start.y

        // Mirrors `SWIPE_VELOCITY_THRESHOLD = 50` from the Kotlin keyboard.
        let velocityThreshold: CGFloat = 50

        var swipeThreshold = view.bounds.width / 2
        var isChangeLanguageKeySwipe = false
        if let langKeyButton {
            let langRect = langKeyButton.convert(langKeyButton.bounds, to: view)
            if langRect.contains(start) && langRect.contains(end) {
                isChangeLanguageKeySwipe = true
                swipeThreshold = langRect.width / 4
            }
        }

        // Kotlin condition:
        // abs(distanceX) > abs(distanceY) && abs(distanceX) > swipeThreshold && abs(velocityX) > SWIPE_VELOCITY_THRESHOLD
        if abs(distanceX) > abs(distanceY),
           abs(distanceX) > swipeThreshold,
           abs(velocityX) > velocityThreshold,
           isChangeLanguageKeySwipe {
            // Direction is used in Kotlin, but the current Android implementation always toggles language.
            _ = distanceX > 0 ? 1 : -1
            didSwipeToggleLanguage = true
            toggleLanguage()
            return
        }

        // Kotlin also supports swipe up/down (but Android currently no-ops them).
        // We leave it as a no-op for now.
        _ = distanceY // silence unused intent
    }
}

