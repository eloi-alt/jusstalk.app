// PremiumCTASection.swift
// Cloaky
//
// Shared CTA component for purchase flow.
// Used in onboarding and paywall post-trial.

import SwiftUI

struct PremiumCTASection: View {
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
            // Header
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
            
            // Features
            featuresSection
                .padding(.top, 4)
            
            // Purchase Button
            purchaseButton
            
            // Restore Button
            if showsRestore {
                restoreButton
            }
            
            // Error Message
            if let error = storeManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Security Text
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
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            featureRow(icon: "photo.on.rectangle.angled", text: "Photos illimitées")
            featureRow(icon: "star.fill", text: "Qualité d'export maximale")
            featureRow(icon: "cube.fill", text: "Filtres avancés (pixel, scramble)")
            featureRow(icon: "wifi.slash", text: "100% offline, sans tracking")
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
    
    // MARK: - Purchase Button
    
    private var purchaseButton: some View {
        Button {
            Task {
                await storeManager.purchaseMainProduct()
            }
        } label: {
            HStack(spacing: 12) {
                // Left side - text or loading
                HStack(spacing: 8) {
                    if storeManager.isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    }
                    
                    buttonText
                }
                
                Spacer()
                
                // Right side - lock icon (always visible when not purchasing)
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
                    colors: [.indigo, .indigo.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .shadow(color: .indigo.opacity(0.5), radius: 8, y: 4)
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
            Text("Débloquer Cloaky")
                .font(.headline)
        }
    }
    
    // MARK: - Restore Button
    
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
struct PremiumCTASection_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            PremiumCTASection(
                title: "Débloquez Cloaky",
                subtitle: "Floutez vos images sans limite",
                showsRestore: true
            )
            .environmentObject(StoreManager())
            .padding()
        }
    }
}
#endif
