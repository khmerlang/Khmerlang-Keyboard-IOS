import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Section {
                Text("Effective date: July 12, 2026")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Khmerlang Keyboard is designed to process typing locally on your device whenever possible. Cloud spell check is optional and disabled by default.")
            } header: {
                Text("Khmerlang Privacy Policy")
            }

            Section("What we collect") {
                bullet("Keyboard input is processed on-device for local suggestions and corrections.")
                bullet("If you enable cloud spell check, text before your cursor is sent to Khmerlang servers to return spelling suggestions.")
                bullet("If you pick a cloud suggestion, we may send the original word and selected suggestion to improve ranking quality.")
            }

            Section("What we do not collect") {
                bullet("We do not require account sign-in to use the keyboard.")
                bullet("Cloud spell check is not active unless you explicitly consent and enable it in the app.")
                bullet("If cloud spell check is disabled, typed text is not sent to Khmerlang servers.")
            }

            Section("Permissions") {
                bullet("Full Access is required only for cloud spell-check network requests.")
                bullet("Without Full Access, cloud spell check cannot run and the keyboard continues with local features.")
            }

            Section("Data use and retention") {
                bullet("Cloud spell-check requests are used to generate spelling suggestions.")
                bullet("Selection feedback may be used to improve suggestion ranking.")
                bullet("We retain only the minimum operational data needed to run and improve the service.")
            }

            Section("Security") {
                bullet("Network communication uses HTTPS.")
                bullet("We apply reasonable safeguards to protect data in transit and at rest.")
            }

            Section("Your choices") {
                bullet("You can disable cloud spell check at any time in this app.")
                bullet("You can revoke keyboard Full Access in iOS Settings at any time.")
            }

            Section("Contact") {
                Link(destination: URL(string: "https://www.khmerlang.com/privacy")!) {
                    Label("Hosted privacy policy page", systemImage: "globe")
                }
                Link(destination: URL(string: "mailto:privacy@khmerlang.com")!) {
                    Label("privacy@khmerlang.com", systemImage: "envelope")
                }
            }
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bullet(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
        .padding(.vertical, 1)
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
