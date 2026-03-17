// SettingsView.swift
// Cloaky
//
// Settings screen with About (T&C, Privacy, Licenses, Version)
// and More (Share, Follow on X) sections.

import SwiftUI
import UIKit

// MARK: - SettingsView

struct SettingsView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    /// Current app version from bundle
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.3"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "2"
        return "\(version) (\(build))"
    }
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - About
                Section {
                    NavigationLink {
                        LegalTextView(
                            title: String(localized: "settings.terms", defaultValue: "Terms & Conditions"),
                            text: termsAndConditionsText
                        )
                    } label: {
                        Label(String(localized: "settings.terms", defaultValue: "Terms & Conditions"), systemImage: "doc.text.fill")
                    }
                    
                    NavigationLink {
                        LegalTextView(
                            title: String(localized: "settings.privacy", defaultValue: "Privacy Policy"),
                            text: privacyPolicyText
                        )
                    } label: {
                        Label(String(localized: "settings.privacy", defaultValue: "Privacy Policy"), systemImage: "lock.fill")
                    }
                    
                    NavigationLink {
                        LegalTextView(
                            title: String(localized: "settings.licenses", defaultValue: "Licenses"),
                            text: licensesText
                        )
                    } label: {
                        Label(String(localized: "settings.licenses", defaultValue: "Licenses"), systemImage: "doc.plaintext")
                    }
                    
                    HStack {
                        Label(String(localized: "settings.version", defaultValue: "Version"), systemImage: "info.circle")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text(String(localized: "settings.about", defaultValue: "About"))
                }
                
                // MARK: - More
                Section {
                    Button {
                        openSupport()
                    } label: {
                        Label {
                            Text(String(localized: "settings.support", defaultValue: "Support"))
                        } icon: {
                            Image(systemName: "questionmark.circle")
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button {
                        shareApp()
                    } label: {
                        Label {
                            Text(String(localized: "settings.share", defaultValue: "Share the app (support us 🚀)"))
                        } icon: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button {
                        openTwitter()
                    } label: {
                        Label {
                            Text(String(localized: "settings.follow.x", defaultValue: "Follow us on X"))
                        } icon: {
                            Image(systemName: "link")
                        }
                    }
                    .foregroundColor(.primary)
                } header: {
                    Text(String(localized: "settings.more", defaultValue: "More"))
                }
                
                // MARK: - Footer
                Section {
                    EmptyView()
                } footer: {
                    HStack {
                        Spacer()
                        Text(String(localized: "settings.footer", defaultValue: "Made with ❤️ in 🇫🇷"))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.top, 16)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(String(localized: "settings.title", defaultValue: "Settings"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "settings.done", defaultValue: "Done")) {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    
    // MARK: - Actions
    
    private func shareApp() {
        let text = String(localized: "share.text", defaultValue: "Check out Cloakyy - Protect your privacy by removing biometric data from your photos before sharing! 🛡️")
        let url = URL(string: "https://apps.apple.com/app/id6759176071")!
        
        let activityVC = UIActivityViewController(
            activityItems: [text, url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            // Find the topmost presented controller
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            
            // iPad needs sourceView for popover
            activityVC.popoverPresentationController?.sourceView = topVC.view
            activityVC.popoverPresentationController?.sourceRect = CGRect(
                x: topVC.view.bounds.midX,
                y: topVC.view.bounds.midY,
                width: 0,
                height: 0
            )
            
            topVC.present(activityVC, animated: true)
        }
    }
    
    private func openTwitter() {
        // Try X app first, fall back to browser
        let xAppURL = URL(string: "twitter://user?screen_name=lxucan")!
        let webURL = URL(string: "https://x.com/lxucan")!
        
        if UIApplication.shared.canOpenURL(xAppURL) {
            UIApplication.shared.open(xAppURL)
        } else {
            UIApplication.shared.open(webURL)
        }
    }
    
    private func openSupport() {
        if let url = URL(string: "https://lxucan.com/cloakyy/") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Legal Text View

struct LegalTextView: View {
    let title: String
    let text: String
    
    var body: some View {
        ScrollView {
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
                .padding(20)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
}



