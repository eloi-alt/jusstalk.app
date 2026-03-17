// PreviewViewModel.swift
// Cloaky
//
// ViewModel for the before/after preview screen with export functionality.

import Foundation
import UIKit
import Photos
import Combine

// MARK: - PreviewViewModel

@MainActor
final class PreviewViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var originalImage: UIImage?
    @Published var processedImage: UIImage?
    @Published var sliderPosition: Double = 0.5
    @Published var isSaving: Bool = false
    @Published var isSaved: Bool = false
    @Published var isSharing: Bool = false
    @Published var errorMessage: String?
    @Published var detectionResults: DetectionResults?
    @Published var processingTime: TimeInterval = 0
    
    // MARK: - Init
    
    init() {}
    
    /// Configure with images and results
    func configure(
        original: UIImage,
        processed: UIImage,
        results: DetectionResults? = nil,
        processingTime: TimeInterval = 0
    ) {
        self.originalImage = original
        self.processedImage = processed
        self.detectionResults = results
        self.processingTime = processingTime
    }
    
    // MARK: - Save to Photos
    
    /// Save the processed image to the photo library
    func saveToPhotos() async {
        guard let image = processedImage else {
            errorMessage = String(localized: "error.save.image", defaultValue: "No processed image to save")
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        do {
            // Request permission if needed
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                errorMessage = String(localized: "error.photo.access.denied", defaultValue: "Photo library access denied")
                isSaving = false
                return
            }
            
            // Save to photo library
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            
            isSaving = false
            isSaved = true
            
        } catch {
            isSaving = false
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Share
    
    /// Trigger share sheet
    func share() {
        isSharing = true
    }
    
    // MARK: - Stats
    
    /// Protection summary for display
    var protectionSummary: [(icon: String, text: String)] {
        var items: [(String, String)] = []
        
        if let results = detectionResults {
            if !results.faces.isEmpty {
                items.append(("face.dashed", "\(results.faces.count) face\(results.faces.count > 1 ? "s" : "") protected"))
            }
            if !results.hands.isEmpty {
                items.append(("hand.raised", "\(results.hands.count) hand\(results.hands.count > 1 ? "s" : "") protected"))
            }
            if !results.texts.isEmpty {
                let textSummary = results.texts.count == 1 
                    ? String(localized: "preview.texts.hidden", defaultValue: "1 text hidden")
                    : String(localized: "preview.texts.hidden.plural", defaultValue: "\(results.texts.count) texts hidden")
                items.append(("doc.text", textSummary))
            }
        }
        
        items.append(("checkmark.shield", String(localized: "preview.metadata.removed", defaultValue: "Metadata removed")))
        
        if processingTime > 0 {
            items.append(("clock", String(format: "Processed in %.1fs", processingTime)))
        }
        
        return items
    }
    
    // MARK: - Reset
    
    func reset() {
        sliderPosition = 0.5
        isSaved = false
        isSharing = false
        errorMessage = nil
    }
}
