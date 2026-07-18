//
//  KeyboardView.swift
//  Khmerlang
//
//  Renders a KeyboardGrid as rows of proportionally-sized KeyButtons and
//  forwards key events to its delegate.
//

import UIKit

final class KeyboardView: UIView {

    weak var delegate: KeyButtonDelegate?

    private var buttonRows: [[KeyButton]] = []
    private let theme: KeyboardTheme

    private let keyGapX: CGFloat = 3
    private let keyGapY: CGFloat = 5

    init(theme: KeyboardTheme) {
        self.theme = theme
        super.init(frame: .zero)
        backgroundColor = theme.background
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Built button rows per cache key, so switching pages (notably the
    /// shift revert after every shifted character) reuses views instead of
    /// recreating ~30 buttons on the main thread mid-typing.
    private var cachedRows: [String: [[KeyButton]]] = [:]

    /// Buttons from a replaced grid whose touch was still in progress when the
    /// page switched (fast rollover typing, or a long-press being held). They
    /// stay in the hierarchy — removing a view mid-touch cancels its touch and
    /// drops the key — and are removed when their touch finishes.
    private var retiredButtons: [KeyButton] = []

    /// Show a layout. Pass a `cacheKey` unique to the grid's content
    /// (language + page + return-key label) to reuse previously built buttons.
    func setGrid(_ grid: KeyboardGrid, cacheKey: String? = nil) {
        buttonRows.forEach { row in
            row.forEach { button in
                if button.isTracking {
                    if !retiredButtons.contains(where: { $0 === button }) {
                        retiredButtons.append(button)
                    }
                } else {
                    button.removeFromSuperview()
                }
            }
        }
        if let cacheKey, let cached = cachedRows[cacheKey] {
            buttonRows = cached
            cached.forEach { $0.forEach { addSubview($0) } }
        } else {
            buttonRows = grid.map { row in
                row.map { key -> KeyButton in
                    let button = KeyButton(key: key, theme: theme)
                    button.delegate = delegate
                    addSubview(button)
                    return button
                }
            }
            if let cacheKey {
                cachedRows[cacheKey] = buttonRows
            }
        }
        // Switching back to a cached page mid-touch can re-adopt a retired
        // button; it's part of the live grid again.
        retiredButtons.removeAll { button in
            buttonRows.contains { row in row.contains { $0 === button } }
        }
        setNeedsLayout()
    }

    /// Called by a KeyButton when its touch ends or is cancelled; removes it
    /// if a page switch retired it while the touch was in progress.
    func keyButtonDidFinishTouch(_ button: KeyButton) {
        guard let index = retiredButtons.firstIndex(where: { $0 === button }) else { return }
        retiredButtons.remove(at: index)
        button.removeFromSuperview()
    }

    /// Touches landing in the gaps between keys (or the side margins of a
    /// centered row) hit-test to this view and would be silently dropped —
    /// a major cause of missed presses during fast typing. Route them to the
    /// nearest key instead, so the whole keyboard surface is tappable like
    /// the system keyboard.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        guard view === self, bounds.contains(point) else { return view }
        return nearestButton(to: point) ?? view
    }

    private func nearestButton(to point: CGPoint) -> KeyButton? {
        var best: KeyButton?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for row in buttonRows {
            for button in row {
                // Squared distance from the point to the button's frame
                // (zero when inside).
                let dx = max(button.frame.minX - point.x, 0, point.x - button.frame.maxX)
                let dy = max(button.frame.minY - point.y, 0, point.y - button.frame.maxY)
                let distance = dx * dx + dy * dy
                if distance < bestDistance {
                    bestDistance = distance
                    best = button
                }
            }
        }
        return best
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !buttonRows.isEmpty else { return }

        let rowHeight = bounds.height / CGFloat(buttonRows.count)
        for (rowIndex, row) in buttonRows.enumerated() {
            let totalFraction = row.reduce(0) { $0 + $1.key.width }
            // Center rows that don't fill the full width (e.g. the a–l row).
            let sideMargin = bounds.width * (max(0, 100 - totalFraction) / 100) / 2
            var x = sideMargin
            let y = CGFloat(rowIndex) * rowHeight
            for button in row {
                let width = bounds.width * (button.key.width / 100)
                let cell = CGRect(x: x, y: y, width: width, height: rowHeight)
                button.frame = cell.insetBy(dx: keyGapX, dy: keyGapY)
                x += width
            }
        }
    }
}

// Opts the keyboard into the system key-click sound (played via
// UIDevice.playInputClick(), honouring the user's "Keyboard Clicks" setting).
extension KeyboardView: UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}
