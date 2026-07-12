//
//  ContentView.swift
//  Khmerlang-Keyboard-IOS
//
//  Container app: guides the user through enabling the Khmerlang keyboard and
//  offers a text field to try it out.
//

import SwiftUI

struct ContentView: View {
    @State private var tryOutText: String = ""
    @State private var romanEnabled = SharedStore.romanCorrectionEnabled
    @State private var englishEnabled = SharedStore.englishCorrectionEnabled

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
                        .onChange(of: romanEnabled) { _, value in
                            SharedStore.romanCorrectionEnabled = value
                        }
                    Toggle("English suggestions", isOn: $englishEnabled)
                        .onChange(of: englishEnabled) { _, value in
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

    private func stepRow(_ number: Int, _ text: String) -> some View {
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
