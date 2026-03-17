// CTAPageJusstalkView.swift
// Jusstalk
//
// Fourth onboarding page - Call to action for purchase or trial.

import SwiftUI

struct CTAPageJusstalkView: View {
    @EnvironmentObject private var storeManager: StoreManager
    
    let onPurchaseComplete: () -> Void
    let onTryFree: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 20) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .blue.opacity(0.4), radius: 20, x: 0, y: 10)
                
                Text("Débloque tout le potentiel")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            PremiumCTASectionJusstalk(
                title: "Débloquer Jusstalk",
                subtitle: "Transcription illimitée",
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
                Text("Essayer gratuitement (3 transcriptions)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - PremiumCTASectionJusstalk

struct PremiumCTASectionJusstalk: View {
    @EnvironmentObject var storeManager: StoreManager
    
    let title: String
    let subtitle: String?
    let showsRestore: Bool
    var onPurchaseSuccess: (() -> Void)?
    
    init(
        title: String,
        subtitle: String? = nil,
        showsRestore: Bool = true,
        onPurchaseSuccess: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showsRestore = showsRestore
        self.onPurchaseSuccess = onPurchaseSuccess
    }
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
            
            featuresSection
                .padding(.top, 4)
            
            purchaseButton
            
            if showsRestore {
                restoreButton
            }
            
            if let error = storeManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Text("Paiement sécurisé Apple")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
        }
        .task {
            if storeManager.mainProduct == nil && !storeManager.isLoadingProducts {
                await storeManager.loadProducts()
            }
        }
        .onChange(of: storeManager.isPremium) { newValue in
            if newValue, let callback = onPurchaseSuccess {
                callback()
            }
        }
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            featureRow(icon: "infinity", text: "Transcriptions illimitées")
            featureRow(icon: "bolt.fill", text: "Transcription rapide")
            featureRow(icon: "sparkles", text: "IA de mise en forme avancée")
            featureRow(icon: "doc.on.doc", text: "Exporter dans tous les formats")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.green)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
        }
    }
    
    private var purchaseButton: some View {
        Button {
            Task {
                await storeManager.purchaseMainProduct()
            }
        } label: {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    if storeManager.isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    }
                    
                    buttonText
                }
                
                Spacer()
                
                if storeManager.isPurchasing {
                    EmptyView()
                } else {
                    Image(systemName: "lock.fill")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.blue, .blue.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .shadow(color: .blue.opacity(0.5), radius: 8, y: 4)
        }
        .disabled(storeManager.isPurchasing || storeManager.isLoadingProducts)
        .opacity(storeManager.isPurchasing || storeManager.isLoadingProducts ? 0.8 : 1)
    }
    
    @ViewBuilder
    private var buttonText: some View {
        if storeManager.isPurchasing {
            Text("Achat en cours...")
                .font(.headline)
        } else if let product = storeManager.mainProduct {
            Text("Payer \(product.displayPrice)")
                .font(.headline)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        } else if storeManager.isLoadingProducts {
            HStack(spacing: 6) {
                Text("Chargement")
                Text("...")
            }
            .font(.headline)
        } else {
            Text("Débloquer Jusstalk")
                .font(.headline)
        }
    }
    
    private var restoreButton: some View {
        Button {
            Task {
                await storeManager.restorePurchases()
            }
        } label: {
            HStack(spacing: 8) {
                if storeManager.isRestoring {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.7)))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.subheadline)
                }
                Text(storeManager.isRestoring ? "Restauration..." : "Restaurer mes achats")
                    .font(.subheadline)
            }
            .foregroundColor(.white.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .disabled(storeManager.isRestoring)
        .opacity(storeManager.isRestoring ? 0.6 : 1)
    }
}

// MARK: - Preview

#if DEBUG
struct CTAPageJusstalkView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AnimatedBackground()
            CTAPageJusstalkView(
                onPurchaseComplete: {},
                onTryFree: {}
            )
            .environmentObject(StoreManager())
        }
    }
}
#endif
