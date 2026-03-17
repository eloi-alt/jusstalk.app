// DemoPageView.swift
// Cloaky
//
// Second onboarding page - Demo feature showcase.

import SwiftUI

struct DemoPageView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            detectionDemoView
            
            VStack(alignment: .leading, spacing: 20) {
                featureRow(
                    icon: "face.dashed",
                    title: "Détecte visages, mains, textes sensibles",
                    description: "Technologie Apple Vision"
                )
                
                featureRow(
                    icon: "exclamationmark.triangle",
                    title: "Supprime métadonnées (EXIF, GPS...)",
                    description: "Zéro donnée personnelle"
                )
                
                featureRow(
                    icon: "wifi.slash",
                    title: "Fonctionne totalement hors-ligne",
                    description: "Pas de connexion requise"
                )
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var detectionDemoView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.3))
                .frame(height: 180)
            
            HStack(spacing: 20) {
                demoImageView(icon: "person.fill", label: "Visages")
                demoImageView(icon: "hand.raised.fill", label: "Mains")
                demoImageView(icon: "textformat", label: "Textes")
            }
        }
        .padding(.horizontal, 24)
    }
    
    private func demoImageView(icon: String, label: String) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.3))
                    .frame(width: 70, height: 70)
                
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.indigo)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

#if DEBUG
struct DemoPageView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AnimatedBackground()
            DemoPageView()
        }
    }
}
#endif
