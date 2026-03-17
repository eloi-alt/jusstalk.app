// HeroPageView.swift
// Cloaky
//
// First onboarding page - Hero section with app logo and tagline.

import SwiftUI

struct HeroPageView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(color: .indigo.opacity(0.4), radius: 30, x: 0, y: 15)
            
            VStack(spacing: 16) {
                Text("Tes photos, sans traces")
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Tout est traité en local, aucune donnée ne quitte ton iPhone.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
struct HeroPageView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AnimatedBackground()
            HeroPageView()
        }
    }
}
#endif
