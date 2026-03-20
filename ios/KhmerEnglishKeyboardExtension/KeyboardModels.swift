import Foundation

enum KeyboardMode: Equatable {
    case english
    case khmer
}

enum KeyboardPage: Equatable {
    case normal
    case shift
    case symbol
    case symbolShift
    case number
}

enum KeyCodes {
    // Mirrors values found in `res/values/integer.xml` and `res/values/integers.xml`.
    static let shift = -1
    static let unshift = -996
    static let modeChange = -2
    static let cancel = -3
    static let done = -4
    static let delete = -5

    static let switchNextInputMode = -995
    static let abc = -998
    static let sym = -997
    static let symUnshift = -1000
    static let symShift = -999
    static let numberShift = -1001

    // Khmer combining vowel long-press outputs (from integer.xml).
    static let am = -10 // "ាំ"
    static let om = -11 // "ុំ"
    static let os = -12 // "ោះ"
    static let asVowel = -13 // "េះ"
    static let ors = -14 // "ុះ"
    static let ies = -15 // "ិះ"

    static let space = 32
}

struct KeyboardKey: Identifiable {
    let id = UUID()
    let code: Int
    let label: String
    let longPressCode: Int?
    let isRepeatable: Bool

    init(code: Int, label: String, longPressCode: Int? = nil, isRepeatable: Bool = false) {
        self.code = code
        self.label = label
        self.longPressCode = longPressCode
        self.isRepeatable = isRepeatable
    }
}

struct KeyboardRow {
    let keys: [KeyboardKey]
}

struct KeyboardLayout {
    let rows: [KeyboardRow]
}

enum KeyboardLayouts {
    static func layout(language: KeyboardMode, page: KeyboardPage) -> KeyboardLayout {
        switch (language, page) {
        case (.english, .normal):
            return englishNormal
        case (.english, .shift):
            return englishShift
        case (.english, .symbol):
            return englishSymbol
        case (.english, .symbolShift):
            return englishSymbolShift
        case (.english, .number):
            return numberLayout

        case (.khmer, .normal):
            return khmerNormal
        case (.khmer, .shift):
            return khmerShift
        case (.khmer, .symbol):
            return khmerSymbol
        case (.khmer, .symbolShift):
            return khmerSymbolShift
        case (.khmer, .number):
            return numberLayout
        }
    }

