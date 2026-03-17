import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultExportFormat") private var defaultFormat = "none"

    private let exportOptions: [String] = ["none"] + ExportFormat.allCases.map { $0.rawValue }

    var body: some View {
        NavigationView {
            List {
                Section("EXPORT PREFERENCES") {
                    Picker("Default Format", selection: $defaultFormat) {
                        Text("Ask every time").tag("none")
                        ForEach(ExportFormat.allCases, id: \.rawValue) { format in
                            Text(format.rawValue).tag(format.rawValue)
                        }
                    }
                }
                Section("LEGAL") {
                    NavigationLink("Terms of Service") { LegalDocView(title: "Terms", content: LegalContent.terms) }
                    NavigationLink("Privacy Policy") { LegalDocView(title: "Privacy", content: LegalContent.privacy) }
                    NavigationLink("Licenses") { LegalDocView(title: "Licenses", content: LegalContent.licenses) }
                }
                Section("SOCIAL") {
                    Button {
                        if let url = URL(string: "https://x.com/lxucan") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Text("Follow @lxucan on X")
                            Spacer()
                            Image(systemName: "arrow.up.forward").foregroundColor(.secondary)
                        }
                    }
                }
                Section("ABOUT") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (1)").foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Close") { dismiss() } } }
        }
    }
}

struct LegalDocView: View {
    let title: String
    let content: String
    var body: some View {
        ScrollView {
            Text(content).font(.system(size: 14)).padding()
        }.navigationTitle(title)
    }
}
