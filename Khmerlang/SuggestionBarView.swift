//
//  SuggestionBarView.swift
//  Khmerlang
//
//  The suggestion (smart) bar shown above the keys: a horizontally scrollable
//  row of candidate word buttons, ported from the Android smartbar.
//

import UIKit

protocol SuggestionBarViewDelegate: AnyObject {
    func suggestionBar(_ bar: SuggestionBarView, didSelect suggestion: String)
    /// The quick-settings strip was closed after (possibly) changing settings;
    /// the controller should recompute the candidates.
    func suggestionBarDidChangeSettings(_ bar: SuggestionBarView)
    /// The user asked for a server spell check from the quick-settings strip.
    func suggestionBarDidRequestSpellCheck(_ bar: SuggestionBarView)
}

final class SuggestionBarView: UIView {

    static let preferredHeight: CGFloat = 44

    weak var delegate: SuggestionBarViewDelegate?

    private let theme: KeyboardTheme
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    /// The Khmerlang logo at the leading edge (Android's smartbar logo button);
    /// toggles the quick-settings strip.
    private let logoButton = UIButton(type: .system)
    private var showingSettings = false

    init(theme: KeyboardTheme) {
        self.theme = theme
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        backgroundColor = theme.background

        logoButton.setImage(UIImage(named: "khmerlang-logo")?.withRenderingMode(.alwaysOriginal), for: .normal)
        logoButton.imageView?.contentMode = .scaleAspectFit
        logoButton.addTarget(self, action: #selector(logoTapped), for: .touchUpInside)
        logoButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(logoButton)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        addSubview(scrollView)

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = 0
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            logoButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            logoButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            logoButton.widthAnchor.constraint(equalToConstant: 34),
            logoButton.heightAnchor.constraint(equalToConstant: 34),

            scrollView.leadingAnchor.constraint(equalTo: logoButton.trailingAnchor, constant: 4),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
    }

    /// Replace the displayed candidates. Typing closes the settings strip
    /// (mirrors the Android smartbar's setTyping behaviour).
    func setSuggestions(_ suggestions: [String]) {
        showingSettings = false
        clearStack()

        guard !suggestions.isEmpty else { return }

        for (index, suggestion) in suggestions.enumerated() {
            if index > 0 {
                stack.addArrangedSubview(makeSeparator())
            }
            stack.addArrangedSubview(makeButton(suggestion))
        }
    }

    private func clearStack() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        scrollView.setContentOffset(.zero, animated: false)
    }

    // MARK: - Quick settings strip

    @objc private func logoTapped() {
        showingSettings.toggle()
        if showingSettings {
            renderSettings()
        } else {
            // Settings may have changed — let the controller repopulate.
            delegate?.suggestionBarDidChangeSettings(self)
        }
    }

    /// Toggle chips for the Latin-input suggestion sources (the Android
    /// smartbar settings list opened from the logo button).
    private func renderSettings() {
        clearStack()
        // Spell check is the future premium feature; hidden when not entitled.
        if SharedStore.spellCheckEnabled && SharedStore.spellCheckConsentGranted {
            let check = UIButton(type: .system, primaryAction: UIAction { [weak self] _ in
                guard let self else { return }
                self.showingSettings = false
                self.delegate?.suggestionBarDidRequestSpellCheck(self)
            })
            check.setImage(UIImage(systemName: "text.magnifyingglass"), for: .normal)
            check.setTitle(" ពិនិត្យ", for: .normal)
            check.tintColor = theme.keyText
            check.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
            check.contentEdgeInsets = UIEdgeInsets(top: 4, left: 16, bottom: 4, right: 16)
            check.widthAnchor.constraint(greaterThanOrEqualToConstant: minButtonWidth).isActive = true
            stack.addArrangedSubview(check)
            stack.addArrangedSubview(makeSeparator())
        }
        stack.addArrangedSubview(makeSettingChip("Roman → ខ្មែរ", isOn: SharedStore.romanCorrectionEnabled) {
            SharedStore.romanCorrectionEnabled.toggle()
        })
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(makeSettingChip("English", isOn: SharedStore.englishCorrectionEnabled) {
            SharedStore.englishCorrectionEnabled.toggle()
        })
    }

    private func makeSettingChip(_ title: String, isOn: Bool, onTap: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system, primaryAction: UIAction { [weak self] _ in
            onTap()
            self?.renderSettings()   // refresh checkmarks
        })
        button.setTitle((isOn ? "✓ " : "○ ") + title, for: .normal)
        button.setTitleColor(isOn ? theme.keyText : theme.subLabelText, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 16, bottom: 4, right: 16)
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: minButtonWidth).isActive = true
        return button
    }

    // MARK: - Subview factories

    private func makeButton(_ title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(theme.keyText, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.7
        button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 16, bottom: 4, right: 16)
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        // Ensure short lists still spread across the bar width.
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: minButtonWidth).isActive = true
        button.addTarget(self, action: #selector(candidateTapped(_:)), for: .touchUpInside)
        return button
    }

    private var minButtonWidth: CGFloat {
        // Roughly a third of the screen so 1–3 candidates fill the bar.
        max(96, UIScreen.main.bounds.width / 3.2)
    }

    private func makeSeparator() -> UIView {
        let line = UIView()
        line.backgroundColor = theme.subLabelText.withAlphaComponent(0.4)
        line.translatesAutoresizingMaskIntoConstraints = false
        line.widthAnchor.constraint(equalToConstant: 1).isActive = true
        let container = UIView()
        container.addSubview(line)
        NSLayoutConstraint.activate([
            line.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            line.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.5),
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        return container
    }

    @objc private func candidateTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal), !title.isEmpty else { return }
        delegate?.suggestionBar(self, didSelect: title)
    }
}
