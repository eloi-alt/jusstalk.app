// CTAPageView.swift
// Cloaky
//
// Fourth onboarding page - Call to action for purchase or trial.

import SwiftUI

struct CTAPageView: View {
    @EnvironmentObject private var storeManager: StoreManager
    
    let onPurchaseComplete: () -> Void
    let onTryFree: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 20) {
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .indigo.opacity(0.4), radius: 20, x: 0, y: 10)
                
                Text("Ta vie privée mérite mieux qu'un compromis")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            PremiumCTASection(
                title: "Débloquez Cloaky",
                subtitle: "Floutez vos images sans limite",
                showsRestore: true,
                onPurchaseSuccess: {
                    onPurchaseComplete()
                }
            )
            .environmentObject(storeManager)
            .frame(maxWidth: 360)
            .padding(.horizontal, 16)
            
            tryForFreeButton
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var tryForFreeButton: some View {
        Button {
            onTryFree()
        } label: {
            HStack {
                Text("Essayer gratuitement (3 photos)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.vertical, 8)
        }
    }
}

#if DEBUG
struct CTAPageView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AnimatedBackground()
            CTAPageView(
                onPurchaseComplete: {},
                onTryFree: {}
            )
            .environmentObject(StoreManager())
        }
    }
}
#endif
