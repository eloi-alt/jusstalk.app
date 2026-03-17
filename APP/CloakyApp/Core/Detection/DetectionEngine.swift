// DetectionEngine.swift
// Cloaky
//
// Orchestrates all biometric detectors with parallel execution and intelligent caching.

import Foundation
import CoreImage
import UIKit

// MARK: - DetectionEngine

/// Central orchestrator for all biometric detection
/// Runs detectors in parallel and caches results for performance.
final class DetectionEngine: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let faceDetector: FaceDetector
    private let handDetector: HandDetector
    private let textDetector: TextDetector
    
    /// LRU cache keyed by image hash
    private let cache = NSCache<NSString, CachedDetectionResults>()
    
    // MARK: - Init
    
    init(
        faceDetector: FaceDetector = FaceDetector(),
        handDetector: HandDetector = HandDetector(),
        textDetector: TextDetector = TextDetector()
    ) {
        self.faceDetector = faceDetector
        self.handDetector = handDetector
        self.textDetector = textDetector
        
        // Cache configuration
        cache.countLimit = 10
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
        
        // Clear cache on memory warning
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Detection
    
    /// Run all enabled detectors in parallel on the given image
    /// - Parameters:
    ///   - image: The source CIImage to analyze
    ///   - settings: Detection settings controlling which detectors to run
    ///   - progressHandler: Callback reporting progress (0.0 - 1.0)
    /// - Returns: Aggregated detection results
    func detect(
        in image: CIImage,
        settings: DetectionSettings = .default,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> DetectionResults {
        try Task.checkCancellation()
        
        // PARANOÏA MODE: Cache DISABLED - always recompute
        // let cacheKey = NSString(string: "\(image.extent.hashValue)")
        // if let cached = cache.object(forKey: cacheKey) {
        //     progressHandler?(1.0)
        //     return cached.results
        // }
        
        // Downsample for detection if image is very large (process at max 4096px).
        // Using 4096 gives the best detection accuracy for faces and hands,
        // trading off more processing time for significantly better results.
        let detectionImage = image.downsampledForDetection(maxDimension: 4096)
        let scale = image.extent.width / detectionImage.extent.width
        
        // Run detectors in parallel
        progressHandler?(0.0)
        
        // Parallel detection with async let (faces + hands + text)
        async let facesResult: [FaceDetection] = {
            guard settings.detectFaces else { return [] }
            return try await self.faceDetector.detect(in: detectionImage)
        }()
        
        async let handsResult: [HandDetection] = {
            guard settings.detectHands else { return [] }
            return try await self.handDetector.detect(in: detectionImage)
        }()
        
        async let textsResult: [TextDetection] = {
            guard settings.detectText else { return [] }
            return try await self.textDetector.detect(in: detectionImage, mode: settings.textMode)
        }()
        
        // Await all results
        let faces = try await facesResult
        let hands = try await handsResult
        let texts = try await textsResult
        
        // Scale bounding boxes back to original image size if downsampled
        let scaledFaces = faces.map { face in
            FaceDetection(
                id: face.id,
                boundingBox: face.boundingBox.scaled(by: scale),
                confidence: face.confidence,
                landmarks: face.landmarks,
                roll: face.roll,
                yaw: face.yaw
            )
        }
        
        let scaledHands = hands.map { hand in
            HandDetection(
                id: hand.id,
                boundingBox: hand.boundingBox.scaled(by: scale),
                confidence: hand.confidence,
                landmarks: hand.landmarks,
                chirality: hand.chirality
            )
        }
        
        let scaledTexts = texts.map { text in
            TextDetection(
                id: text.id,
                boundingBox: text.boundingBox.scaled(by: scale),
                confidence: text.confidence,
                text: text.text,
                isSensitive: text.isSensitive
            )
        }
        
        let results = DetectionResults(
            faces: scaledFaces,
            hands: scaledHands,
            texts: scaledTexts
        )
        
        // PARANOÏA MODE: Cache storage DISABLED
        // cache.setObject(CachedDetectionResults(results: results), forKey: cacheKey)
        
        progressHandler?(1.0)
        return results
    }
    
    // MARK: - Cache Management
    
    @objc func clearCache() {
        cache.removeAllObjects()
    }
}

// MARK: - Cache Wrapper

/// Wrapper class for NSCache (requires reference type)
private final class CachedDetectionResults: NSObject {
    let results: DetectionResults
    
    init(results: DetectionResults) {
        self.results = results
    }
}

// MARK: - CIImage Downsampling Extension

extension CIImage {
    /// Downsample image for faster detection processing
    func downsampledForDetection(maxDimension: CGFloat = 1024) -> CIImage {
        let currentMax = max(extent.width, extent.height)
        guard currentMax > maxDimension else { return self }
        
        let scale = maxDimension / currentMax
        return transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }
}

// MARK: - CGRect Scaling Extension

extension CGRect {
    /// Scale a rect by a given factor
    func scaled(by factor: CGFloat) -> CGRect {
        CGRect(
            x: origin.x * factor,
            y: origin.y * factor,
            width: width * factor,
            height: height * factor
        )
    }
    
    /// Expand rect by a given factor (centered)
    func expanded(by factor: CGFloat) -> CGRect {
        let newWidth = width * factor
        let newHeight = height * factor
        let dx = (newWidth - width) / 2
        let dy = (newHeight - height) / 2
        return CGRect(
            x: origin.x - dx,
            y: origin.y - dy,
            width: newWidth,
            height: newHeight
        )
    }
}
