// HandDetector.swift
// Cloaky
//
// Hand detection using Vision Framework VNDetectHumanHandPoseRequest.
// Detects up to 10 hands with 21 joint landmarks each.

import Foundation
import Vision
import CoreImage

// MARK: - HandDetector

/// Detects hands and joint landmarks using Vision Framework
final class HandDetector: BiometricDetectorProtocol, @unchecked Sendable {
    
    private let processingQueue = DispatchQueue(
        label: "com.cloak.handDetector",
        qos: .userInitiated
    )
    
    /// Maximum number of hands to detect
    private let maximumHandCount: Int
    /// Padding around hand bounding box in pixels
    private let boundingBoxPadding: CGFloat
    
    init(maximumHandCount: Int = 10, boundingBoxPadding: CGFloat = 30) {
        self.maximumHandCount = maximumHandCount
        self.boundingBoxPadding = boundingBoxPadding
    }
    
    // MARK: - Detection
    
    /// Detect hands in the provided CIImage
    func detect(in image: CIImage) async throws -> [HandDetection] {
        try Task.checkCancellation()
        
        let imageSize = image.extent.size
        
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                do {
                    let handPoseRequest = VNDetectHumanHandPoseRequest()
                    handPoseRequest.maximumHandCount = self.maximumHandCount
                    
                    let handler = VNImageRequestHandler(ciImage: image, options: [:])
                    try handler.perform([handPoseRequest])
                    
                    guard let observations = handPoseRequest.results else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    let detections = observations.compactMap { observation -> HandDetection? in
                        self.processHandObservation(observation, imageSize: imageSize)
                    }
                    
                    continuation.resume(returning: detections)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Process Observation
    
    private func processHandObservation(
        _ observation: VNHumanHandPoseObservation,
        imageSize: CGSize
    ) -> HandDetection? {
        // All joint names to extract
        let jointNames: [VNHumanHandPoseObservation.JointName] = [
            .wrist,
            .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
            .indexMCP, .indexPIP, .indexDIP, .indexTip,
            .middleMCP, .middlePIP, .middleDIP, .middleTip,
            .ringMCP, .ringPIP, .ringDIP, .ringTip,
            .littleMCP, .littlePIP, .littleDIP, .littleTip
        ]
        
        var landmarks: [String: CGPoint] = [:]
        var confidences: [Float] = []
        var points: [CGPoint] = []
        
        for jointName in jointNames {
            guard let point = try? observation.recognizedPoint(jointName),
                  point.confidence > 0.05 else { continue }
            
            // Convert from Vision normalised coordinates to pixel coordinates.
            // Both Vision and CIImage use bottom-left origin — no Y-flip needed.
            let pixelPoint = CGPoint(
                x: point.location.x * imageSize.width,
                y: point.location.y * imageSize.height
            )
            
            landmarks["\(jointName.rawValue)"] = pixelPoint
            confidences.append(point.confidence)
            points.append(pixelPoint)
        }
        
        guard !points.isEmpty else { return nil }
        
        // Calculate bounding box from landmarks
        let boundingBox = calculateBoundingBox(from: points, padding: boundingBoxPadding, imageSize: imageSize)
        
        // Average confidence
        let avgConfidence = confidences.reduce(0, +) / Float(confidences.count)
        
        // Determine chirality
        let chirality: String
        if #available(iOS 15.0, *) {
            chirality = observation.chirality == .left ? "left" : "right"
        } else {
            chirality = "unknown"
        }
        
        return HandDetection(
            boundingBox: boundingBox,
            confidence: avgConfidence,
            landmarks: landmarks,
            chirality: chirality
        )
    }
    
    // MARK: - Bounding Box Calculation
    
    /// Calculate bounding box from an array of points with padding
    private func calculateBoundingBox(
        from points: [CGPoint],
        padding: CGFloat,
        imageSize: CGSize
    ) -> CGRect {
        guard !points.isEmpty else { return .zero }
        
        let minX = points.map(\.x).min()! - padding
        let maxX = points.map(\.x).max()! + padding
        let minY = points.map(\.y).min()! - padding
        let maxY = points.map(\.y).max()! + padding
        
        // Clamp to image bounds
        let clampedMinX = max(0, minX)
        let clampedMinY = max(0, minY)
        let clampedMaxX = min(imageSize.width, maxX)
        let clampedMaxY = min(imageSize.height, maxY)
        
        return CGRect(
            x: clampedMinX,
            y: clampedMinY,
            width: clampedMaxX - clampedMinX,
            height: clampedMaxY - clampedMinY
        )
    }
}
