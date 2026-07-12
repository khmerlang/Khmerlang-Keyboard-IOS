//
//  SpellCheckPanelView.swift
//  Khmerlang
//
//  The server spell-check results panel, shown over the key grid (the iOS
//  counterpart of the Android spellSuggestionView). Lists each typo with a
//  strikethrough and its suggestion chips; tapping a chip asks the delegate
//  to apply the replacement and removes the row.
//

import UIKit

protocol SpellCheckPanelViewDelegate: AnyObject {
    func spellCheckPanel(_ panel: SpellCheckPanelView, didPick suggestion: String, for typo: SpellCheckTypo)
    func spellCheckPanelDidClose(_ panel: SpellCheckPanelView)
}

final class SpellCheckPanelView: UIView {

    weak var delegate: SpellCheckPanelViewDelegate?

    private let theme: KeyboardTheme
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let scrollView = UIScrollView()
    private let rowsStack = UIStackView()
    private let statusLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)

    init(theme: KeyboardTheme) {
        self.theme = theme
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        backgroundColor = theme.background

        titleLabel.text = "Khmerlang Spell Check"
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = theme.keyText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = theme.subLabelText
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(closeButton)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        rowsStack.axis = .vertical
        rowsStack.spacing = 8
        rowsStack.alignment = .fill
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(rowsStack)

        statusLabel.font = .systemFont(ofSize: 15)
        statusLabel.textColor = theme.subLabelText
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusLabel)

        spinner.hidesWhenStopped = true
        spinner.color = theme.subLabelText
        spinner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(spinner)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),

            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            rowsStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 4),
            rowsStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 12),
            rowsStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -12),
            rowsStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -8),
            rowsStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -24),

            statusLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),

            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    // MARK: - States

    func setLoading() {
        clearRows()
        statusLabel.text = nil
        spinner.startAnimating()
    }

    func show(message: String) {
        clearRows()
        spinner.stopAnimating()
        statusLabel.text = message
    }

    func show(typos: [SpellCheckTypo]) {
        clearRows()
        spinner.stopAnimating()
        guard !typos.isEmpty else {
            statusLabel.text = "No spelling issues found 🎉"
            return
        }
        statusLabel.text = nil
        for typo in typos {
            rowsStack.addArrangedSubview(makeRow(for: typo))
        }
    }

    private func clearRows() {
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        scrollView.setContentOffset(.zero, animated: false)
    }

    // MARK: - Rows

    private func makeRow(for typo: SpellCheckTypo) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center

        let typoLabel = UILabel()
        typoLabel.attributedText = NSAttributedString(
            string: typo.word,
            attributes: [
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .strikethroughColor: UIColor.systemRed,
                .foregroundColor: UIColor.systemRed,
                .font: UIFont.systemFont(ofSize: 17)
            ])
        typoLabel.setContentHuggingPriority(.required, for: .horizontal)
        typoLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        row.addArrangedSubview(typoLabel)

        // Suggestion chips scroll horizontally when they overflow the row.
        let chipsScroll = UIScrollView()
        chipsScroll.showsHorizontalScrollIndicator = false
        let chips = UIStackView()
        chips.axis = .horizontal
        chips.spacing = 6
        chips.translatesAutoresizingMaskIntoConstraints = false
        chipsScroll.addSubview(chips)
        NSLayoutConstraint.activate([
            chips.leadingAnchor.constraint(equalTo: chipsScroll.contentLayoutGuide.leadingAnchor),
            chips.trailingAnchor.constraint(equalTo: chipsScroll.contentLayoutGuide.trailingAnchor),
            chips.topAnchor.constraint(equalTo: chipsScroll.contentLayoutGuide.topAnchor),
            chips.bottomAnchor.constraint(equalTo: chipsScroll.contentLayoutGuide.bottomAnchor),
            chips.heightAnchor.constraint(equalTo: chipsScroll.frameLayoutGuide.heightAnchor),
            chipsScroll.heightAnchor.constraint(equalToConstant: 34)
        ])
        for suggestion in typo.suggestions.prefix(5) {
            chips.addArrangedSubview(makeChip(suggestion, typo: typo, row: row))
        }
        row.addArrangedSubview(chipsScroll)
        return row
    }

    private func makeChip(_ suggestion: String, typo: SpellCheckTypo, row: UIView) -> UIButton {
        let button = UIButton(type: .system, primaryAction: UIAction { [weak self, weak row] _ in
            guard let self else { return }
            self.delegate?.spellCheckPanel(self, didPick: suggestion, for: typo)
            row?.removeFromSuperview()
            if self.rowsStack.arrangedSubviews.isEmpty {
                self.statusLabel.text = "All fixed 🎉"
            }
        })
        button.setTitle(suggestion, for: .normal)
        button.setTitleColor(theme.keyText, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16)
        button.backgroundColor = theme.keyBackground
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 5, left: 12, bottom: 5, right: 12)
        return button
    }

    @objc private func closeTapped() {
        delegate?.spellCheckPanelDidClose(self)
    }
}
