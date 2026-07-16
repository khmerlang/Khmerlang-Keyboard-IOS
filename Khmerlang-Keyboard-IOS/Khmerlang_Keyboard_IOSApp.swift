//
//  Khmerlang_Keyboard_IOSApp.swift
//  Khmerlang-Keyboard-IOS
//
//  Created by Sreang Rathanak on 11/7/26.
//

import SwiftUI

@main
struct Khmerlang_Keyboard_IOSApp: App {
    /// "system" follows the device language; "en" / "km" force the app UI language.
    @AppStorage("appLanguage") private var appLanguage = "system"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, appLanguage == "system" ? .current : Locale(identifier: appLanguage))
        }
    }
}
