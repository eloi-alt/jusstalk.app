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
                    NavigationLink("Terms of Service") { TermsOfServiceView() }
                    NavigationLink("Privacy Policy") { PrivacyPolicyView() }
                    NavigationLink("Open Source Licenses") { LicensesView() }
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
                        Text("1.1.0 (1)").foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

import SwiftUI

struct LicensesView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Open Source Licenses")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)
                
                VStack(alignment: .leading, spacing: 16) {
                    LegalSectionView(
                        title: "Voxtral-Mini-Transcribe-2507",
                        content: "License: Apache 2.0\nCopyright: Copyright 2024 Mistral AI"
                    )
                    
                    Divider()
                    
                    LegalSectionView(
                        title: "Swift / SwiftUI",
                        content: "License: Apache 2.0\nCopyright: Copyright 2014–2024 Apple Inc."
                    )
                    
                    Divider()
                    
                    LegalSectionView(
                        title: "Tailwind CSS",
                        content: "License: MIT\nCopyright: Copyright 2020 Tailwind Labs, Inc."
                    )
                    
                    Divider()
                    
                    LegalSectionView(
                        title: "Inter Font",
                        content: "License: SIL Open Font License 1.1\nCopyright: Copyright 2020 The Inter Project Authors"
                    )
                    
                    Divider()
                    
                    LegalSectionView(
                        title: "DeepSeek API",
                        content: "DeepSeek API is used under DeepSeek's commercial API terms. See https://platform.deepseek.com"
                    )
                }
            }
            .padding(20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}
