//
//  CustomMappingsView.swift
//  Khmerlang-Keyboard-IOS
//
//  User-defined romanisation → Khmer pairs (the Android CustomMapping +
//  RomanDialog feature). Stored in the App Group so the keyboard extension
//  feeds them into its correction trees on next launch.
//

import SwiftUI

struct CustomMappingsView: View {
    @State private var mappings = SharedStore.customMappings
    @State private var khmerText = ""
    @State private var romanText = ""

    /// Khmer field: Khmer block scalars only (plus ? ! and zero-width space),
    /// matching the Android RomanDialog validation.
    private var khmerValid: Bool {
        !khmerText.isEmpty && khmerText.unicodeScalars.allSatisfy {
            (0x1780...0x17FF).contains($0.value) || $0 == "?" || $0 == "!" || $0.value == 0x200B
        }
    }

    /// Roman field: ASCII letters only.
    private var romanValid: Bool {
        !romanText.isEmpty && romanText.allSatisfy { $0.isASCII && $0.isLetter }
    }

    private var isDuplicate: Bool {
        let roman = romanText.lowercased()
        return mappings.contains { $0.khmer == khmerText && $0.roman == roman }
    }

    var body: some View {
        List {
            Section {
                TextField("ពាក្យខ្មែរ (Khmer word)", text: $khmerText)
                TextField("Romanization (e.g. songsa)", text: $romanText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    addMapping()
                } label: {
                    Label("Add mapping", systemImage: "plus.circle.fill")
                }
                .disabled(!khmerValid || !romanValid || isDuplicate)
            } header: {
                Text("New mapping")
            } footer: {
                Text("Type the romanization on the English keyboard to get the Khmer word as a suggestion. Changes apply the next time the keyboard opens.")
            }

            if !mappings.isEmpty {
                Section("My mappings") {
                    ForEach(mappings.reversed()) { mapping in
                        HStack {
                            Text(mapping.khmer)
                            Spacer()
                            Text(mapping.roman)
                                .foregroundStyle(.secondary)
                                .font(.callout.monospaced())
                        }
                    }
                    .onDelete(perform: deleteReversed)
                }
            }
        }
        .navigationTitle("Custom Dictionary")
    }

    private func addMapping() {
        mappings.append(CustomMapping(khmer: khmerText, roman: romanText.lowercased()))
        SharedStore.customMappings = mappings
        khmerText = ""
        romanText = ""
    }

    /// The list displays newest-first, so delete offsets must be flipped back.
    private func deleteReversed(at offsets: IndexSet) {
        let count = mappings.count
        let original = IndexSet(offsets.map { count - 1 - $0 })
        mappings.remove(atOffsets: original)
        SharedStore.customMappings = mappings
    }
}

#Preview {
    NavigationStack {
        CustomMappingsView()
    }
}