    // English NORMAL from `res/xml/qwerty.xml`.
    private static let englishNormal: KeyboardLayout = KeyboardLayout(rows: [
        KeyboardRow(keys: [
            KeyboardKey(code: 113, label: "q"),
            KeyboardKey(code: 119, label: "w"),
            KeyboardKey(code: 101, label: "e"),
            KeyboardKey(code: 114, label: "r"),
            KeyboardKey(code: 116, label: "t"),
            KeyboardKey(code: 121, label: "y"),
            KeyboardKey(code: 117, label: "u"),
            KeyboardKey(code: 105, label: "i"),
            KeyboardKey(code: 111, label: "o"),
            KeyboardKey(code: 112, label: "p"),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: 97, label: "a"),
            KeyboardKey(code: 115, label: "s"),
            KeyboardKey(code: 100, label: "d"),
            KeyboardKey(code: 102, label: "f"),
            KeyboardKey(code: 103, label: "g"),
            KeyboardKey(code: 104, label: "h"),
            KeyboardKey(code: 106, label: "j"),
            KeyboardKey(code: 107, label: "k"),
            KeyboardKey(code: 108, label: "l"),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: KeyCodes.shift, label: "Shift"),
            KeyboardKey(code: 122, label: "z"),
            KeyboardKey(code: 120, label: "x"),
            KeyboardKey(code: 99, label: "c"),
            KeyboardKey(code: 118, label: "v"),
            KeyboardKey(code: 98, label: "b"),
            KeyboardKey(code: 110, label: "n"),
            KeyboardKey(code: 109, label: "m"),
            KeyboardKey(code: KeyCodes.delete, label: "⌫", isRepeatable: true),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: KeyCodes.sym, label: "?123"),
            KeyboardKey(code: KeyCodes.modeChange, label: "Lang"),
            KeyboardKey(code: KeyCodes.switchNextInputMode, label: "Next"),
            KeyboardKey(code: KeyCodes.space, label: "Space"),
            KeyboardKey(code: 44, label: ","),
            KeyboardKey(code: KeyCodes.done, label: "Return"),
        ]),
    ])

    // English SHIFT from `res/xml/qwerty_shift.xml`.
    private static let englishShift: KeyboardLayout = KeyboardLayout(rows: [
        KeyboardRow(keys: [
            KeyboardKey(code: 81, label: "Q"),
            KeyboardKey(code: 87, label: "W"),
            KeyboardKey(code: 69, label: "E"),
            KeyboardKey(code: 82, label: "R"),
            KeyboardKey(code: 84, label: "T"),
            KeyboardKey(code: 89, label: "Y"),
            KeyboardKey(code: 85, label: "U"),
            KeyboardKey(code: 73, label: "I"),
            KeyboardKey(code: 79, label: "O"),
            KeyboardKey(code: 80, label: "P"),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: 65, label: "A"),
            KeyboardKey(code: 83, label: "S"),
            KeyboardKey(code: 68, label: "D"),
            KeyboardKey(code: 70, label: "F"),
            KeyboardKey(code: 71, label: "G"),
            KeyboardKey(code: 72, label: "H"),
            KeyboardKey(code: 74, label: "J"),
            KeyboardKey(code: 75, label: "K"),
            KeyboardKey(code: 76, label: "L"),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: KeyCodes.unshift, label: "Caps"),
            KeyboardKey(code: 90, label: "Z"),
            KeyboardKey(code: 88, label: "X"),
            KeyboardKey(code: 67, label: "C"),
            KeyboardKey(code: 86, label: "V"),
            KeyboardKey(code: 66, label: "B"),
            KeyboardKey(code: 78, label: "N"),
            KeyboardKey(code: 77, label: "M"),
            KeyboardKey(code: KeyCodes.delete, label: "⌫", isRepeatable: true),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: KeyCodes.sym, label: "?123"),
            KeyboardKey(code: KeyCodes.modeChange, label: "Lang"),
            KeyboardKey(code: KeyCodes.switchNextInputMode, label: "Next"),
            KeyboardKey(code: KeyCodes.space, label: "Space"),
            KeyboardKey(code: 44, label: ","),
            KeyboardKey(code: KeyCodes.done, label: "Return"),
        ]),
    ])

    // English SYMBOL from `res/xml/qwerty_symbol.xml`.
    private static let englishSymbol: KeyboardLayout = KeyboardLayout(rows: [
        KeyboardRow(keys: [
            KeyboardKey(code: 43, label: "+", longPressCode: nil),
            KeyboardKey(code: 49, label: "1"),
            KeyboardKey(code: 50, label: "2"),
            KeyboardKey(code: 51, label: "3"),
            KeyboardKey(code: 37, label: "%"),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: 40, label: "("),
            KeyboardKey(code: 52, label: "4"),
            KeyboardKey(code: 53, label: "5"),
            KeyboardKey(code: 54, label: "6"),
            KeyboardKey(code: KeyCodes.space, label: "Space"),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: 41, label: ")"),
            KeyboardKey(code: 55, label: "7"),
            KeyboardKey(code: 56, label: "8"),
            KeyboardKey(code: 57, label: "9"),
            KeyboardKey(code: KeyCodes.delete, label: "⌫", isRepeatable: true),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: KeyCodes.abc, label: "ABC"),
            KeyboardKey(code: KeyCodes.symShift, label: "=\\>"),
            KeyboardKey(code: KeyCodes.switchNextInputMode, label: "Next"),
            KeyboardKey(code: KeyCodes.space, label: "Space"),
            KeyboardKey(code: 46, label: "."),
            KeyboardKey(code: KeyCodes.done, label: "Return"),
        ]),
    ])

    // English SYMBOL_SHIFT from `res/xml/qwerty_symbol_shift.xml`.
    private static let englishSymbolShift: KeyboardLayout = KeyboardLayout(rows: [
        KeyboardRow(keys: [
            KeyboardKey(code: 126, label: "~"),
            KeyboardKey(code: 177, label: "±"),
            KeyboardKey(code: 215, label: "×"),
            KeyboardKey(code: 247, label: "÷"),
            KeyboardKey(code: 8226, label: "•"),
            KeyboardKey(code: 176, label: "°"),
            KeyboardKey(code: 96, label: "`"),
            KeyboardKey(code: 180, label: "´"),
            KeyboardKey(code: 123, label: "{"),
            KeyboardKey(code: 125, label: "}"),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: 169, label: "©"),
            KeyboardKey(code: 163, label: "£"),
            KeyboardKey(code: 8364, label: "€"),
            KeyboardKey(code: 94, label: "^"),
            KeyboardKey(code: 174, label: "®"),
            KeyboardKey(code: 165, label: "¥"),
            KeyboardKey(code: 95, label: "_"),
            KeyboardKey(code: 43, label: "+"),
            KeyboardKey(code: 91, label: "["),
            KeyboardKey(code: 93, label: "]"),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: KeyCodes.symUnshift, label: "?123"),
            KeyboardKey(code: 6107, label: "៛"),
            KeyboardKey(code: 6106, label: "៚"),
            KeyboardKey(code: 60, label: "<"),
            KeyboardKey(code: 62, label: ">"),
            KeyboardKey(code: 124, label: "|"),
            KeyboardKey(code: 92, label: "\\"),
            KeyboardKey(code: 191, label: "¿"),
            KeyboardKey(code: KeyCodes.delete, label: "⌫", isRepeatable: true),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: KeyCodes.abc, label: "ABC"),
            KeyboardKey(code: KeyCodes.numberShift, label: "123"),
            KeyboardKey(code: KeyCodes.switchNextInputMode, label: "Next"),
            KeyboardKey(code: KeyCodes.space, label: "Space"),
            KeyboardKey(code: 44, label: ","),
            KeyboardKey(code: KeyCodes.done, label: "Return"),
        ]),
    ])

    // Khmer NORMAL from `res/xml/khmer_qwerty.xml`.
    private static let khmerNormal: KeyboardLayout = KeyboardLayout(rows: [
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
            KeyboardKey(code: 6047, label: "ស"),
            KeyboardKey(code: 6026, label: "ដ"),
            KeyboardKey(code: 6020, label: "ង"),
            KeyboardKey(code: 6033, label: "ទ", longPressCode: 6054),
            KeyboardKey(code: 6098, label: "្", longPressCode: 6090),
            KeyboardKey(code: 6025, label: "ញ"),
            KeyboardKey(code: 6016, label: "ក", longPressCode: 6102),
            KeyboardKey(code: 6043, label: "ល", longPressCode: 6103),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: KeyCodes.shift, label: "Shift"),
            KeyboardKey(code: 6078, label: "ើ", longPressCode: KeyCodes.ors),
            KeyboardKey(code: 6021, label: "ច", longPressCode: KeyCodes.ies),
            KeyboardKey(code: 6023, label: "ជ", longPressCode: 6088),
            KeyboardKey(code: 6038, label: "ព", longPressCode: 6061),
            KeyboardKey(code: 6036, label: "ប", longPressCode: 6058),
            KeyboardKey(code: 6035, label: "ន", longPressCode: 6064),
            KeyboardKey(code: 6040, label: "ម", longPressCode: 6061),
            KeyboardKey(code: KeyCodes.delete, label: "⌫", isRepeatable: true),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: KeyCodes.sym, label: "123"),
            KeyboardKey(code: KeyCodes.modeChange, label: "Lang"),
            KeyboardKey(code: KeyCodes.switchNextInputMode, label: "Next"),
            KeyboardKey(code: KeyCodes.space, label: "Space"),
            KeyboardKey(code: 46, label: "."),
            KeyboardKey(code: KeyCodes.done, label: "Return"),
        ]),
    ])

    // Khmer SHIFT from `res/xml/khmer_qwerty_shift.xml`.
    private static let khmerShift: KeyboardLayout = KeyboardLayout(rows: [
        KeyboardRow(keys: [
            KeyboardKey(code: 6024, label: "ឈ"),
            KeyboardKey(code: 6022, label: "ឆ"),
            KeyboardKey(code: 6073, label: "ឹ"),
            KeyboardKey(code: 6074, label: "ឺ"),
            KeyboardKey(code: 6077, label: "ួ"),
            KeyboardKey(code: 6076, label: "ូ"),
            KeyboardKey(code: 6084, label: "ោ"),
            KeyboardKey(code: 6085, label: "ៅ"),
            KeyboardKey(code: 6039, label: "ភ"),
            KeyboardKey(code: 6037, label: "ផ"),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: 6080, label: "ៀ"),
            KeyboardKey(code: 6079, label: "ឿ"),
            KeyboardKey(code: 6028, label: "ឌ"),
            KeyboardKey(code: 6034, label: "ធ"),
            KeyboardKey(code: 6032, label: "ថ"),
            KeyboardKey(code: 6050, label: "អ"),
            KeyboardKey(code: 6087, label: "ះ"),
            KeyboardKey(code: 6048, label: "ហ"),
            KeyboardKey(code: 6018, label: "គ"),
            KeyboardKey(code: 6049, label: "ឡ"),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: KeyCodes.unshift, label: "Caps"),
            KeyboardKey(code: 6027, label: "ឋ"),
            KeyboardKey(code: 6029, label: "ឍ"),
            KeyboardKey(code: 6017, label: "ខ"),
            KeyboardKey(code: 6019, label: "ឃ"),
            KeyboardKey(code: 6044, label: "វ"),
            KeyboardKey(code: 6030, label: "ណ"),
            KeyboardKey(code: 6066, label: "ឲ"),
            KeyboardKey(code: KeyCodes.delete, label: "⌫", isRepeatable: true),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: KeyCodes.sym, label: "123"),
            KeyboardKey(code: KeyCodes.modeChange, label: "Lang"),
            KeyboardKey(code: KeyCodes.switchNextInputMode, label: "Next"),
            KeyboardKey(code: KeyCodes.space, label: "Space"),
            KeyboardKey(code: 46, label: "."),
            KeyboardKey(code: KeyCodes.done, label: "Return"),
        ]),
    ])

    // Khmer SYMBOL from `res/xml/khmer_symbol.xml`.
    private static let khmerSymbol: KeyboardLayout = KeyboardLayout(rows: [
        KeyboardRow(keys: [
            KeyboardKey(code: 6113, label: "១"),
            KeyboardKey(code: 6114, label: "២"),
            KeyboardKey(code: 6115, label: "៣"),
            KeyboardKey(code: 6116, label: "៤"),
            KeyboardKey(code: 6117, label: "៥"),
            KeyboardKey(code: 6118, label: "៦"),
            KeyboardKey(code: 6119, label: "៧"),
            KeyboardKey(code: 6120, label: "៨"),
            KeyboardKey(code: 6121, label: "៩"),
            KeyboardKey(code: 6112, label: "០"),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: 43, label: "+"),
            KeyboardKey(code: 215, label: "×"),
            KeyboardKey(code: 247, label: "÷"),
            KeyboardKey(code: 61, label: "="),
            KeyboardKey(code: 6107, label: "៛"),
            KeyboardKey(code: 6058, label: "ឪ"),
            KeyboardKey(code: 6065, label: "ឱ"),
            KeyboardKey(code: 6055, label: "ឧ"),
            KeyboardKey(code: 6057, label: "ឩ"),
            KeyboardKey(code: 6056, label: "ឨ"),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: KeyCodes.symShift, label: "1/2"),
            KeyboardKey(code: 6106, label: "៚"),
            KeyboardKey(code: 6108, label: "ៜ"),
            KeyboardKey(code: 6109, label: "៝"),
            KeyboardKey(code: 6094, label: "៎"),
            KeyboardKey(code: 6045, label: "ឝ"),
            KeyboardKey(code: 6105, label: "ឞ"),
            KeyboardKey(code: 6067, label: "ឳ"),
            KeyboardKey(code: KeyCodes.delete, label: "⌫", isRepeatable: true),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: KeyCodes.abc, label: "កខគ"),
            KeyboardKey(code: KeyCodes.modeChange, label: "Lang"),
            KeyboardKey(code: KeyCodes.switchNextInputMode, label: "Next"),
            KeyboardKey(code: KeyCodes.space, label: "Space"),
            KeyboardKey(code: 46, label: "."),
            KeyboardKey(code: KeyCodes.done, label: "Return"),
        ]),
    ])

    // Khmer SYMBOL_SHIFT from `res/xml/khmer_symbol_shift.xml`.
    private static let khmerSymbolShift: KeyboardLayout = KeyboardLayout(rows: [
        KeyboardRow(keys: [
            KeyboardKey(code: 6129, label: "៱"),
            KeyboardKey(code: 6130, label: "៲"),
            KeyboardKey(code: 6131, label: "៳"),
            KeyboardKey(code: 6132, label: "៴"),
            KeyboardKey(code: 6133, label: "៵"),
            KeyboardKey(code: 6134, label: "៶"),
            KeyboardKey(code: 6135, label: "៷"),
            KeyboardKey(code: 6136, label: "៸"),
            KeyboardKey(code: 6137, label: "៹"),
            KeyboardKey(code: 6128, label: "៰"),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: 47, label: "/"),
            KeyboardKey(code: 92, label: "\\"),
            KeyboardKey(code: 96, label: "`"),
            KeyboardKey(code: 180, label: "´"),
            KeyboardKey(code: 60, label: "<"),
            KeyboardKey(code: 62, label: ">"),
            KeyboardKey(code: 123, label: "{"),
            KeyboardKey(code: 125, label: "}"),
            KeyboardKey(code: 91, label: "["),
            KeyboardKey(code: 93, label: "]"),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: KeyCodes.symUnshift, label: "?123"),
            KeyboardKey(code: 95, label: "_"),
            KeyboardKey(code: 35, label: "#"),
            KeyboardKey(code: 38, label: "&"),
            KeyboardKey(code: 64, label: "@"),
            KeyboardKey(code: 37, label: "%"),
            KeyboardKey(code: 39, label: "'"),
            KeyboardKey(code: 34, label: "\""),
            KeyboardKey(code: KeyCodes.delete, label: "⌫", isRepeatable: true),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: KeyCodes.abc, label: "កខគ"),
            KeyboardKey(code: KeyCodes.modeChange, label: "Lang"),
            KeyboardKey(code: KeyCodes.switchNextInputMode, label: "Next"),
            KeyboardKey(code: KeyCodes.space, label: "Space"),
            KeyboardKey(code: 44, label: ","),
            KeyboardKey(code: KeyCodes.done, label: "Return"),
        ]),
    ])

    // Number page from `res/xml/number.xml` (shared).
    private static let numberLayout: KeyboardLayout = KeyboardLayout(rows: [
        KeyboardRow(keys: [
            KeyboardKey(code: 49, label: "1"),
            KeyboardKey(code: 50, label: "2"),
            KeyboardKey(code: 51, label: "3"),
            KeyboardKey(code: 52, label: "4"),
            KeyboardKey(code: 53, label: "5"),
            KeyboardKey(code: 54, label: "6"),
            KeyboardKey(code: 55, label: "7"),
            KeyboardKey(code: 56, label: "8"),
            KeyboardKey(code: 57, label: "9"),
            KeyboardKey(code: 48, label: "0"),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: 64, label: "@"),
            KeyboardKey(code: 35, label: "#"),
            KeyboardKey(code: 36, label: "$"),
            KeyboardKey(code: 37, label: "%"),
            KeyboardKey(code: 38, label: "&"),
            KeyboardKey(code: 42, label: "*"),
            KeyboardKey(code: 45, label: "-"),
            KeyboardKey(code: 61, label: "="),
            KeyboardKey(code: 40, label: "("),
            KeyboardKey(code: 41, label: ")"),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: KeyCodes.symShift, label: ">=\\"),
            KeyboardKey(code: 33, label: "!"),
            KeyboardKey(code: 34, label: "\""),
            KeyboardKey(code: 39, label: "'"),
            KeyboardKey(code: 58, label: ":"),
            KeyboardKey(code: 59, label: ";"),
            KeyboardKey(code: 47, label: "/"),
            KeyboardKey(code: 63, label: "?"),
            KeyboardKey(code: KeyCodes.delete, label: "⌫", isRepeatable: true),
        ]),
        KeyboardRow(keys: [
            KeyboardKey(code: KeyCodes.abc, label: "ABC"),
            KeyboardKey(code: KeyCodes.numberShift, label: "123"),
            KeyboardKey(code: KeyCodes.switchNextInputMode, label: "Next"),
            KeyboardKey(code: KeyCodes.space, label: "Space"),
            KeyboardKey(code: 46, label: "."),
            KeyboardKey(code: KeyCodes.done, label: "Return"),
        ]),
    ])
}

