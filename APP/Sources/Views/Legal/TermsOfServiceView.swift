import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Terms of Use")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)
                
                Text("Last updated: March 18, 2026")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 16)
                
                VStack(alignment: .leading, spacing: 16) {
                    LegalSectionView(
                        title: "Acceptance",
                        content: "By downloading or using Jusstalk, you agree to these Terms. If you disagree, do not use the app."
                    )
                    
                    Divider()
                    
                    LegalSectionView(
                        title: "License",
                        content: "Jusstalk grants you a limited, non-exclusive, non-transferable, revocable license to use the app on Apple devices you own, subject to these Terms and Apple's Usage Rules."
                    )
                    
                    Divider()
                    
                    LegalSectionView(
                        title: "In-App Purchases",
                        content: "The \"Unlock Jusstalk\" purchase (com.jusstalk.unlock_pro) is a non-consumable one-time payment. All purchases are processed by Apple and subject to Apple's refund policy. We do not issue refunds directly — contact Apple Support for refund requests. Purchases are linked to your Apple ID and transferable across your personal devices via Family Sharing if enabled."
                    )
                    
                    Divider()
                    
                    LegalSectionView(
                        title: "Acceptable Use",
                        content: "You agree NOT to:\n• Reverse engineer, decompile, or attempt to extract source code from the app\n• Use the app to record conversations without all parties' consent\n• Use the app for illegal purposes"
                    )
                    
                    Divider()
                    
                    LegalSectionView(
                        title: "AI Services Disclaimer",
                        content: "Transcription accuracy is not guaranteed. DeepSeek and Mistral AI outputs may contain errors. You are responsible for verifying transcription content before relying on it."
                    )
                    
                    Divider()
                    
                    LegalSectionView(
                        title: "Intellectual Property",
                        content: "The Jusstalk name, logo, and app design are proprietary. Transcriptions you create belong to you."
                    )
                    
                    Divider()
                    
                    LegalSectionView(
                        title: "Disclaimer of Warranties",
                        content: "THE APP IS PROVIDED \"AS IS\" WITHOUT WARRANTIES OF ANY KIND. WE DO NOT WARRANT THAT THE APP WILL BE ERROR-FREE OR UNINTERRUPTED."
                    )
                    
                    Divider()
                    
                    LegalSectionView(
                        title: "Limitation of Liability",
                        content: "TO THE MAXIMUM EXTENT PERMITTED BY LAW, OUR LIABILITY IS LIMITED TO THE AMOUNT YOU PAID FOR THE APP."
                    )
                    
                    Divider()
                    
                    LegalSectionView(
                        title: "Governing Law",
                        content: "These terms are governed by applicable law. Disputes will be resolved in competent courts."
                    )
                    
                    Divider()
                    
                    LegalSectionView(
                        title: "Apple as Third-Party Beneficiary",
                        content: "Apple is a third-party beneficiary of these Terms and may enforce them against you."
                    )
                    
                    Divider()
                    
                    LegalSectionView(
                        title: "Contact",
                        content: "Twitter: @lxucan"
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

#Preview {
    NavigationView {
        TermsOfServiceView()
    }
}
