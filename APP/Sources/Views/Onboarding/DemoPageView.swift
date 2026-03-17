// DemoPageView.swift
// Jusstalk
//
// Second onboarding page - Demo/How it works.

import SwiftUI

struct DemoPageView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "mic.fill.circle")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .shadow(color: .blue.opacity(0.4), radius: 15, x: 0, y: 8)
                
                Text("Comment ça marche ?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 16) {
                    demoStep(number: 1, text: "Enregistre ta voix")
                    demoStep(number: 2, text: "L'IA adapte le texte automatiquement")
                    demoStep(number: 3, text: "Copie ou partage ton texte")
                }
                .padding(.horizontal, 32)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func demoStep(number: Int, text: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 36)
                Text("\(number)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(text)
                .font(.system(size: 17))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
        }
    }
}

// MARK: - Preview

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
