//
//  Khmerlang_Keyboard_IOSApp.swift
//  Khmerlang-Keyboard-IOS
//
//  Created by Sreang Rathanak on 11/7/26.
//

import SwiftUI

@main
struct Khmerlang_Keyboard_IOSApp: App {
    /// "en" / "km" force the app UI language; defaults to Khmer. A stray
    /// "system" value left over from an older app version still falls back
    /// to the device locale rather than an invalid Locale identifier.
    @AppStorage("appLanguage") private var appLanguage = "km"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, appLanguage == "system" ? .current : Locale(identifier: appLanguage))
        }
    }
}
