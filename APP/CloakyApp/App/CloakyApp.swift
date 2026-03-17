// CloakApp.swift
// Cloaky
//
// App entry point. Initializes shared state and presents the main content view.

import SwiftUI
import UIKit
import CloudKit
import StoreKit

// MARK: - CloakyApp

@main
struct CloakyApp: App {
    
    @StateObject private var appState = AppState()
    @StateObject private var storeManager = StoreManager()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(storeManager)
                .preferredColorScheme(nil)
                .task {
                    #if DEBUG
                    print("[CloakyApp] Loading products at launch...")
                    #endif
                    await storeManager.loadProducts()
                    await storeManager.refreshEntitlements()
                    #if DEBUG
                    print("[CloakyApp] Products loaded: \(storeManager.products.count), mainProduct: \(storeManager.mainProduct?.id ?? "nil")")
                    #endif
                }
                .onAppear {
                    NSUbiquitousKeyValueStore.default.synchronize()
                    NotificationCenter.default.addObserver(
                        forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                        object: NSUbiquitousKeyValueStore.default,
                        queue: .main
                    ) { _ in
                        NSUbiquitousKeyValueStore.default.synchronize()
                    }
                    
                    NotificationCenter.default.addObserver(
                        forName: UIApplication.didReceiveMemoryWarningNotification,
                        object: nil,
                        queue: .main
                    ) { _ in
                        Task {
                            await CacheManager.shared.clearAll()
                        }
                    }
                }
        }
    }
}
