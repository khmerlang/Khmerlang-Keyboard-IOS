//
//  KeyboardLayouts.swift
//  Khmerlang
//
//  The keyboard layouts, ported 1:1 from the Android resources:
//    res/xml/khmer_qwerty.xml, khmer_qwerty_shift.xml, khmer_symbol.xml,
//    khmer_symbol_shift.xml, qwerty.xml, qwerty_shift.xml, qwerty_symbol.xml,
//    qwerty_symbol_shift.xml, number.xml
//

import UIKit

enum KeyboardLayouts {

    // MARK: - Convenience builders

    /// A character key whose inserted text equals its label, optionally with a
    /// long-press sub-label.
    private static func c(_ label: String, sub: String? = nil, w: CGFloat = 10) -> Key {
        Key(label: label, subLabel: sub, action: .character(label), width: w)
    }

    /// A function (special) key.
    private static func fn(_ action: KeyAction,
                           label: String = "",
                           icon: String? = nil,
                           w: CGFloat = 10,
                           fontScale: CGFloat = 1.0) -> Key {
        Key(label: label, action: action, width: w, icon: icon, isSpecial: true, fontScale: fontScale)
    }

    // Shared function keys.
    private static var shiftKey: Key { fn(.shift, icon: "shift", w: 15) }
    private static var unshiftKey: Key { fn(.unshift, icon: "shift.fill", w: 15) }
    private static var deleteKey: Key {
        Key(label: "", action: .backspace, width: 15, icon: "delete.left",
            isSpecial: true, isRepeatable: true)
    }
    private static var modeChangeKey: Key { fn(.modeChange, icon: "arrow.left.arrow.right", w: 10) }
    private static var globeKey: Key { fn(.nextKeyboard, icon: "gearshape", w: 10) }
    private static var returnKey: Key { fn(.enter, icon: "return", w: 15) }

    private static func spaceKey(_ language: KeyboardLanguage) -> Key {
        Key(label: language.spaceLabel, action: .space, width: 40, fontScale: 0.7)
    }

    // MARK: - Layout resolution

    static func grid(language: KeyboardLanguage, page: KeyboardPage) -> KeyboardGrid {
        switch page {
        case .number:
            return numberGrid(language)
        case .normal:
            return language == .khmer ? khmerNormal : englishNormal
        case .shift:
            return language == .khmer ? khmerShift : englishShift
        case .symbol:
            return language == .khmer ? khmerSymbol(language) : englishSymbol(language)
        case .symbolShift:
            return language == .khmer ? khmerSymbolShift(language) : englishSymbolShift(language)
        }
    }

    // MARK: - Khmer: normal (khmer_qwerty.xml)

    private static var khmerNormal: KeyboardGrid {
        [
            [c("ំ", sub: "៌"), c("េ", sub: "ោះ"), c("ែ", sub: "ឯ"), c("រ", sub: "ឫ"),
             c("ត", sub: "ឥ"), c("យ", sub: "ឧ"), c("ុ", sub: "ុំ"), c("ិ", sub: "័"),
             c("ី", sub: "៍"), c("់", sub: "៉")],
            [c("ា", sub: "ាំ"), c("ៃ", sub: "៏"), c("ស"), c("ដ"), c("ង"),
             c("ទ", sub: "ឦ"), c("្", sub: "៊"), c("ញ"), c("ក", sub: "៖"), c("ល", sub: "ៗ")],
            [shiftKey, c("ើ", sub: "ុះ"), c("ច", sub: "ិះ"), c("ជ", sub: "ៈ"),
             c("ព", sub: "ឭ"), c("ប", sub: "ឪ"), c("ន", sub: "ឰ"), c("ម", sub: "ឭ"), deleteKey],
            [fn(.symbols, label: "១២៣", w: 15, fontScale: 0.6), modeChangeKey, globeKey,
             spaceKey(.khmer), c("។", sub: "៕", w: 10), returnKey]
        ]
    }

    // MARK: - Khmer: shift (khmer_qwerty_shift.xml)

    private static var khmerShift: KeyboardGrid {
        [
            [c("ឈ"), c("ឆ"), c("ឹ"), c("ឺ"), c("ួ"), c("ូ"), c("ោ"), c("ៅ"), c("ភ"), c("ផ")],
            [c("ៀ"), c("ឿ"), c("ឌ"), c("ធ"), c("ថ"), c("អ"), c("ះ"), c("ហ"), c("គ"), c("ឡ")],
            [unshiftKey, c("ឋ"), c("ឍ"), c("ខ"), c("ឃ"), c("វ"), c("ណ"), c("ឲ"), deleteKey],
            [fn(.symbols, label: "១២៣", w: 15, fontScale: 0.6), modeChangeKey, globeKey,
             spaceKey(.khmer), c("?", w: 10), returnKey]
        ]
    }

    // MARK: - Khmer: symbol (khmer_symbol.xml)

    private static func khmerSymbol(_ language: KeyboardLanguage) -> KeyboardGrid {
        [
            [c("១", sub: "1"), c("២", sub: "2"), c("៣", sub: "3"), c("៤", sub: "4"), c("៥", sub: "5"),
             c("៦", sub: "6"), c("៧", sub: "7"), c("៨", sub: "8"), c("៩", sub: "9"), c("០", sub: "0")],
            [c("+", sub: "~"), c("×", sub: "*"), c("÷", sub: "^"), c("=", sub: "("), c("៛", sub: ")"),
             c("ឪ", sub: "$"), c("ឱ", sub: "€"), c("ឧ", sub: "£"), c("ឩ", sub: "¥"), c("ឨ", sub: "៙")],
            [fn(.symbolsShift, label: "1/2", w: 15), c("៚"), c("ៜ"), c("៝"), c("៎"),
             c("ឝ"), c("ឞ"), c("ឳ"), deleteKey],
            [fn(.alphabet, label: "កខគ", w: 15, fontScale: 0.7), modeChangeKey, globeKey,
             spaceKey(language), c("។", sub: "៕", w: 10), returnKey]
        ]
    }

