// ProcessingPipeline.swift
// Cloaky
//
// End-to-end orchestration: Detection → Obfuscation → Metadata Stripping → Export.
// Supports both auto-detected regions and manual brush strokes.
// Budget: <5s for 12MP image, <500MB peak memory.

import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

// MARK: - Processing Errors

enum ProcessingError: LocalizedError {
    case noBiometricsDetected
    case processingFailed
    case metadataStrippingFailed
    case imageConversionFailed
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .noBiometricsDetected: return "No biometric data detected in this image."
        case .processingFailed: return "Image processing failed. Please try again."
        case .metadataStrippingFailed: return "Failed to remove metadata."
        case .imageConversionFailed: return "Failed to convert the processed image."
        case .cancelled: return "Processing was cancelled."
        }
    }
}

// MARK: - ProcessingPipeline

/// Orchestrates the complete image processing flow:
/// 1. Detection (40% time) → 2. Obfuscation (50%) → 3. Render (5%) → 4. Metadata strip (5%)
final class ProcessingPipeline: @unchecked Sendable {
    
    // MARK: - Properties
    
    let detectionEngine: DetectionEngine
    let obfuscationEngine: ObfuscationEngine
    let metadataHandler: MetadataHandler
    
    /// Shared CIContext (reused, Metal-accelerated)
    let ciContext: CIContext = {
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false,    // Use Metal GPU
            .priorityRequestLow: false,     // High priority
            .cacheIntermediates: false      // DISABLED: No caching of intermediate filters
        ]
        return CIContext(options: options)
    }()
    
    // MARK: - Init
    
    init(
        detectionEngine: DetectionEngine = DetectionEngine(),
        obfuscationEngine: ObfuscationEngine = ObfuscationEngine(),
        metadataHandler: MetadataHandler = MetadataHandler()
    ) {
        self.detectionEngine = detectionEngine
        self.obfuscationEngine = obfuscationEngine
        self.metadataHandler = metadataHandler
    }
    
    // MARK: - Full Pipeline
    
    /// Process an image through the complete pipeline: detect → obfuscate → strip metadata
    func process(
        _ image: CIImage,
        detectionSettings: DetectionSettings = .default,
        obfuscationMethod: ObfuscationMethod = .intelligentBlur,
        obfuscationSettings: ObfuscationSettings = .default,
        progressHandler: ((String, Double) -> Void)? = nil
    ) async throws -> (image: UIImage, results: DetectionResults) {
        
        var currentImage = image
        
        // STEP 1: DETECTION (35% of total time)
        progressHandler?("Detecting biometrics...", 0.0)
        
        let results = try await detectionEngine.detect(
            in: currentImage,
            settings: detectionSettings
        ) { detectionProgress in
            progressHandler?("Detecting biometrics...", detectionProgress * 0.35)
        }
        
        try Task.checkCancellation()
        
        guard results.totalCount > 0 else {
            throw ProcessingError.noBiometricsDetected
        }
        
        // STEP 2: OBFUSCATION (50% of total time)
        progressHandler?("Applying protection...", 0.35)
        
        let processed = await obfuscationEngine.obfuscate(
            currentImage,
            regions: results.allRegions,
            method: obfuscationMethod,
            settings: obfuscationSettings
        ) { obfuscationProgress in
            progressHandler?("Applying protection...", 0.35 + obfuscationProgress * 0.5)
        }
        
        try Task.checkCancellation()
        
        // STEP 3: RENDER to UIImage (7.5%)
        progressHandler?("Finalizing...", 0.85)
        
        guard let cgImage = ciContext.createCGImage(processed, from: processed.extent) else {
            throw ProcessingError.imageConversionFailed
        }
        let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
        
        // STEP 4: METADATA STRIPPING (7.5%)
        progressHandler?("Removing metadata...", 0.925)
        
        guard let cleanImage = metadataHandler.stripMetadata(from: uiImage) else {
            throw ProcessingError.metadataStrippingFailed
        }
        
        progressHandler?("Complete", 1.0)
        
        return (image: cleanImage, results: results)
    }
    
    // MARK: - Simple Processing (Pre-detected Regions)
    
    /// Process with pre-detected regions (skip detection step).
    func processSimple(
        _ image: CIImage,
        regions: [any BiometricRegion],
        method: ObfuscationMethod = .intelligentBlur,
        settings: ObfuscationSettings = .default,
        progressHandler: ((String, Double) -> Void)? = nil
    ) async throws -> UIImage {
        
        var currentImage = image
        
        progressHandler?("Applying protection...", 0.0)
        
        let processed = await obfuscationEngine.obfuscate(
            currentImage,
            regions: regions,
            method: method,
            settings: settings
        ) { progress in
            progressHandler?("Applying protection...", progress * 0.85)
        }
        
        try Task.checkCancellation()
        
        // Render
        progressHandler?("Finalizing...", 0.85)
        
        guard let cgImage = ciContext.createCGImage(processed, from: processed.extent) else {
            throw ProcessingError.imageConversionFailed
        }
        let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
        
        // Strip metadata
        progressHandler?("Removing metadata...", 0.925)
        
        guard let cleanImage = metadataHandler.stripMetadata(from: uiImage) else {
            throw ProcessingError.metadataStrippingFailed
        }
        
        progressHandler?("Complete", 1.0)
        return cleanImage
    }
    
    // MARK: - Brush Blur Application
    
    /// Apply manual brush blur to an image using stroke mask.
    /// - Parameters:
    ///   - image: Source CIImage
    ///   - strokes: Array of brush strokes from the canvas
    ///   - intensity: Blur intensity (0.0-1.0)
    ///   - imageSize: Original image size in points
    ///   - displaySize: Canvas display size the strokes were drawn at
    /// - Returns: Image with brush blur applied
    func applyBrushBlur(
        to image: CIImage,
        strokes: [BrushStroke],
        intensity: Double,
        imageSize: CGSize,
        displaySize: CGSize
    ) -> CIImage {
        guard !strokes.isEmpty else { return image }
        
        // Generate mask from strokes
        guard let mask = strokes.toBlurmask(imageSize: imageSize, displaySize: displaySize) else {
            return image
        }
        
        // Create blurred version — must match BrushCanvasView.generateBlurred formula
        // Slider range: 0.1-1.0 → blur radius: 6-60 pixels
        let blurRadius = intensity * 60.0
        
        // Extend image to avoid edge artifacts, then crop back
        let extendedImage = image.clampedToExtent()
        
        let blurFilter = CIFilter.gaussianBlur()
        blurFilter.inputImage = extendedImage
        blurFilter.radius = Float(blurRadius)
        
        guard let blurredImage = blurFilter.outputImage else {
            return image
        }
        
        // Crop blurred image to original extent
        let croppedBlurred = blurredImage.cropped(to: image.extent)
        
        // Composite: blend original and blurred using mask
        let finalMask = mask

        // Use CIBlendWithMask: where mask is white → show blurred, where black → show original
        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = croppedBlurred
        blendFilter.backgroundImage = image
        blendFilter.maskImage = finalMask
        
        return blendFilter.outputImage ?? image
    }
    
    // MARK: - Detection Only
    
    /// Run detection only (no obfuscation)
    func detectOnly(
        in image: CIImage,
        settings: DetectionSettings = .default,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> DetectionResults {
        try await detectionEngine.detect(in: image, settings: settings, progressHandler: progressHandler)
    }
}
