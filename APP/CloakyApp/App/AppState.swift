// AppState.swift
// Cloaky
//
// Shared app state and dependency container.

import Foundation
import UIKit
import Combine
import SwiftUI

// MARK: - AppState

/// Shared state and dependency container for the entire app
@MainActor
final class AppState: ObservableObject {
    
    // MARK: - Shared Dependencies
    
    /// The main processing pipeline (shared across all views)
    let processingPipeline: ProcessingPipeline
    
    // MARK: - Shared State
    
    @Published var selectedImage: UIImage?
    @Published var detectionResults: DetectionResults?
    @Published var processedImage: UIImage?
    @Published var hasCompletedOnboarding: Bool = false
    
    var isPremium: Bool {
        false
    }
    
    // MARK: - Init
    
    init() {
        // Create shared pipeline with all engines
        let detectionEngine = DetectionEngine()
        let obfuscationEngine = ObfuscationEngine()
        let metadataHandler = MetadataHandler()
        
        self.processingPipeline = ProcessingPipeline(
            detectionEngine: detectionEngine,
            obfuscationEngine: obfuscationEngine,
            metadataHandler: metadataHandler
        )
    }
    
    // MARK: - State Management
    
    /// Reset all state for a new session
    func reset() {
        selectedImage = nil
        detectionResults = nil
        processedImage = nil
    }
    

}
