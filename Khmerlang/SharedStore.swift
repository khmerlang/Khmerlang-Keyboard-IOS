//
//  SharedStore.swift
//  Khmerlang
//
//  Settings and user data shared between the container app and the keyboard
//  extension through the App Group. The iOS counterpart of the Android
//  KeyboardPreferences + the custom-mapping Realm records.
//
//  NOTE: an identical copy lives in Khmerlang-Keyboard-IOS/SharedStore.swift
//  (each target's synchronized folder needs its own file) — keep them in sync.
//  Sharing only works once BOTH targets have the App Groups capability with
//  the group ID below (Signing & Capabilities in Xcode).
//

import Foundation

/// A user-defined romanisation → Khmer word pair (Android's custom=true Ngram).
struct CustomMapping: Codable, Equatable, Identifiable {
    let khmer: String
    let roman: String

    var id: String { khmer + "|" + roman }
}

enum SharedStore {

    /// App Group shared by the container app and the keyboard extension
    /// (must match the App Groups capability on BOTH targets).
    static let appGroupID = "group.com.rathanak.khmerroman"

    static let defaults = UserDefaults(suiteName: appGroupID)

    // Preference keys (named after the Android KeyboardPreferences equivalents).
    private static let romanCorrectionKey = "key_rm_correction_mode"
    private static let englishCorrectionKey = "key_en_correction_mode"
    private static let customMappingsKey = "key_custom_mappings"
    private static let customMappingsVersionKey = "key_custom_mappings_version"

    /// Roman → Khmer suggestions for Latin input (default on).
    static var romanCorrectionEnabled: Bool {
        get { defaults?.object(forKey: romanCorrectionKey) as? Bool ?? true }
        set { defaults?.set(newValue, forKey: romanCorrectionKey) }
    }

    /// English corrections/completions for Latin input (default on).
    static var englishCorrectionEnabled: Bool {
        get { defaults?.object(forKey: englishCorrectionKey) as? Bool ?? true }
        set { defaults?.set(newValue, forKey: englishCorrectionKey) }
    }

    /// User-defined romanisation → Khmer pairs, oldest first.
    static var customMappings: [CustomMapping] {
        get {
            guard let data = defaults?.data(forKey: customMappingsKey),
                  let mappings = try? JSONDecoder().decode([CustomMapping].self, from: data) else {
                return []
            }
            return mappings
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults?.set(data, forKey: customMappingsKey)
            defaults?.set(customMappingsVersion + 1, forKey: customMappingsVersionKey)
        }
    }

    /// Monotonic counter bumped on every mappings edit; the keyboard compares
    /// it against the version its correction trees were built with, and
    /// rebuilds when the user changed the dictionary in the container app.
    static var customMappingsVersion: Int {
        defaults?.integer(forKey: customMappingsVersionKey) ?? 0
    }

    /// Whether the server spell-check feature is available.
    /// Defaults to false so cloud requests are opt-in for public release.
    static var spellCheckEnabled: Bool {
        get { defaults?.object(forKey: spellCheckEnabledKey) as? Bool ?? false }
        set { defaults?.set(newValue, forKey: spellCheckEnabledKey) }
    }
    private static let spellCheckEnabledKey = "key_spell_check_enabled"

    /// Whether the user explicitly granted consent for cloud spell-checking.
    /// Kept separate from the entitlement/feature flag so UI can explain why
    /// spell check is unavailable when either gate is off.
    static var spellCheckConsentGranted: Bool {
        get { defaults?.object(forKey: spellCheckConsentKey) as? Bool ?? false }
        set { defaults?.set(newValue, forKey: spellCheckConsentKey) }
    }
    private static let spellCheckConsentKey = "key_spell_check_consent"
}
