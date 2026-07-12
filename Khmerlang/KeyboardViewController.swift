//
//  KeyboardViewController.swift
//  Khmerlang
//
//  The custom keyboard extension. Manages the current language / page state and
//  translates key events into edits on the text document. Ported from the
//  Android InputMethodService (R2KhmerService).
//

import UIKit

class KeyboardViewController: UIInputViewController {

    private var language: KeyboardLanguage = .khmer
    private var page: KeyboardPage = .normal

    private var keyboardView: KeyboardView!
    private var suggestionBar: SuggestionBarView!
    private var heightConstraint: NSLayoutConstraint!
    private var spellCheckPanel: SpellCheckPanelView?

    private let suggestionProvider = SuggestionProvider()

    /// True while the bar shows next-word predictions (nothing being composed):
    /// picking one must append, not replace the previous word.
    private var suggestionsAreNextWords = false

    /// Last seen return-key type; the grid reloads when the host field changes it.
    private var lastReturnKeyType: UIReturnKeyType = .default

    private var theme: KeyboardTheme {
        KeyboardTheme.theme(for: textDocumentProxy.keyboardAppearance ?? .default)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildKeyboard()
        requestSupplementaryLexicon { [weak self] lexicon in
            self?.suggestionProvider.lexicon = lexicon
        }
        // The corrector's BK-trees build in the background after each extension
        // launch; refresh the bar once fuzzy correction becomes available.
        KhmerlangCorrector.shared.notifyWhenReady { [weak self] in
            self?.updateSuggestions()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // The extension process survives across presentations; pick up custom
        // dictionary edits made in the container app since the trees were built.
        KhmerlangCorrector.shared.refreshCustomMappingsIfNeeded()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        // Relabel the return key when moving to a field with a different action.
        let returnType = textDocumentProxy.returnKeyType ?? .default
        if returnType != lastReturnKeyType {
            lastReturnKeyType = returnType
            reloadGrid()
        }
        updateSuggestions()
    }

    override func updateViewConstraints() {
        super.updateViewConstraints()
        heightConstraint?.constant = preferredKeyboardHeight
    }

    // MARK: - Building

    /// Height of the key grid alone (excludes the suggestion bar).
    private var preferredKeysHeight: CGFloat {
        // A little taller than a Latin keyboard so Khmer glyphs read well.
        let portrait = UIScreen.main.bounds.height > UIScreen.main.bounds.width
        return portrait ? 244 : 190
    }

    /// Total input-view height (suggestion bar + keys).
    private var preferredKeyboardHeight: CGFloat {
        SuggestionBarView.preferredHeight + preferredKeysHeight
    }

    private func buildKeyboard() {
        keyboardView?.removeFromSuperview()
        suggestionBar?.removeFromSuperview()

        let bar = SuggestionBarView(theme: theme)
        bar.delegate = self
        bar.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(bar)
        self.suggestionBar = bar

        let view = KeyboardView(theme: theme)
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setGrid(currentGrid())
        self.view.addSubview(view)
        self.keyboardView = view

        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            bar.topAnchor.constraint(equalTo: self.view.topAnchor),
            bar.heightAnchor.constraint(equalToConstant: SuggestionBarView.preferredHeight),

            view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            view.topAnchor.constraint(equalTo: bar.bottomAnchor),
            view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])