    // MARK: - Khmer: symbol shift (khmer_symbol_shift.xml)

    private static func khmerSymbolShift(_ language: KeyboardLanguage) -> KeyboardGrid {
        [
            [c("៱"), c("៲"), c("៳"), c("៴"), c("៵"), c("៶"), c("៷"), c("៸"), c("៹"), c("៰")],
            [c("/"), c("\\"), c("`"), c("´"), c("<"), c(">"), c("{"), c("}"), c("["), c("]")],
            [fn(.symbolsUnshift, label: "2/2", w: 15), c("_"), c("#"), c("&"), c("@"),
             c("%"), c("'"), c("\""), deleteKey],
            [fn(.alphabet, label: "កខគ", w: 15, fontScale: 0.7), modeChangeKey, globeKey,
             spaceKey(language), c(",", w: 10), returnKey]
        ]
    }

    // MARK: - English: normal (qwerty.xml)

    private static var englishNormal: KeyboardGrid {
        [
            [c("q"), c("w"), c("e"), c("r"), c("t"), c("y"), c("u"), c("i"), c("o"), c("p")],
            [c("a"), c("s"), c("d"), c("f"), c("g"), c("h"), c("j"), c("k"), c("l")],
            [shiftKey, c("z"), c("x"), c("c"), c("v"), c("b"), c("n"), c("m"), deleteKey],
            [fn(.symbols, label: "?123", w: 15, fontScale: 0.7), modeChangeKey, globeKey,
             spaceKey(.english), c(".", w: 10), returnKey]
        ]
    }

    // MARK: - English: shift (qwerty_shift.xml)

    private static var englishShift: KeyboardGrid {
        [
            [c("Q"), c("W"), c("E"), c("R"), c("T"), c("Y"), c("U"), c("I"), c("O"), c("P")],
            [c("A"), c("S"), c("D"), c("F"), c("G"), c("H"), c("J"), c("K"), c("L")],
            [unshiftKey, c("Z"), c("X"), c("C"), c("V"), c("B"), c("N"), c("M"), deleteKey],
            [fn(.symbols, label: "?123", w: 15, fontScale: 0.7), modeChangeKey, globeKey,
             spaceKey(.english), c(",", w: 10), returnKey]
        ]
    }

    // MARK: - English: symbol (qwerty_symbol.xml)

    private static func englishSymbol(_ language: KeyboardLanguage) -> KeyboardGrid {
        [
            [c("1"), c("2"), c("3"), c("4"), c("5"), c("6"), c("7"), c("8"), c("9"), c("0")],
            [c("@"), c("#"), c("$"), c("%"), c("&"), c("*"), c("-"), c("="), c("("), c(")")],
            [fn(.symbolsShift, label: "=\\<", w: 15), c("!"), c("\""), c("'"), c(":"),
             c(";"), c("/"), c("?"), deleteKey],
            [fn(.alphabet, label: "ABC", w: 15, fontScale: 0.8), fn(.numberShift, icon: "circle.grid.3x3", w: 10),
             globeKey, spaceKey(language), c(".", w: 10), returnKey]
        ]
    }

    // MARK: - English: symbol shift (qwerty_symbol_shift.xml)

    private static func englishSymbolShift(_ language: KeyboardLanguage) -> KeyboardGrid {
        [
            [c("~"), c("±"), c("×"), c("÷"), c("•"), c("°"), c("`"), c("´"), c("{"), c("}")],
            [c("©"), c("£"), c("€"), c("^"), c("®"), c("¥"), c("_"), c("+"), c("["), c("]")],
            [fn(.symbolsUnshift, label: "?123", w: 15, fontScale: 0.7), c("៛"), c("៚"), c("<"),
             c(">"), c("|"), c("\\"), c("¿"), deleteKey],
            [fn(.alphabet, label: "ABC", w: 15, fontScale: 0.8), fn(.numberShift, icon: "circle.grid.3x3", w: 10),
             globeKey, spaceKey(language), c(",", w: 10), returnKey]
        ]
    }

    // MARK: - Number pad (number.xml, shared by both languages)

    private static func numberGrid(_ language: KeyboardLanguage) -> KeyboardGrid {
        [
            [c("+", w: 20), c("1", w: 20), c("2", w: 20), c("3", w: 20), c("%", w: 20)],
            [c("(", w: 20), c("4", w: 20), c("5", w: 20), c("6", w: 20),
             Key(label: "", action: .space, width: 20, icon: "space")],
            [c(")", w: 20), c("7", w: 20), c("8", w: 20), c("9", w: 20),
             Key(label: "", action: .backspace, width: 20, icon: "delete.left",
                 isSpecial: true, isRepeatable: true)],
            [fn(.alphabet, label: "ABC", w: 20, fontScale: 0.8),
             fn(.symbols, label: "?123", w: 20, fontScale: 0.7),
             c(",", w: 10), c("0", w: 20), c(".", w: 10), returnKey]
        ]
    }
}
