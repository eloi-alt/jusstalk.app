// CloakyImage.swift
// Cloaky
//
// Domain model representing an image being processed by Cloaky.

import Foundation
import UIKit
import CoreImage

// MARK: - CloakyImage

/// Represents an image at various stages of the Cloak processing pipeline
struct CloakyImage: Identifiable {
    let id: UUID
    let originalImage: UIImage
    let ciImage: CIImage
    var processedImage: UIImage?
    var detectionResults: DetectionResults?
    let createdAt: Date
    
    init(image: UIImage) {
        let normalizedImage = image.normalized()
        self.id = UUID()
        self.originalImage = normalizedImage
        self.ciImage = CIImage(image: normalizedImage) ?? CIImage()
        self.processedImage = nil
        self.detectionResults = nil
        self.createdAt = Date()
    }
    
    /// Whether detection has been run
    var isDetected: Bool {
        detectionResults != nil
    }
    
    /// Whether processing is complete
    var isProcessed: Bool {
        processedImage != nil
    }
    
    /// Image dimensions string
    var dimensionsString: String {
        let size = originalImage.size
        return "\(Int(size.width))×\(Int(size.height))"
    }
    
    /// Estimated file size in MB
    var estimatedSizeMB: Double {
        guard let data = originalImage.jpegData(compressionQuality: 0.9) else { return 0 }
        return Double(data.count) / (1024 * 1024)
    }
}
