// HeroPageView.swift
// Jusstalk
//
// First onboarding page - Hero introduction.

import SwiftUI

struct HeroPageView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 20) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: .blue.opacity(0.4), radius: 20, x: 0, y: 10)
                
                Text("Jusstalk")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Transcris tes idées instantanément")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

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
