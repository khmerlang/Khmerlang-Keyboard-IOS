import UIKit

final class KeyboardKeyButton: UIButton {
    private var didLongPress = false
    private var key: KeyboardKey?
    private var onKeyPress: ((_ key: KeyboardKey, _ longPress: Bool) -> Void)?

    init(key: KeyboardKey, onKeyPress: @escaping (_ key: KeyboardKey, _ longPress: Bool) -> Void) {
        self.key = key
        self.onKeyPress = onKeyPress
        super.init(frame: .zero)

        setTitle(key.label, for: .normal)
        setTitleColor(.black, for: .normal)
        titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        layer.cornerRadius = 8

        adjustsImageWhenHighlighted = false
        showsTouchWhenHighlighted = true

        addTarget(self, action: #selector(handleTapDown), for: .touchDown)
        addTarget(self, action: #selector(handleTapUp), for: .touchUpInside)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.45
        longPress.cancelsTouchesInView = true
        addGestureRecognizer(longPress)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateTitle(_ title: String) {
        setTitle(title, for: .normal)
    }

    @objc private func handleTapDown() {
        // Reset between interactions.
        didLongPress = false
    }

    @objc private func handleTapUp() {
        guard let key else { return }
        guard !didLongPress else { return }
        onKeyPress?(key, false)
    }

    @objc private func handleLongPress(_ gr: UILongPressGestureRecognizer) {
        guard let key, let onKeyPress else { return }
        guard gr.state == .began else { return }

        // If key has no long-press output, treat it as a normal tap.
        guard key.longPressCode != nil else {
            didLongPress = true
            onKeyPress(key, false)
            return
        }

        didLongPress = true
        onKeyPress(key, true)
    }
}

