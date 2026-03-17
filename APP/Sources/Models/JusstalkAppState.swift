// JusstalkAppState.swift
// Jusstalk
//
// Shared app state and dependency container.

import Foundation
import SwiftUI

// MARK: - JusstalkAppState

/// Shared state and dependency container for the entire app
@MainActor
final class JusstalkAppState: ObservableObject {
    
    // MARK: - Published State
    
    @Published var hasCompletedOnboarding: Bool = false
    
    // MARK: - Dependencies
    
    weak var storeManager: StoreManager?
    
    // MARK: - Computed Properties
    
    var isPremium: Bool {
        storeManager?.isPremium ?? false
    }
    
    // MARK: - Init
    
    init() {}
    
    // MARK: - Configuration
    
    func configure(storeManager: StoreManager) {
        self.storeManager = storeManager
    }
}
