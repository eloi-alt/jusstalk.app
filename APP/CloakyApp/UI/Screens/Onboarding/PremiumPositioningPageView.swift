// PremiumPositioningPageView.swift
// Cloaky
//
// Third onboarding page - Premium positioning and privacy claims.

import SwiftUI

struct PremiumPositioningPageView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 60))
                    .foregroundColor(.indigo)
                
                Text("100% Privé, 100% Local")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                premiumFeatureRow(text: "Zéro tracking, zéro analytics, zéro serveur")
                premiumFeatureRow(text: "Construit uniquement avec les frameworks Apple (Vision, Core Image, SwiftUI)")
                premiumFeatureRow(text: "Ton téléphone seulement — pas de cloud, pas de tiers")
            }
            .padding(.horizontal, 24)
            
            comparisonView
                .padding(.horizontal, 24)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func premiumFeatureRow(text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.body)
            
            Text(text)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
        }
    }
    
    private var comparisonView: some View {
        VStack(spacing: 12) {
            Text("Sans Cloakyy vs Avec Cloakyy")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 16) {
                comparisonBox(
                    title: "Sans Cloakyy",
                    items: ["Métadonnées intactes", "Visages identifiables", "Données GPS"],
                    isPro: false
                )
                
                Image(systemName: "arrow.right")
                    .font(.title2)
                    .foregroundColor(.indigo)
                
                comparisonBox(
                    title: "Avec Cloakyy",
                    items: ["Métadonnées supprimées", "Visages obfusqués", "Zéro trace"],
                    isPro: true
                )
            }
        }
    }
    
    private func comparisonBox(title: String, items: [String], isPro: Bool) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(isPro ? .green : .white.opacity(0.7))
            
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isPro ? Color.green.opacity(0.15) : Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isPro ? Color.green.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

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
