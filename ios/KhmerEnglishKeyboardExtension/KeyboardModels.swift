import UIKit

enum KeyboardMode: Equatable {
    case english
    case khmer
}

enum KeyCodes {
    // Mirrors the Android keyboard integer values found in `res/values/integer.xml`.
    static let shift = -1
    static let modeChange = -2
    static let cancel = -3
    static let done = -4
    static let delete = -5

    static let switchNextInputMode = -995 // keycode_switch_next_keyboard (icon button)
    static let sym = -997 // keycode_sym (unused in this starter scaffold)

    // Combining vowel long-press outputs for Khmer.
    static let am = -10 // "ាំ"
    static let om = -11 // "ុំ"
    static let os = -12 // "ោះ"
    static let asVowel = -13 // "េះ"
    static let ors = -14 // "ុះ"
    static let ies = -15 // "ិះ"

    static let space = 32
    static let newline = -999 // internal helper; not an Android code
}

struct KeyboardKey: Identifiable {
    let id = UUID()
    let code: Int
    let label: String
    let longPressCode: Int?
}

struct KeyboardRow {
    let keys: [KeyboardKey]
}

struct KeyboardLayout {
    let rows: [KeyboardRow]
}

enum KeyboardLayouts {
    static func layout(for mode: KeyboardMode) -> KeyboardLayout {
        switch mode {
        case .english:
            return englishLayout
        case .khmer:
            return khmerLayout
        }
    }

    // English layout taken from `res/xml/qwerty.xml` (NORMAL page subset).
    private static let englishLayout: KeyboardLayout = KeyboardLayout(rows: [
        KeyboardRow(keys: [
            KeyboardKey(code: 113, label: "q", longPressCode: nil),
            KeyboardKey(code: 119, label: "w", longPressCode: nil),
            KeyboardKey(code: 101, label: "e", longPressCode: nil),
            KeyboardKey(code: 114, label: "r", longPressCode: nil),
            KeyboardKey(code: 116, label: "t", longPressCode: nil),
            KeyboardKey(code: 121, label: "y", longPressCode: nil),
            KeyboardKey(code: 117, label: "u", longPressCode: nil),
            KeyboardKey(code: 105, label: "i", longPressCode: nil),
            KeyboardKey(code: 111, label: "o", longPressCode: nil),
            KeyboardKey(code: 112, label: "p", longPressCode: nil),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: 97, label: "a", longPressCode: nil),
            KeyboardKey(code: 115, label: "s", longPressCode: nil),
            KeyboardKey(code: 100, label: "d", longPressCode: nil),
            KeyboardKey(code: 102, label: "f", longPressCode: nil),
            KeyboardKey(code: 103, label: "g", longPressCode: nil),
            KeyboardKey(code: 104, label: "h", longPressCode: nil),
            KeyboardKey(code: 106, label: "j", longPressCode: nil),
            KeyboardKey(code: 107, label: "k", longPressCode: nil),
            KeyboardKey(code: 108, label: "l", longPressCode: nil),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: KeyCodes.shift, label: "Shift", longPressCode: nil),
            KeyboardKey(code: 122, label: "z", longPressCode: nil),
            KeyboardKey(code: 120, label: "x", longPressCode: nil),
            KeyboardKey(code: 99, label: "c", longPressCode: nil),
            KeyboardKey(code: 118, label: "v", longPressCode: nil),
            KeyboardKey(code: 98, label: "b", longPressCode: nil),
            KeyboardKey(code: 110, label: "n", longPressCode: nil),
            KeyboardKey(code: 109, label: "m", longPressCode: nil),
            KeyboardKey(code: KeyCodes.delete, label: "⌫", longPressCode: nil),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: KeyCodes.sym, label: "123", longPressCode: nil),
            KeyboardKey(code: KeyCodes.modeChange, label: "Lang", longPressCode: nil),
            KeyboardKey(code: KeyCodes.switchNextInputMode, label: "Next", longPressCode: nil),
            KeyboardKey(code: KeyCodes.space, label: "Space", longPressCode: nil),
            KeyboardKey(code: 46, label: ".", longPressCode: nil),
            KeyboardKey(code: KeyCodes.done, label: "Return", longPressCode: nil),
        ]),
    ])

    // Khmer layout taken from `res/xml/khmer_qwerty.xml` (NORMAL page subset).
    private static let khmerLayout: KeyboardLayout = KeyboardLayout(rows: [
        KeyboardRow(keys: [
            KeyboardKey(code: 6086, label: "ំ", longPressCode: 6092),
            KeyboardKey(code: 6081, label: "េ", longPressCode: KeyCodes.os),
            KeyboardKey(code: 6082, label: "ែ", longPressCode: 6063),
            KeyboardKey(code: 6042, label: "រ", longPressCode: 6059),
            KeyboardKey(code: 6031, label: "ត", longPressCode: 6053),
            KeyboardKey(code: 6041, label: "យ", longPressCode: 6055),
            KeyboardKey(code: 6075, label: "ុ", longPressCode: KeyCodes.om),
            KeyboardKey(code: 6071, label: "ិ", longPressCode: 6096),
            KeyboardKey(code: 6072, label: "ី", longPressCode: 6093),
            KeyboardKey(code: 6091, label: "់", longPressCode: 6089),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: 6070, label: "ា", longPressCode: KeyCodes.am),
            KeyboardKey(code: 6083, label: "ៃ", longPressCode: 6095),
            KeyboardKey(code: 6047, label: "ស", longPressCode: nil),
            KeyboardKey(code: 6026, label: "ដ", longPressCode: nil),
            KeyboardKey(code: 6020, label: "ង", longPressCode: nil),
            KeyboardKey(code: 6033, label: "ទ", longPressCode: 6054),
            KeyboardKey(code: 6098, label: "្", longPressCode: 6090),
            KeyboardKey(code: 6025, label: "ញ", longPressCode: nil),
            KeyboardKey(code: 6016, label: "ក", longPressCode: 6102),
            KeyboardKey(code: 6043, label: "ល", longPressCode: 6103),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: KeyCodes.shift, label: "Shift", longPressCode: nil),
            KeyboardKey(code: 6078, label: "ើ", longPressCode: KeyCodes.ors),
            KeyboardKey(code: 6021, label: "ច", longPressCode: KeyCodes.ies),
            KeyboardKey(code: 6023, label: "ជ", longPressCode: 6088),
            KeyboardKey(code: 6038, label: "ព", longPressCode: 6061),
            KeyboardKey(code: 6036, label: "ប", longPressCode: 6058),
            KeyboardKey(code: 6035, label: "ន", longPressCode: 6064),
            KeyboardKey(code: 6040, label: "ម", longPressCode: 6061),
            KeyboardKey(code: KeyCodes.delete, label: "⌫", longPressCode: nil),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: KeyCodes.sym, label: "123", longPressCode: nil),
            KeyboardKey(code: KeyCodes.modeChange, label: "Lang", longPressCode: nil),
            KeyboardKey(code: KeyCodes.switchNextInputMode, label: "Next", longPressCode: nil),
            KeyboardKey(code: KeyCodes.space, label: "Space", longPressCode: nil),
            KeyboardKey(code: 46, label: ".", longPressCode: nil),
            KeyboardKey(code: KeyCodes.done, label: "Return", longPressCode: nil),
        ]),
    ])
}

extension KeyboardKey {
    func outputLabel(isShiftOn: Bool, mode: KeyboardMode) -> String {
        guard isShiftOn, mode == .english else { return label }
        // Only uppercase ASCII letters (like `q`..`p`).
        if (97...122).contains(code) { return label.uppercased() }
        return label
    }
}

