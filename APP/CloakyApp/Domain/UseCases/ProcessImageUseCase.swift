// ProcessImageUseCase.swift
// Cloaky
//
// Use case for processing a single image through the full pipeline.

import Foundation
import UIKit
import CoreImage

// MARK: - ProcessImageUseCase

/// Clean architecture use case for processing an image
final class ProcessImageUseCase {
    
    private let pipeline: ProcessingPipeline
    
    init(pipeline: ProcessingPipeline) {
        self.pipeline = pipeline
    }
    
    /// Execute the full processing pipeline on an image
    /// - Parameters:
    ///   - image: The source UIImage
    ///   - method: Obfuscation method to use
    ///   - settings: Obfuscation settings
    ///   - progressHandler: Progress callback (step, progress)
    /// - Returns: Tuple of processed image and detection results
    func execute(
        image: UIImage,
        method: ObfuscationMethod = .intelligentBlur,
        settings: ObfuscationSettings = .default,
        detectionSettings: DetectionSettings = .default,
        progressHandler: ((String, Double) -> Void)? = nil
    ) async throws -> (image: UIImage, results: DetectionResults) {
        let normalizedImage = image.normalized()
        guard let ciImage = CIImage(image: normalizedImage) else {
            throw ProcessingError.imageConversionFailed
        }
        
        return try await pipeline.process(
            ciImage,
            detectionSettings: detectionSettings,
            obfuscationMethod: method,
            obfuscationSettings: settings,
            progressHandler: progressHandler
        )
    }
}
