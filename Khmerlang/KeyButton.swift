//
//  KeyButton.swift
//  Khmerlang
//
//  A single interactive key. Handles press highlighting, a preview popup for
//  character keys, long-press insertion of the sub-label, and auto-repeat for
//  repeatable keys (backspace).
//
//  Keys without a long-press variant commit on touch-DOWN like the system
//  keyboard: firing on touch-up added a full finger-contact of latency and
//  silently dropped the key whenever the touch was cancelled (page reloads,
//  system gestures) — the main cause of missed presses during fast typing.
//

import UIKit

protocol KeyButtonDelegate: AnyObject {
    func keyButton(_ button: KeyButton, didTap key: Key)
    func keyButton(_ button: KeyButton, didLongPress key: Key)
}

final class KeyButton: UIView {

    let key: Key
    private let theme: KeyboardTheme
    weak var delegate: KeyButtonDelegate?

    private let mainLabel = UILabel()
    private let subLabel = UILabel()
    private let iconView = UIImageView()

    private var longPressTimer: Timer?
    private var repeatDelayTimer: Timer?
    private var repeatTimer: Timer?
    private var didFireLongPress = false
    private var didCommitOnDown = false

    /// True while a touch is in progress on this key. KeyboardView keeps
    /// tracking buttons alive across page switches so the touch isn't cancelled.
    private(set) var isTracking = false

    init(key: Key, theme: KeyboardTheme) {
        self.key = key
        self.theme = theme
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Setup

    private func setupView() {
        layer.cornerRadius = 5
        layer.masksToBounds = false
        backgroundColor = key.isSpecial ? theme.specialKeyBackground : theme.keyBackground

        // Subtle drop shadow to mimic the raised key look.
        layer.shadowColor = theme.keyShadow.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0
        layer.shadowOpacity = 1.0

        if let icon = key.icon {
            iconView.image = UIImage(systemName: icon)
            iconView.tintColor = theme.keyText
            iconView.contentMode = .scaleAspectFit
            addSubview(iconView)
        } else {
            mainLabel.text = key.label
            mainLabel.textAlignment = .center
            mainLabel.textColor = theme.keyText
            mainLabel.adjustsFontSizeToFitWidth = true
            mainLabel.minimumScaleFactor = 0.5
            addSubview(mainLabel)

            if let sub = key.subLabel {
                subLabel.text = sub
                subLabel.textAlignment = .center
                subLabel.textColor = theme.subLabelText
                subLabel.font = .systemFont(ofSize: 10)
                addSubview(subLabel)
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath

        if key.icon != nil {
            let side = min(bounds.width, bounds.height) * 0.5
            iconView.frame = CGRect(x: (bounds.width - side) / 2,
                                    y: (bounds.height - side) / 2,
                                    width: side, height: side)
        } else {
            let baseSize = min(bounds.height * 0.42, 24) * key.fontScale
            mainLabel.font = .systemFont(ofSize: max(11, baseSize))
            if key.subLabel != nil {
                // Main label sits slightly lower; sub-label pinned top-right.
                mainLabel.frame = CGRect(x: 0, y: bounds.height * 0.18,
                                         width: bounds.width, height: bounds.height * 0.72)
                subLabel.frame = CGRect(x: bounds.width * 0.45, y: 2,
                                        width: bounds.width * 0.5, height: bounds.height * 0.3)
            } else {
                mainLabel.frame = bounds
            }
        }
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        didFireLongPress = false
        didCommitOnDown = false
        isTracking = true
        setHighlighted(true)

        if key.isRepeatable {
            // Fire once immediately, then begin repeating after a short delay.
            delegate?.keyButton(self, didTap: key)
            repeatDelayTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
                guard let self else { return }
                self.repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                    guard let self else { return }
                    self.delegate?.keyButton(self, didTap: self.key)
                }
            }
        } else {
            showPreview()
            if key.subLabel != nil {
                // Long-press keys must wait for touch-up to know which of the
                // two characters the user meant.
                longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    self.didFireLongPress = true
                    self.hidePreview()
                    self.delegate?.keyButton(self, didLongPress: self.key)
                    self.setHighlighted(false)
                }
            } else if key.action != .nextKeyboard {
                // Commit on touch-down. The globe key stays on touch-up so the
                // app isn't opened out from under an active touch.
                didCommitOnDown = true
                delegate?.keyButton(self, didTap: key)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishTouch(deliverTap: !didFireLongPress && !didCommitOnDown && !key.isRepeatable)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishTouch(deliverTap: false)
    }

    private func finishTouch(deliverTap: Bool) {
        isTracking = false
        cancelTimers()
        hidePreview()
        setHighlighted(false)
        if deliverTap {
            delegate?.keyButton(self, didTap: key)
        }
        didFireLongPress = false
        didCommitOnDown = false
        // If a page switch retired this button mid-touch, remove it now.
        (superview as? KeyboardView)?.keyButtonDidFinishTouch(self)
    }

    private func cancelTimers() {
        longPressTimer?.invalidate(); longPressTimer = nil
        repeatDelayTimer?.invalidate(); repeatDelayTimer = nil
        repeatTimer?.invalidate(); repeatTimer = nil
    }

    private func setHighlighted(_ highlighted: Bool) {
        let normal = key.isSpecial ? theme.specialKeyBackground : theme.keyBackground
        backgroundColor = highlighted ? normal.highlighted : normal
    }

    // MARK: - Preview popup

    private var previewLabel: UILabel?

    private func showPreview() {
        // Only character keys with a text label get a preview bubble.
        guard key.icon == nil, !key.isSpecial, !key.label.isEmpty, previewLabel == nil,
              let container = superview else { return }

        let preview = UILabel()
        preview.text = key.label
        preview.textAlignment = .center
        preview.textColor = theme.keyText
        preview.backgroundColor = theme.popupBackground
        preview.font = .systemFont(ofSize: 30)
        preview.layer.cornerRadius = 6
        preview.layer.masksToBounds = true

        let width = max(bounds.width, 42)
        let height = bounds.height + 14
        var originX = frame.midX - width / 2
        originX = min(max(originX, 2), container.bounds.width - width - 2)
        preview.frame = CGRect(x: originX, y: frame.minY - height - 4, width: width, height: height)
        container.addSubview(preview)
        previewLabel = preview
    }

    private func hidePreview() {
        previewLabel?.removeFromSuperview()
        previewLabel = nil
    }
}

private extension UIColor {
    /// A slightly shifted variant used for the pressed state.
    var highlighted: UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        // Darken light keys, lighten dark keys.
        let delta: CGFloat = (r + g + b) / 3 > 0.5 ? -0.12 : 0.15
        return UIColor(red: max(0, min(1, r + delta)),
                       green: max(0, min(1, g + delta)),
                       blue: max(0, min(1, b + delta)),
                       alpha: a)
    }
}
