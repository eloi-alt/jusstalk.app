import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)
                
                Text("Last updated: March 18, 2026")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 16)
                
                VStack(alignment: .leading, spacing: 16) {
                    LegalSectionView(
                        title: "Overview",
                        content: "Jusstalk does not collect, store, or share personal data. No account is required to use the app."
                    )
                    
                    Divider()
                    
                    LegalSectionView(
                        title: "Data We Process",
                        content: "Audio recordings are sent to Mistral AI for transcription and deleted immediately. Trial usage counter is stored locally on your device only. In-app purchases are handled entirely by Apple StoreKit."
                    )
                    
                    Divider()
                    
                    LegalSectionView(
                        title: "Third-Party Services",
                        content: "Mistral AI (api.mistral.ai) — for audio transcription\nDeepSeek (api.deepseek.com) — for text formatting on explicit user request\nApple App Store — for purchase verification"
                    )
                    
                    Divider()
                    
                    LegalSectionView(
                        title: "Data We Do NOT Collect",
                        content: "No name, email, or account data\nNo device identifiers or advertising IDs\nNo location data\nNo analytics or crash reporting\nNo cookies or tracking\nNo data sold to third parties"
                    )
                    
                    Divider()
                    
                    LegalSectionView(
                        title: "Microphone Permission",
                        content: "Jusstalk requests microphone access solely to record audio for transcription. This data is not stored beyond the transcription session."
                    )
                    
                    Divider()
                    
                    LegalSectionView(
                        title: "Children",
                        content: "The app is not directed at children under 13."
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
        PrivacyPolicyView()
    }
}
