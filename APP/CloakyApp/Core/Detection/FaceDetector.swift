// FaceDetector.swift
// Cloaky
//
// High-performance face detection using Vision Framework.
// Detects faces and extracts detailed landmarks (eyes, nose, mouth, contour).

import Foundation
import Vision
import CoreImage
import UIKit

// MARK: - BiometricDetectorProtocol

/// Protocol for all biometric detectors
protocol BiometricDetectorProtocol: Sendable {
    associatedtype DetectionType: BiometricRegion
    func detect(in image: CIImage) async throws -> [DetectionType]
}

// MARK: - FaceDetector

/// Detects faces and facial landmarks using Vision Framework
final class FaceDetector: BiometricDetectorProtocol, @unchecked Sendable {
    
    /// Dedicated processing queue for detection work
    private let processingQueue = DispatchQueue(
        label: "com.cloak.faceDetector",
        qos: .userInitiated
    )
    
    /// Minimum confidence threshold for face detection
    private let minimumConfidence: Float
    
    init(minimumConfidence: Float = 0.25) {
        self.minimumConfidence = minimumConfidence
    }
    
    // MARK: - Detection
    
    /// Detect faces in the provided CIImage
    /// - Parameter image: The source image to analyze
    /// - Returns: Array of FaceDetection results with landmarks
    func detect(in image: CIImage) async throws -> [FaceDetection] {
        try Task.checkCancellation()
        
        let imageSize = image.extent.size
        
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                do {
                    // Create face landmarks request (includes face detection)
                    let landmarksRequest = VNDetectFaceLandmarksRequest()
                    // Create basic face rectangles request (better for small/far faces)
                    let rectanglesRequest = VNDetectFaceRectanglesRequest()
                    
                    if #available(iOS 16.0, *) {
                        landmarksRequest.revision = VNDetectFaceLandmarksRequestRevision3
                        rectanglesRequest.revision = VNDetectFaceRectanglesRequestRevision3
                    }
                    
                    // Create request handler
                    let handler = VNImageRequestHandler(ciImage: image, options: [:])
                    try handler.perform([landmarksRequest, rectanglesRequest])
                    
                    // Process results
                    var allDetections: [FaceDetection] = []
                    var usedRects: [CGRect] = []
                    
                    // Helper to check for duplicates (IoU or significant overlap)
                    let isDuplicate: (CGRect) -> Bool = { rect in
                        let rectArea = rect.width * rect.height
                        guard rectArea > 0 else { return true }
                        
                        return usedRects.contains { usedRect in
                            let intersection = usedRect.intersection(rect)
                            guard !intersection.isNull else { return false }
                            let intersectArea = intersection.width * intersection.height
                            let minArea = min(usedRect.width * usedRect.height, rectArea)
                            // If the intersection covers more than 50% of the smallest box, it's a duplicate
                            return intersectArea > (minArea * 0.5)
                        }
                    }
                    
                    // 1. First process high-quality landmark detections
                    if let landmarkResults = landmarksRequest.results {
                        for observation in landmarkResults {
                            guard observation.confidence >= self.minimumConfidence else { continue }
                            
                            usedRects.append(observation.boundingBox)
                            let pixelBox = self.convertBoundingBox(observation.boundingBox, imageSize: imageSize)
                            
                            allDetections.append(FaceDetection(
                                boundingBox: pixelBox,
                                confidence: observation.confidence,
                                landmarks: observation.landmarks,
                                roll: observation.roll,
                                yaw: observation.yaw
                            ))
                        }
                    }
                    
                    // 2. Then add basic rectangle detections for small/far faces that landmarks missed
                    if let rectangleResults = rectanglesRequest.results {
                        for observation in rectangleResults {
                            guard observation.confidence >= self.minimumConfidence else { continue }
                            guard !isDuplicate(observation.boundingBox) else { continue }
                            
                            usedRects.append(observation.boundingBox)
                            let pixelBox = self.convertBoundingBox(observation.boundingBox, imageSize: imageSize)
                            
                            allDetections.append(FaceDetection(
                                boundingBox: pixelBox,
                                confidence: observation.confidence,
                                // No landmarks available for these bounding boxes
                                landmarks: nil,
                                roll: nil,
                                yaw: nil
                            ))
                        }
                    }
                    
                    continuation.resume(returning: allDetections)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Coordinate Conversion
    
    /// Convert Vision normalized bounding box to pixel coordinates (bottom-left origin).
    ///
    /// Vision and CIImage both use the same coordinate system:
    /// origin at **bottom-left**, Y increases upward, values normalised 0-1.
    /// We simply scale to pixel coordinates — no Y-flip is needed.
    ///
    /// - Parameters:
    ///   - box: Normalized bounding box from Vision
    ///   - imageSize: Size of the source image in pixels
    /// - Returns: Bounding box in pixel coordinates (bottom-left origin, matches CIImage)
    func convertBoundingBox(_ box: CGRect, imageSize: CGSize) -> CGRect {
        let x = box.origin.x * imageSize.width
        let y = box.origin.y * imageSize.height
        let width = box.width * imageSize.width
        let height = box.height * imageSize.height
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
