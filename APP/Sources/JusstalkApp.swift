// JusstalkApp.swift
// Jusstalk
//
// App entry point. Initializes shared state and presents the main content view.

import SwiftUI
import StoreKit

@main
struct JusstalkApp: App {
    
    @StateObject private var appState = JusstalkAppState()
    @StateObject private var storeManager = StoreManager()
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(storeManager)
                .preferredColorScheme(nil)
                .task {
                    #if DEBUG
                    print("[JusstalkApp] Loading products at launch...")
                    #endif
                    await storeManager.loadProducts()
                    await storeManager.refreshEntitlements()
                    #if DEBUG
                    print("[JusstalkApp] Products loaded: \(storeManager.products.count), mainProduct: \(storeManager.mainProduct?.id ?? "nil")")
                    #endif
                }
                .onReceive(networkMonitor.$isConnected) { isConnected in
                    if isConnected {
                        Task {
                            await OfflineQueueProcessor.shared.processQueue()
                        }
                    }
                }
                .task {
                    if networkMonitor.isConnected {
                        await OfflineQueueProcessor.shared.processQueue()
                    }
                }
        }
    }
}
