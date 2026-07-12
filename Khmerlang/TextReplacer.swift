//
//  TextReplacer.swift
//  Khmerlang
//
//  Scalar-accurate "replace the text before the cursor" for the keyboard.
//
//  deleteBackward's granularity varies by host app, iOS version and script:
//  one press may remove a single scalar, a combining pair, or a whole Khmer
//  cluster (e.g. ស្រ). Counting presses therefore corrupts text (the សស្រី
//  bug). Instead, progress is measured against the document after every
//  press, and if the final press over-deletes past the boundary (a cluster
//  spanning it), the over-deleted scalars are restored before inserting.
//

import Foundation

enum TextReplacer {

    /// Delete exactly `scalarCount` Unicode scalars before the cursor, then
    /// insert `replacement`. The document is accessed through closures so the
    /// logic is testable without UIKit.
    static func replaceBeforeCursor(scalarCount: Int, replacement: String,
                                    context: () -> String?,
                                    deleteBackward: () -> Void,
                                    insert: (String) -> Void) {
        guard scalarCount > 0 else {
            insert(replacement)
            return
        }
        let originalScalars = Array((context() ?? "").unicodeScalars)
        let targetCount = max(0, originalScalars.count - scalarCount)
        var currentCount = originalScalars.count
        var presses = 0
        while currentCount > targetCount, presses < scalarCount * 6 + 8 {
            deleteBackward()
            presses += 1
            let now = (context() ?? "").unicodeScalars.count
            guard now < currentCount else { break }   // no progress; stop safely
            currentCount = now
        }
        var restored = ""
        if currentCount < targetCount {
            // The last press removed a whole cluster spanning the boundary —
            // put back the scalars that belong to the document.
            restored = String(String.UnicodeScalarView(originalScalars[currentCount..<targetCount]))
        }
        insert(restored + replacement)
    }
}
