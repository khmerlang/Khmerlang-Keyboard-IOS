import UIKit

final class KeyboardViewController: UIInputViewController {
    private var mode: KeyboardMode = .khmer
    private var isShiftOn: Bool = false

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

        let layout = KeyboardLayouts.layout(for: mode)

        for row in layout.rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.alignment = .fill
            rowStack.distribution = .fillEqually
            rowStack.spacing = 6

            for key in row.keys {
                let btn = KeyboardKeyButton(key: key, onKeyPress: { [weak self] key, longPress in
                    self?.handleKey(key, longPress: longPress)
                })
                btn.updateTitle(key.outputLabel(isShiftOn: isShiftOn, mode: mode))
                btn.heightAnchor.constraint(equalToConstant: 44).isActive = true
                rowStack.addArrangedSubview(btn)
            }

            rootStack.addArrangedSubview(rowStack)
        }
    }

    private func handleKey(_ key: KeyboardKey, longPress: Bool) {
        let outputCode: Int
        if longPress, let longPressCode = key.longPressCode {
            outputCode = longPressCode
        } else {
            outputCode = key.code
        }

        // Special control keys.
        switch outputCode {
        case KeyCodes.shift:
            if mode == .english {
                isShiftOn.toggle()
                rebuildKeyboard()
            }
            return
        case KeyCodes.modeChange:
            mode = (mode == .khmer) ? .english : .khmer
            isShiftOn = false
            rebuildKeyboard()
            return
        case KeyCodes.switchNextInputMode:
            advanceToNextInputMode()
            return
        case KeyCodes.sym:
            // Not implemented in this starter scaffold.
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

        // Apply shift only to English ASCII letters (matches Android `qwerty.xml` behavior).
        var finalText = textToInsert
        if mode == .english, isShiftOn, (97...122).contains(outputCode) {
            finalText = textToInsert.uppercased()
            // Common iOS behavior: shift applies to the next character.
            isShiftOn = false
            rebuildKeyboard()
        }

        insertText(finalText)
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
}

