// PaywallView.swift
// Jusstalk
//
// Simple paywall shown after trial is exhausted.

import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    
    let onPurchaseComplete: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                
                VStack(spacing: 20) {
                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    Text("Essayez la version complète")
                        .font(.system(size: 22, weight: .bold))
                        .multilineTextAlignment(.center)
                    
                    Text("Votre essai gratuit est terminé.\nDébloquez Jusstalk pour transcrire sans limite.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                purchaseSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
            .padding(.top, 24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            if storeManager.mainProduct == nil && !storeManager.isLoadingProducts {
                await storeManager.loadProducts()
            }
        }
        .onChange(of: storeManager.isPremium) { newValue in
            if newValue {
                onPurchaseComplete()
                dismiss()
            }
        }
    }
    
    private var purchaseSection: some View {
        VStack(spacing: 16) {
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
                .foregroundColor(.secondary)
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
                    Text("Débloquer Jusstalk")
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
    
    private var restoreButton: some View {
        Button {
            Task {
                await storeManager.restorePurchases()
            }
        } label: {
            HStack(spacing: 8) {
                if storeManager.isRestoring {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.subheadline)
                }
                Text(storeManager.isRestoring ? "Restauration..." : "Restaurer mes achats")
                    .font(.subheadline)
            }
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .disabled(storeManager.isRestoring)
        .opacity(storeManager.isRestoring ? 0.6 : 1)
    }
}

// MARK: - Preview

#if DEBUG
struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        PaywallView(onPurchaseComplete: {})
            .environmentObject(StoreManager())
    }
}
#endif
