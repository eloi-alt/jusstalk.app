// ProcessingViewModel.swift
// Cloaky
//
// ViewModel for the processing screen with progress tracking.
// Supports both auto-detected regions and manual brush strokes.

import Foundation
import UIKit
import CoreImage
import Combine

// MARK: - ProcessingViewModel

@MainActor
final class ProcessingViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var processingProgress: Double = 0.0
    @Published var currentStep: String = ""
    @Published var processedImage: UIImage?
    @Published var detectionResults: DetectionResults?
    @Published var isProcessing: Bool = false
    @Published var isComplete: Bool = false
    @Published var error: Error?
    @Published var processingTime: TimeInterval = 0
    
    // MARK: - Dependencies
    
    private let pipeline: ProcessingPipeline
    private var processingTask: Task<Void, Never>?
    
    // MARK: - Init
    
    init(pipeline: ProcessingPipeline) {
        self.pipeline = pipeline
    }
    
    // MARK: - Processing (with brush strokes support)
    
    /// Start processing with both regions and brush strokes
    func process(
        image: UIImage,
        regions: [any BiometricRegion],
        brushStrokes: [BrushStroke] = [],
        brushIntensity: Double = 0.8,
        canvasDisplaySize: CGSize = .zero,
        method: ObfuscationMethod,
        settings: ObfuscationSettings = .default
    ) async {
        // Normalize to guarantee orientation=.up / scale=1
        let normalizedImage = image.normalized()
        guard let ciImage = CIImage(image: normalizedImage) else {
            error = ProcessingError.imageConversionFailed
            return
        }
        
        isProcessing = true
        isComplete = false
        processingProgress = 0.0
        currentStep = String(localized: "processing.starting", defaultValue: "Starting...")
        error = nil
        
        let startTime = Date()
        
        do {
            // Determine what we need to do
            let hasRegions = !regions.isEmpty
            let hasBrush = !brushStrokes.isEmpty
            
            // Image courante qui va subir les transformations successives
            var currentImage: CIImage = ciImage
            
            // --- ÉTAPE 1 : REGION OBFUSCATION (40%) ---
            if hasRegions {
                currentStep = String(localized: "processing.applying.region.protection", defaultValue: "Applying region protection...")
                processingProgress = 0.1
                
                currentImage = await pipeline.obfuscationEngine.obfuscate(
                    currentImage,
                    regions: regions,
                    method: method,
                    settings: settings
                ) { [weak self] progress in
                    Task { @MainActor in
                        let range = hasBrush ? 0.4 : 0.7
                        self?.processingProgress = 0.1 + (progress * range)
                    }
                }
            }
            
            try Task.checkCancellation()
            
            // --- ÉTAPE 2 : BRUSH STROKES (40%) ---
            if hasBrush {
                currentStep = String(localized: "processing.applying.brush.blur", defaultValue: "Applying brush blur...")
                
                currentImage = pipeline.applyBrushBlur(
                    to: currentImage,
                    strokes: brushStrokes,
                    intensity: brushIntensity,
                    imageSize: image.size,
                    displaySize: canvasDisplaySize
                )
                
                processingProgress = hasRegions ? 0.9 : 0.8
            }
            
            try Task.checkCancellation()
            
            // --- ÉTAPE 3 : RENDER & METADATA (20%) ---
            currentStep = String(localized: "processing.finalizing", defaultValue: "Finalizing...")
            
            guard let cgImage = pipeline.ciContext.createCGImage(currentImage, from: currentImage.extent) else {
                throw ProcessingError.imageConversionFailed
            }
            
            let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
            
            currentStep = String(localized: "processing.removing.metadata", defaultValue: "Removing metadata...")
            processingProgress = 0.95
            
            guard let cleanImage = pipeline.metadataHandler.stripMetadata(from: uiImage) else {
                throw ProcessingError.metadataStrippingFailed
            }
            
            processedImage = cleanImage
            processingTime = Date().timeIntervalSince(startTime)
            isProcessing = false
            isComplete = true
            currentStep = String(localized: "processing.complete", defaultValue: "Complete")
            processingProgress = 1.0
            
        } catch {
            // CRITICAL: Never fallback to original image on failure
            self.error = error
            isProcessing = false
            isComplete = false  // Ensure we don't show "success" state
            
            // Explicit error message for debugging
            let errorDesc = error.localizedDescription
            currentStep = "ERROR: \(errorDesc)"
            
            // DO NOT update processedImage - leave user on previous screen
            // The UI should display an error alert blocking further action
        }
    }
    
    // MARK: - Legacy Process (without brush)
    
    /// Start the full processing pipeline
    func processRegionsOnly(
        image: UIImage,
        regions: [any BiometricRegion],
        method: ObfuscationMethod,
        settings: ObfuscationSettings = .default
    ) async {
        await process(
            image: image,
            regions: regions,
            method: method,
            settings: settings
        )
    }
    
    /// Start the full auto-detect + process pipeline
    func processWithDetection(
        image: UIImage,
        method: ObfuscationMethod = .intelligentBlur,
        settings: ObfuscationSettings = .default,
        detectionSettings: DetectionSettings = .default
    ) async {
        let normalizedImage = image.normalized()
        guard let ciImage = CIImage(image: normalizedImage) else {
            error = ProcessingError.imageConversionFailed
            return
        }
        
        isProcessing = true
        isComplete = false
        processingProgress = 0.0
        currentStep = String(localized: "processing.starting", defaultValue: "Starting...")
        error = nil
        
        let startTime = Date()
        
        do {
            let result = try await pipeline.process(
                ciImage,
                detectionSettings: detectionSettings,
                obfuscationMethod: method,
                obfuscationSettings: settings
            ) { [weak self] step, progress in
                Task { @MainActor in
                    self?.currentStep = step
                    self?.processingProgress = progress
                }
            }
            
            processedImage = result.image
            detectionResults = result.results
            processingTime = Date().timeIntervalSince(startTime)
            isProcessing = false
            isComplete = true
            currentStep = String(localized: "processing.complete", defaultValue: "Complete")
            processingProgress = 1.0
            
        } catch {
            // CRITICAL: Never fallback to original image on failure
            self.error = error
            isProcessing = false
            isComplete = false
            currentStep = "ERROR: \(error.localizedDescription)"
            // DO NOT update processedImage
        }
    }
    
    // MARK: - Cancellation
    
    func cancel() {
        processingTask?.cancel()
        isProcessing = false
        currentStep = String(localized: "processing.cancelled", defaultValue: "Cancelled")
    }
}
