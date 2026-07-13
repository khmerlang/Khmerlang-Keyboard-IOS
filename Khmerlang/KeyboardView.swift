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

    /// Show a layout. Pass a `cacheKey` unique to the grid's content
    /// (language + page + return-key label) to reuse previously built buttons.
    func setGrid(_ grid: KeyboardGrid, cacheKey: String? = nil) {
        buttonRows.forEach { $0.forEach { $0.removeFromSuperview() } }
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
        setNeedsLayout()
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
