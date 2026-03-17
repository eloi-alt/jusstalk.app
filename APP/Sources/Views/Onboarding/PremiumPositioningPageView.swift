// PremiumPositioningPageView.swift
// Jusstalk
//
// Third onboarding page - Premium positioning/value proposition.

import SwiftUI

struct PremiumPositioningPageView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "crown.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .shadow(color: .yellow.opacity(0.4), radius: 15, x: 0, y: 8)
                
                Text("Pourquoi payer ?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 14) {
                    premiumFeatureRow(icon: "infinity", text: "Transcriptions illimitées")
                    premiumFeatureRow(icon: "bolt.fill", text: "Transcription rapide")
                    premiumFeatureRow(icon: "sparkles", text: "IA de mise en forme avancée")
                    premiumFeatureRow(icon: "doc.on.doc", text: "Exporter dans tous les formats")
                }
                .padding(.horizontal, 32)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func premiumFeatureRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.green)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PremiumPositioningPageView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AnimatedBackground()
            PremiumPositioningPageView()
        }
    }
}
#endif
