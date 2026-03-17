// StoreManager.swift
// Jusstalk
//
// Secure StoreKit 2 implementation for non-consumable in-app purchases.
// Uses Transaction.currentEntitlements for secure verification.
// Single source of truth for all purchase flows.

import StoreKit
import SwiftUI

// MARK: - Product Identifier

enum ProductIdentifier: String, CaseIterable {
    case unlockPro = "com.jusstalk.unlock_pro"
    
    var displayName: String {
        switch self {
        case .unlockPro:
            return "Débloquer Jusstalk"
        }
    }
}

// MARK: - StoreError

enum StoreError: LocalizedError {
    case productsNotFound
    case purchaseFailed(Error)
    case verificationFailed
    case restoreFailed
    case productNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .productsNotFound:
            return "Produits non disponibles"
        case .purchaseFailed(let error):
            return "Achat échoué: \(error.localizedDescription)"
        case .verificationFailed:
            return "Vérification sécurisée échouée"
        case .restoreFailed:
            return "Restauration échouée"
        case .productNotAvailable:
            return "Produit indisponible. Réessayez dans quelques instants."
        }
    }
}

// MARK: - StoreManager

@MainActor
final class StoreManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var products: [Product] = []
    @Published private(set) var isPurchased: Bool = false
    @Published private(set) var isLoadingProducts: Bool = false
    @Published private(set) var isPurchasing: Bool = false
    @Published private(set) var isRestoring: Bool = false
    @Published var errorMessage: String?
    @Published var showSuccessAnimation: Bool = false
    
    // MARK: - Convenience Aliases
    
    var mainProduct: Product? {
        products.first
    }
    
    var isPremium: Bool {
        isPurchased
    }
    
    var isLoading: Bool {
        isLoadingProducts
    }
    
    // MARK: - Private Properties
    
    private var updateListenerTask: Task<Void, Error>?
    
    #if DEBUG
    private func log(_ message: String) {
        print("[StoreManager] \(message)")
    }
    #else
    private func log(_ message: String) {}
    #endif
    
    // MARK: - Initialization
    
    init() {
        startListeningForTransactions()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Loads available products from App Store
    func loadProducts() async {
        log("loadProducts() started")
        isLoadingProducts = true
        errorMessage = nil
        
        do {
            let productIDs = ProductIdentifier.allCases.map { $0.rawValue }
            log("Requesting products for IDs: \(productIDs)")
            
            var fetchedProducts = try await Product.products(for: productIDs)
            log("Fetched \(fetchedProducts.count) products")
            
            if fetchedProducts.isEmpty {
                log("No products fetched, retrying after delay...")
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                fetchedProducts = try await Product.products(for: productIDs)
                log("Retry fetched \(fetchedProducts.count) products")
            }
            
            for product in fetchedProducts {
                log("Product found: \(product.id), price: \(product.displayPrice)")
            }
            
            // Sort by price
            products = fetchedProducts.sorted { $0.price < $1.price }
            
            if mainProduct == nil {
                log("WARNING: mainProduct is nil after fetch!")
                errorMessage = "Produit indisponible. Vérifiez la configuration StoreKit."
            } else {
                log("mainProduct loaded: \(mainProduct!.id)")
            }
            
            // Check if already purchased
            await checkCurrentEntitlements()
            log("isPurchased: \(isPurchased)")
            
        } catch {
            log("ERROR loading products: \(error.localizedDescription)")
            errorMessage = "Impossible de charger les produits: \(error.localizedDescription)"
        }
        
        isLoadingProducts = false
        log("loadProducts() finished, products count: \(products.count)")
    }
    
    /// Unified purchase method for the main product
    func purchaseMainProduct() async {
        guard !isPurchasing else { return }
        
        isPurchasing = true
        errorMessage = nil
        
        // Load products if not available
        if mainProduct == nil {
            await loadProducts()
        }
        
        guard let product = mainProduct else {
            errorMessage = StoreError.productNotAvailable.localizedDescription
            isPurchasing = false
            return
        }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                
                isPurchased = true
                showSuccessAnimation = true
                isPurchasing = false
                log("Purchase successful! isPurchased: \(isPurchased)")
                
            case .userCancelled:
                isPurchasing = false
                
            case .pending:
                isPurchasing = false
                
            @unknown default:
                isPurchasing = false
            }
            
        } catch {
            errorMessage = "Impossible de finaliser l'achat."
            isPurchasing = false
        }
    }
    
    /// Initiates purchase flow for a specific product (legacy support)
    func purchase(_ product: Product) async -> Bool {
        guard !isPurchasing else { return false }
        
        isPurchasing = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                isPurchased = true
                showSuccessAnimation = true
                isPurchasing = false
                log("Purchase successful via legacy method")
                return true
                
            case .userCancelled:
                isPurchasing = false
                return false
                
            case .pending:
                isPurchasing = false
                return false
                
            @unknown default:
                isPurchasing = false
                return false
            }
            
        } catch {
            errorMessage = StoreError.purchaseFailed(error).localizedDescription
            isPurchasing = false
            return false
        }
    }
    
    /// Restores previous purchases using AppStore.sync()
    func restorePurchases() async {
        isRestoring = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await checkCurrentEntitlements()
            
            if isPurchased {
                showSuccessAnimation = true
            } else {
                errorMessage = "Aucun achat trouvé"
            }
            
        } catch {
            errorMessage = "Restauration échouée: \(error.localizedDescription)"
        }
        
        isRestoring = false
    }
    
    /// Refresh entitlements from StoreKit
    func refreshEntitlements() async {
        await checkCurrentEntitlements()
    }
    
    /// Checks current entitlements to verify purchase status
    func checkCurrentEntitlements() async {
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if ProductIdentifier(rawValue: transaction.productID) != nil {
                    if transaction.revocationDate == nil {
                        if let expirationDate = transaction.expirationDate {
                            if expirationDate > Date() {
                                isPurchased = true
                                return
                            }
                        } else {
                            isPurchased = true
                            return
                        }
                    }
                }
            case .unverified:
                continue
            }
        }
        
        isPurchased = false
    }
    
    // MARK: - Private Methods
    
    /// Starts listening for transactions updates
    private func startListeningForTransactions() {
        updateListenerTask = Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }
                
                switch result {
                case .verified(let transaction):
                    if ProductIdentifier(rawValue: transaction.productID) != nil {
                        await transaction.finish()
                        
                        await MainActor.run {
                            if let revocationDate = transaction.revocationDate, revocationDate <= Date() {
                                self.isPurchased = false
                            } else {
                                self.isPurchased = true
                                self.showSuccessAnimation = true
                            }
                        }
                    }
                case .unverified:
                    continue
                }
            }
        }
    }
    
    /// Verifies StoreKit transaction cryptographically
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Product Extension

extension Product {
    var displayPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: price as NSDecimalNumber) ?? "\(price)"
    }
    
    var displayName: String {
        switch id {
        case ProductIdentifier.unlockPro.rawValue:
            return "Débloquer Jusstalk"
        default:
            return "Jusstalk"
        }
    }
}