        if heightConstraint == nil {
            heightConstraint = self.view.heightAnchor.constraint(equalToConstant: preferredKeyboardHeight)
            heightConstraint.priority = .required - 1
            heightConstraint.isActive = true
        }
        heightConstraint.constant = preferredKeyboardHeight
        updateSuggestions()
    }

    /// Rebuild only the grid (keeps the same view/height).
    private func reloadGrid() {
        keyboardView.setGrid(currentGrid())
    }

    /// The grid for the current language/page, with the return key relabelled
    /// to the host field's action (Search, Go, …) like Android's handleEnter
    /// IME-action dispatch.
    private func currentGrid() -> KeyboardGrid {
        var grid = KeyboardLayouts.grid(language: language, page: page)
        lastReturnKeyType = textDocumentProxy.returnKeyType ?? .default
        guard let title = Self.returnKeyTitle(for: lastReturnKeyType) else { return grid }
        for (r, row) in grid.enumerated() {
            for (k, key) in row.enumerated() where key.action == .enter {
                grid[r][k] = Key(label: title, action: .enter, width: key.width,
                                 isSpecial: true, fontScale: 0.7)
            }
        }
        return grid
    }

    /// Text shown on the return key for a given action type; nil keeps the
    /// plain return icon.
    static func returnKeyTitle(for type: UIReturnKeyType) -> String? {
        switch type {
        case .go:            return "Go"
        case .google, .search, .yahoo: return "Search"
        case .send:          return "Send"
        case .done:          return "Done"
        case .next:          return "Next"
        case .join:          return "Join"
        case .route:         return "Route"
        case .continue:      return "Continue"
        case .emergencyCall: return "Call"
        default:             return nil
        }
    }

    // MARK: - Suggestions

    /// Recompute candidates and refresh the bar. While a word is being typed we
    /// show prefix completions; right after a space we show next-word predictions.
    private func updateSuggestions() {
        guard let suggestionBar else { return }
        let (word, prevOne, prevTwo) = composingContext()
        let suggestions: [String]
        suggestionsAreNextWords = word.isEmpty
        if word.isEmpty {
            // No predictions at the start of a sentence (matches Android's
            // isStartSen guard) — "<s>" alone isn't usable context.
            suggestions = (prevTwo.isEmpty || prevTwo == "<s>")
                ? [] : suggestionProvider.nextWords(prevOne: prevOne, prevTwo: prevTwo)
        } else {
            let before = textDocumentProxy.documentContextBeforeInput ?? ""
            let isStartSentence = Self.isSentenceStart(String(before.dropLast(word.count)))
            suggestions = suggestionProvider.completions(for: word, language: language,
                                                         prevOne: prevOne, prevTwo: prevTwo,
                                                         isStartSentence: isStartSentence)
        }
        suggestionBar.setSuggestions(suggestions)
    }

    /// The word being composed plus its two preceding context words. Khmer is
    /// written without spaces, so a trailing Khmer run is split with the
    /// dictionary segmenter (when built): the run's last segment is the
    /// composing word and earlier segments provide the n-gram context. Latin
    /// input keeps the whitespace-based behaviour.
    private func composingContext() -> (word: String, prevOne: String, prevTwo: String) {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let run = Self.trailingWord(in: before)
        let contextBefore = String(before.dropLast(run.count))
        // N-gram context never crosses a sentence boundary.
        var (one, two) = Self.previousTwoWords(in: Self.currentSentence(in: contextBefore))
        var word = run
        let segmenter = KhmerlangCorrector.shared.segmenter

        if run.isEmpty {
            // Right after a space/punctuation: the newest context token may
            // itself be a spaceless Khmer run — use its last two words.
            if let segmenter, Self.containsKhmer(two) {
                let words = segmenter.words(in: two)
                if let last = words.last {
                    one = words.count >= 2 ? words[words.count - 2] : one
                    two = last
                }
            }
        } else if let segmenter, Self.containsKhmer(run) {
            let split = segmenter.composingSplit(of: run)
            word = split.composing
            let context = split.context
            if context.count >= 2 {
                (one, two) = (context[context.count - 2], context[context.count - 1])
            } else if context.count == 1 {
                (one, two) = (two, context[0])
            }
        }

        // Missing leading context means start of sentence; the n-gram database
        // marks that with "<s>" (matches the Android setComposingTextBasedOnInput).
        if two.isEmpty { return (word, "<s>", "<s>") }
        if one.isEmpty { return (word, "<s>", two) }
        return (word, one, two)
    }

    /// Sentence-ending characters (the Android WordTokenizer CHAR_END_SENTENCE
    /// set plus newline).
    private static let sentenceEnders: Set<Character> = [".", "?", "!", "។", "៕", "៘", "៚", "\n"]

    /// The text after the last sentence terminator.
    static func currentSentence(in text: String) -> String {
        if let boundary = text.lastIndex(where: { sentenceEnders.contains($0) }) {
            return String(text[text.index(after: boundary)...])
        }
        return text
    }

    /// Whether `text` contains any scalar from the Khmer block.
    static func containsKhmer(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x1780...0x17FF).contains($0.value) }
    }

    // MARK: - Precise deletion

    /// Replace the last `scalarCount` scalars before the cursor with
    /// `replacement`, robust to the host's backspace granularity (see
    /// TextReplacer).
    private func replaceBeforeCursor(scalarCount: Int, with replacement: String) {
        let proxy = textDocumentProxy
        TextReplacer.replaceBeforeCursor(scalarCount: scalarCount, replacement: replacement,
                                         context: { proxy.documentContextBeforeInput },
                                         deleteBackward: { proxy.deleteBackward() },
                                         insert: { proxy.insertText($0) })
    }

    /// Zero-width space: the conventional invisible separator between Khmer
    /// words (inserted by the Android Khmerlang keyboard and others). Not
    /// Unicode whitespace, so it needs explicit handling.
    static let zeroWidthSpace: Character = "\u{200B}"

    /// The two whitespace-delimited words immediately preceding the cursor,
    /// returned as (older, newer) to match the Android context order.
    static func previousTwoWords(in text: String) -> (String, String) {
        let tokens = text.split { $0.isWhitespace || $0.isNewline || $0 == zeroWidthSpace }.map(String.init)
        let newer = tokens.last ?? ""
        let older = tokens.count >= 2 ? tokens[tokens.count - 2] : ""
        return (older, newer)
    }

    /// Whether the cursor is at the start of a sentence (used to capitalise
    /// English corrections).
    static func isSentenceStart(_ contextBefore: String) -> Bool {
        let trimmed = contextBefore.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return true }
        return ".!?".contains(last)
    }

    /// The run of word characters immediately preceding the cursor (the word
    /// currently being composed), mirroring the Android composing-word buffer.
    static func trailingWord(in text: String) -> String {
        var characters: [Character] = []
        for character in text.reversed() {
            if character.isWhitespace || character.isPunctuation || character.isSymbol
                || character == zeroWidthSpace { break }
            characters.append(character)
        }
        return String(characters.reversed())
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.heightConstraint?.constant = self.preferredKeyboardHeight
        })
    }
}

