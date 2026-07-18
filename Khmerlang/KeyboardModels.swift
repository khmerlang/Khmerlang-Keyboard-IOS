//
//  KeyboardModels.swift
//  Khmerlang
//
//  Core data model for the keyboard, ported from the Android Khmerlang keyboard
//  (com.rathanak.khmerroman). Describes keys, layouts, pages and languages.
//

import UIKit

/// The action a key performs when tapped.
enum KeyAction: Equatable {
    /// Insert the associated string into the document.
    case character(String)
    /// Delete backwards (repeatable).
    case backspace
    /// Switch to the SHIFT page (one-shot: reverts to normal after next character).
    case shift
    /// Return from SHIFT to the normal alphabetic page.
    case unshift
    /// Go to the symbol page for the current language.
    case symbols
    /// Go to the second symbol page (symbol shift).
    case symbolsShift
    /// Return from the second symbol page to the first symbol page.
    case symbolsUnshift
    /// Go to the numeric keypad page.
    case numberShift
    /// Return to the normal alphabetic page (the "ABC" / "កខគ" key).
    case alphabet
    /// Toggle between Khmer and English layouts (the swap key).
    case modeChange
    /// Open the containing Khmerlang app (the globe key). Switching to the
    /// next system keyboard is handled by iOS itself: it overlays its own
    /// switcher on the keyboard whenever more than one keyboard is enabled
    /// (`UIInputViewController.needsInputModeSwitchKey`), so this button is
    /// free to do something else.
    case nextKeyboard
    /// Insert a space.
    case space
    /// Insert a newline / perform the return action.
    case enter
}

/// A single key on the keyboard.
struct Key {
    /// Primary label shown on the key.
    let label: String
    /// Optional secondary label (shown small, inserted on long-press).
    var subLabel: String? = nil
    /// The action performed on tap.
    let action: KeyAction
    /// Width as a percentage of the row (rows should sum to ~100).
    var width: CGFloat = 10
    /// Optional SF Symbol name used instead of a text label.
    var icon: String? = nil
    /// Whether this is a function key (rendered with the darker background).
    var isSpecial: Bool = false
    /// Whether holding the key repeats the tap (used for backspace).
    var isRepeatable: Bool = false
    /// Scale factor applied to the label font (for keys with long text like "១២៣").
    var fontScale: CGFloat = 1.0
}

typealias KeyRow = [Key]
typealias KeyboardGrid = [KeyRow]

/// Which page of a given language is currently displayed.
enum KeyboardPage {
    case normal
    case shift
    case symbol
    case symbolShift
    case number
}

/// The active input language.
enum KeyboardLanguage {
    case khmer
    case english

    var spaceLabel: String {
        switch self {
        case .khmer: return "ខ្មែរ"
        case .english: return "English"
        }
    }
}

/// Simple light/dark theme derived from the host's keyboard appearance.
struct KeyboardTheme {
    let background: UIColor
    let keyBackground: UIColor
    let specialKeyBackground: UIColor
    let keyText: UIColor
    let subLabelText: UIColor
    let keyShadow: UIColor
    let popupBackground: UIColor

    static func theme(for appearance: UIKeyboardAppearance) -> KeyboardTheme {
        let dark = appearance == .dark
        if dark {
            return KeyboardTheme(
                background: UIColor(white: 0.13, alpha: 1.0),
                keyBackground: UIColor(white: 0.35, alpha: 1.0),
                specialKeyBackground: UIColor(white: 0.22, alpha: 1.0),
                keyText: .white,
                subLabelText: UIColor(white: 0.75, alpha: 1.0),
                keyShadow: UIColor(white: 0.0, alpha: 0.6),
                popupBackground: UIColor(white: 0.45, alpha: 1.0)
            )
        } else {
            return KeyboardTheme(
                background: UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1.0),
                keyBackground: .white,
                specialKeyBackground: UIColor(red: 0.67, green: 0.70, blue: 0.74, alpha: 1.0),
                keyText: .black,
                subLabelText: UIColor(white: 0.4, alpha: 1.0),
                keyShadow: UIColor(white: 0.5, alpha: 0.9),
                popupBackground: .white
            )
        }
    }
}
