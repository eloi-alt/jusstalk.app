// PaywallView.swift
// Cloaky
//
// Premium paywall view - shown after trial exhaustion or manual upgrade.

import SwiftUI

struct PaywallView: View {
    @ObservedObject var storeManager: StoreManager
    @ObservedObject var appState: AppState
    
    let context: PaywallContext
    let onPurchaseComplete: () -> Void
    var onDismiss: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AnimatedBackground()
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Spacer(minLength: 20)
                        
                        // App Logo
                        Image("AppLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .indigo.opacity(0.4), radius: 20, x: 0, y: 10)
                        
                        // Contextual Title
                        VStack(spacing: 8) {
                            Text(context.mainTitle)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text(context.subtitle)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        
                        // Features Section
                        featuresSection
                        
                        // CTA Section
                        VStack(spacing: 14) {
                            purchaseButton
                            
                            restoreButton
                            
                            if let error = storeManager.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Text("Paiement sécurisé Apple")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.top, 8)
                            
                            Button {
                                handleDismiss()
                            } label: {
                                Text("Peut-être plus tard")
                                    .font(.footnote)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.top, 8)
                        }
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                    .frame(minHeight: geometry.size.height - geometry.safeAreaInsets.top - geometry.safeAreaInsets.bottom)
                }
            }
        }
        .task {
            if storeManager.mainProduct == nil {
                await storeManager.loadProducts()
            }
        }
        .onChange(of: storeManager.isPremium) { newValue in
            if newValue {
                onPurchaseComplete()
            }
        }
        .onChange(of: storeManager.showSuccessAnimation) { newValue in
            if newValue {
                onPurchaseComplete()
            }
        }
    }
    
    private func handleDismiss() {
        if let customDismiss = onDismiss {
            customDismiss()
        } else {
            dismiss()
        }
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "photo.on.rectangle.angled", text: "Photos illimitées")
            featureRow(icon: "star.fill", text: "Qualité d'export maximale")
            featureRow(icon: "cube.fill", text: "Filtres avancés (pixel, scramble)")
            featureRow(icon: "wifi.slash", text: "100% offline, sans tracking")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.green)
                .frame(width: 24, alignment: .center)
            
            Text(text)
                .font(.subheadline)
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
                if storeManager.isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                    Text("Achat en cours...")
                        .font(.headline)
                } else if let product = storeManager.mainProduct {
                    Text("Payer \(product.displayPrice)")
                        .font(.headline)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                } else if storeManager.isLoadingProducts {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                    Text("Chargement...")
                        .font(.headline)
                } else {
                    Text("Débloquer Cloaky")
                        .font(.headline)
                }
                
                Spacer()
                
                if !storeManager.isPurchasing {
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
            .cornerRadius(16)
            .shadow(color: .indigo.opacity(0.5), radius: 8, y: 4)
        }
        .disabled(storeManager.isPurchasing || storeManager.isLoadingProducts)
        .opacity(storeManager.isPurchasing || storeManager.isLoadingProducts ? 0.8 : 1)
    }
    
    private var restoreButton: some View {
        Button {
            Task {
                await storeManager.restorePurchases()
            }
        } label: {
            HStack(spacing: 6) {
                if storeManager.isRestoring {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.7)))
                        .scaleEffect(0.8)
                    Text("Restauration...")
                } else {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.subheadline)
                    Text("Restaurer mes achats")
                }
            }
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.7))
        }
        .disabled(storeManager.isRestoring)
        .opacity(storeManager.isRestoring ? 0.6 : 1)
    }
}

extension PaywallContext {
    var mainTitle: String {
        switch self {
        case .onboarding:
            return "Version payante"
        case .trialExhausted:
            return "Vous avez utilisé vos\n3 photos gratuites"
        case .manualUpgrade:
            return "Passez à la\nversion payante"
        }
    }
}

#if DEBUG
struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        PaywallView(
            storeManager: StoreManager(),
            appState: AppState(),
            context: .trialExhausted,
            onPurchaseComplete: {}
        )
    }
}
#endif
