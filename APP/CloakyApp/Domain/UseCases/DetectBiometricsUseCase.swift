// DetectBiometricsUseCase.swift
// Cloaky
//
// Use case for detecting biometric data in an image.

import Foundation
import UIKit
import CoreImage

// MARK: - DetectBiometricsUseCase

/// Clean architecture use case for biometric detection
final class DetectBiometricsUseCase {
    
    private let pipeline: ProcessingPipeline
    
    init(pipeline: ProcessingPipeline) {
        self.pipeline = pipeline
    }
    
    /// Execute biometric detection on an image
    /// - Parameters:
    ///   - image: The source UIImage
    ///   - settings: Detection settings
    ///   - progressHandler: Progress callback
    /// - Returns: Detection results
    func execute(
        image: UIImage,
        settings: DetectionSettings = .default,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> DetectionResults {
        let normalizedImage = image.normalized()
        guard let ciImage = CIImage(image: normalizedImage) else {
            throw ProcessingError.imageConversionFailed
        }
        
        return try await pipeline.detectOnly(
            in: ciImage,
            settings: settings,
            progressHandler: progressHandler
        )
    }
}
