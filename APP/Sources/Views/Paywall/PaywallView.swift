// PaywallView.swift
// Jusstalk
//
// Paywall view presented when trial is exhausted or user tries to transcribe without premium.

import SwiftUI
import UIKit

struct PaywallView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    
    let onPurchaseComplete: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                headerSection
                
                featuresSection
                
                PremiumCTASectionJusstalk(
                    title: "Débloquer Jusstalk",
                    subtitle: "Transcription illimitée",
                    showsRestore: true,
                    onPurchaseSuccess: {
                        onPurchaseComplete()
                        dismiss()
                    }
                )
                .environmentObject(storeManager)
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .padding(.top, 24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
            
            Text("Essayez la version complète")
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
            
            Text("Votre essai gratuit est terminé.\nDébloquez Jusstalk pour transcrire sans limite.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Inclus dans la version complète")
                .font(.headline)
                .padding(.horizontal, 24)
            
            VStack(alignment: .leading, spacing: 10) {
                featureRow(icon: "infinity", text: "Transcriptions illimitées")
                featureRow(icon: "bolt.fill", text: "Transcription rapide")
                featureRow(icon: "sparkles", text: "IA de mise en forme avancée")
                featureRow(icon: "doc.on.doc", text: "Exporter dans tous les formats")
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 24)
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.green)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        PaywallView(onPurchaseComplete: {})
            .environmentObject(StoreManager())
    }
}
#endif