// MARK: - Key handling

extension KeyboardViewController: KeyButtonDelegate {

    func keyButton(_ button: KeyButton, didTap key: Key) {
        handle(action: key.action)
    }

    func keyButton(_ button: KeyButton, didLongPress key: Key) {
        guard let sub = key.subLabel else { return }
        UIDevice.current.playInputClick()
        textDocumentProxy.insertText(sub)
        revertShiftIfNeeded()
        updateSuggestions()
    }

    private func handle(action: KeyAction) {
        let proxy = textDocumentProxy
        // System key click (respects the user's "Keyboard Clicks" setting).
        UIDevice.current.playInputClick()

        // Note: iOS does not reliably call textDidChange for edits the keyboard
        // itself makes via the proxy, so every mutating case below refreshes
        // the suggestion bar explicitly.
        switch action {
        case .character(let text):
            proxy.insertText(text)
            revertShiftIfNeeded()
            updateSuggestions()

        case .space:
            proxy.insertText(" ")
            revertShiftIfNeeded()
            updateSuggestions()

        case .enter:
            proxy.insertText("\n")
            revertShiftIfNeeded()
            updateSuggestions()

        case .backspace:
            proxy.deleteBackward()
            updateSuggestions()

        case .shift:
            page = .shift
            reloadGrid()

        case .unshift:
            page = .normal
            reloadGrid()

        case .symbols:
            page = .symbol
            reloadGrid()

        case .symbolsShift:
            page = .symbolShift
            reloadGrid()

        case .symbolsUnshift:
            page = .symbol
            reloadGrid()

        case .numberShift:
            page = .number
            reloadGrid()

        case .alphabet:
            page = .normal
            reloadGrid()

        case .modeChange:
            language = (language == .khmer) ? .english : .khmer
            page = .normal
            reloadGrid()

        case .nextKeyboard:
            advanceToNextInputMode()
        }
    }

