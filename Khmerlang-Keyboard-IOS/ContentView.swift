//
//  ContentView.swift
//  Khmerlang-Keyboard-IOS
//
//  Container app: guides the user through enabling the Khmerlang keyboard and
//  offers a text field to try it out.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("appLanguage") private var appLanguage = "system"
    @State private var tryOutText: String = ""
    @State private var romanEnabled = SharedStore.romanCorrectionEnabled
    @State private var englishEnabled = SharedStore.englishCorrectionEnabled
    @State private var cloudSpellCheckEnabled = SharedStore.spellCheckEnabled
    @State private var cloudSpellCheckConsent = SharedStore.spellCheckConsentGranted

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Khmerlang Keyboard")
                            .font(.title2).bold()
                        Text("A modern Khmer + English keyboard.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Language") {
                    Picker("App language", selection: $appLanguage) {
                        Text("System").tag("system")
                        Text("English").tag("en")
                        Text("ខ្មែរ").tag("km")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Enable the keyboard") {
                    stepRow(1, "Open Settings › General › Keyboard › Keyboards.")
                    stepRow(2, "Tap “Add New Keyboard…” and choose Khmerlang.")
                    stepRow(3, "In any app, tap the 🌐 globe key to switch to Khmerlang.")
                }

                Section("Try it out") {
                    TextField("Type here to test the keyboard…", text: $tryOutText, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section {
                    Toggle("Roman → Khmer suggestions", isOn: $romanEnabled)
                        .onChange(of: romanEnabled) { value in
                            SharedStore.romanCorrectionEnabled = value
                        }
                    Toggle("English suggestions", isOn: $englishEnabled)
                        .onChange(of: englishEnabled) { value in
                            SharedStore.englishCorrectionEnabled = value
                        }
                    NavigationLink {
                        CustomMappingsView()
                    } label: {
                        Label("Custom dictionary", systemImage: "character.book.closed")
                    }
                } header: {
                    Text("Suggestions")
                } footer: {
                    Text("Toggles control what appears when typing with Latin letters. Changes apply the next time the keyboard opens.")
                }

                Section {
                    Toggle("I consent to cloud spell check", isOn: $cloudSpellCheckConsent)
                        .onChange(of: cloudSpellCheckConsent) { value in
                            SharedStore.spellCheckConsentGranted = value
                            if !value {
                                cloudSpellCheckEnabled = false
                                SharedStore.spellCheckEnabled = false
                            }
                        }
                    Toggle("Enable cloud spell check in keyboard", isOn: $cloudSpellCheckEnabled)
                        .disabled(!cloudSpellCheckConsent)
                        .onChange(of: cloudSpellCheckEnabled) { value in
                            if value, !cloudSpellCheckConsent {
                                cloudSpellCheckEnabled = false
                                SharedStore.spellCheckEnabled = false
                            } else {
                                SharedStore.spellCheckEnabled = value
                            }
                        }
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("Privacy policy", systemImage: "lock.doc")
                    }
                } header: {
                    Text("Cloud spell check")
                } footer: {
                    Text("When enabled, typed text before the cursor is sent to Khmerlang servers to return spelling suggestions. This requires Full Access for the keyboard extension.")
                }

                Section("Tips") {
                    Label("Long-press a key to insert its secondary symbol.", systemImage: "hand.tap")
                    Label("Tap ⇄ to switch between Khmer and English.", systemImage: "arrow.left.arrow.right")
                    Label("Tap ១២៣ / ?123 for symbols and numbers.", systemImage: "number")
                }

                Section("About") {
                    Link(destination: URL(string: "https://www.khmerlang.com")!) {
                        Label("khmerlang.com", systemImage: "globe")
                    }
                    Link(destination: URL(string: "https://github.com/khmerlang")!) {
                        Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Link(destination: URL(string: "https://web.facebook.com/khmerlang.official")!) {
                        Label("Facebook", systemImage: "person.2")
                    }
                }
            }
            .navigationTitle("Khmerlang")
        }
    }

    private func stepRow(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline).bold()
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.tint))
            Text(text)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ContentView()
}
