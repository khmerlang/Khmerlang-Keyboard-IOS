import UIKit

enum KeyboardKeyAction {
    case tap
    case longPress
    case repeatTick
}

final class KeyboardKeyButton: UIButton {
    private var didLongPress = false
    private var key: KeyboardKey?
    private var onAction: ((_ key: KeyboardKey, _ action: KeyboardKeyAction) -> Void)?

    private var repeatTimer: Timer?

    // Mirrors Kotlin: LONG_PRESS_DELAY = 500, REPEAT_INTERVAL = 50.
    private let initialRepeatDelayMs: TimeInterval = 0.5
    private let repeatIntervalMs: TimeInterval = 0.05

    init(
        key: KeyboardKey,
        onAction: @escaping (_ key: KeyboardKey, _ action: KeyboardKeyAction) -> Void
    ) {
        self.key = key
        self.onAction = onAction
        super.init(frame: .zero)

        setTitle(key.label, for: .normal)
        setTitleColor(.black, for: .normal)
        titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        layer.cornerRadius = 8

        adjustsImageWhenHighlighted = false
        showsTouchWhenHighlighted = true

        addTarget(self, action: #selector(handleTapDown), for: .touchDown)
        addTarget(self, action: #selector(handleTapUpInside), for: .touchUpInside)
        addTarget(self, action: #selector(handleTouchCancelled), for: .touchCancel)
        addTarget(self, action: #selector(handleTouchCancelled), for: .touchUpOutside)
        addTarget(self, action: #selector(handleTouchCancelled), for: .touchDragExit)

        if key.isRepeatable {
            // For repeatable keys (like Delete), long-press is not needed; we repeat while holding.
            return
        }

        if key.longPressCode != nil {
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            longPress.minimumPressDuration = 0.45
            longPress.cancelsTouchesInView = true
            addGestureRecognizer(longPress)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateTitle(_ title: String) {
        setTitle(title, for: .normal)
    }

    @objc private func handleTapDown() {
        didLongPress = false

        guard let key else { return }
        guard key.isRepeatable else { return }

        // Schedule auto-repeat while holding the key.
        repeatTimer?.invalidate()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: initialRepeatDelayMs, repeats: false) { [weak self] _ in
            guard let self, let key = self.key else { return }
            // Now start repeating at fixed interval.
            self.repeatTimer?.invalidate()
            self.repeatTimer = Timer.scheduledTimer(withTimeInterval: self.repeatIntervalMs, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.onAction?(key, .repeatTick)
            }
        }
        RunLoop.main.add(repeatTimer!, forMode: .common)
    }

    @objc private func handleTapUpInside() {
        guard let key else { return }
        stopRepeatIfNeeded()

        guard !didLongPress else { return }
        onAction?(key, .tap)
    }

    @objc private func handleLongPress(_ gr: UILongPressGestureRecognizer) {
        guard let key, let onAction else { return }
        guard gr.state == .began else { return }

        didLongPress = true
        onAction(key, .longPress)
    }

    @objc private func handleTouchCancelled() {
        didLongPress = false
        stopRepeatIfNeeded()
    }

    private func stopRepeatIfNeeded() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}