    /// SHIFT is one-shot: after typing a character it reverts to the normal page,
    /// matching the Android behaviour.
    private func revertShiftIfNeeded() {
        if page == .shift {
            page = .normal
            reloadGrid()
        }
    }
}

// MARK: - Server spell check

extension KeyboardViewController: SpellCheckPanelViewDelegate {

    /// Show the spell-check panel over the key grid and run the server check
    /// on the text before the cursor (the Android spellSuggestionView flow).
    private func presentSpellCheckPanel() {
        guard spellCheckPanel == nil, let keyboardView else { return }

        let panel = SpellCheckPanelView(theme: theme)
        panel.delegate = self
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor),
            panel.topAnchor.constraint(equalTo: keyboardView.topAnchor),
            panel.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor)
        ])
        spellCheckPanel = panel

        guard hasFullAccess else {
            panel.show(message: "Spell check needs Full Access.\nEnable it in Settings › General › Keyboard › Keyboards › Khmerlang.")
            return
        }
        let text = textDocumentProxy.documentContextBeforeInput ?? ""
        panel.setLoading()
        SpellCheckClient.shared.check(text: text) { [weak panel] result in
            guard let panel else { return }
            switch result {
            case .success(let typos):
                panel.show(typos: typos)
            case .failure(let error):
                panel.show(message: error.userMessage)
            }
        }
    }

    func spellCheckPanel(_ panel: SpellCheckPanelView, didPick suggestion: String, for typo: SpellCheckTypo) {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        guard let plan = SpellCheckClient.plan(replacing: typo, with: suggestion, in: before) else {
            return   // text changed since the check; nothing safe to do
        }
        replaceBeforeCursor(scalarCount: plan.deleteScalars, with: plan.insert)
        SpellCheckClient.shared.logSelection(word: typo.word, selected: suggestion)
    }

    func spellCheckPanelDidClose(_ panel: SpellCheckPanelView) {
        panel.removeFromSuperview()
        spellCheckPanel = nil
        updateSuggestions()
    }
}

// MARK: - Suggestion bar

extension KeyboardViewController: SuggestionBarViewDelegate {

    func suggestionBarDidChangeSettings(_ bar: SuggestionBarView) {
        updateSuggestions()
    }

    func suggestionBarDidRequestSpellCheck(_ bar: SuggestionBarView) {
        presentSpellCheckPanel()
    }

    func suggestionBar(_ bar: SuggestionBarView, didSelect suggestion: String) {
        // Replace the word currently being composed (the trailing segment of a
        // spaceless Khmer run, or the whitespace-delimited word) with the
        // chosen candidate. Khmer is written without spaces, so only Latin
        // candidates get the Android-style trailing space.
        let proxy = textDocumentProxy
        let isKhmerPick = Self.containsKhmer(suggestion)
        // Khmer words are separated by a zero-width space, matching the
        // Android keyboard and Khmer typing convention; English gets a space.
        let insertion: String
        if isKhmerPick {
            insertion = (suggestionsAreNextWords ? "\u{200B}" : "") + suggestion
        } else {
            insertion = suggestion + " "
        }
        if suggestionsAreNextWords {
            // Next-word prediction: nothing to replace, just append.
            proxy.insertText(insertion)
        } else {
            // Replace the composing word (scalar-accurate for Khmer clusters).
            let word = composingContext().word
            replaceBeforeCursor(scalarCount: word.unicodeScalars.count, with: insertion)
        }
        if isKhmerPick {
            // Follow the committed word with next-word predictions.
            let ctx = composingContext()
            let committed = ctx.word.isEmpty ? ctx.prevTwo : ctx.word
            let older = ctx.word.isEmpty ? ctx.prevOne : ctx.prevTwo
            suggestionsAreNextWords = true
            suggestionBar.setSuggestions(suggestionProvider.nextWords(prevOne: older, prevTwo: committed))
        } else {
            updateSuggestions()
        }
    }
}
