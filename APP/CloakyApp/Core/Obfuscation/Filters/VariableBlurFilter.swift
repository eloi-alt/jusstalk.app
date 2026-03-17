// VariableBlurFilter.swift
// Cloaky
//
// Custom variable blur filter using Core Image filter chaining.
// Applies different blur intensities to different regions of an image.

import Foundation
import CoreImage

// MARK: - VariableBlurFilter

/// Applies variable-intensity blur using multiple masked Gaussian blur passes
final class VariableBlurFilter {
    
    /// Region with its associated blur intensity
    struct BlurRegion {
        let rect: CGRect
        let sigma: Double
        let feather: CGFloat
    }
    
    /// Apply variable blur to an image with multiple regions at different intensities
    /// - Parameters:
    ///   - image: Source CIImage
    ///   - regions: Array of blur regions with individual sigma values
    /// - Returns: Image with variable blur applied
    static func apply(to image: CIImage, regions: [BlurRegion]) -> CIImage {
        var result = image
        
        // Sort by sigma (apply lighter blurs first, heavier last)
        let sorted = regions.sorted { $0.sigma < $1.sigma }
        
        for region in sorted {
            result = result.applyGaussianBlur(
                sigma: region.sigma,
                region: region.rect,
                feather: region.feather
            )
        }
        
        return result
    }
    
    /// Create blur regions from face landmarks
    /// - Parameters:
    ///   - face: The face detection with landmarks
    ///   - intensity: Base intensity multiplier (0-1)
    /// - Returns: Array of blur regions for variable-intensity face blur
    static func faceBlurRegions(
        for face: FaceDetection,
        intensity: Double
    ) -> [BlurRegion] {
        var regions: [BlurRegion] = []
        
        // Face contour (light blur)
        regions.append(BlurRegion(
            rect: face.boundingBox.expanded(by: 1.1),
            sigma: 10 * intensity,
            feather: 15
        ))
        
        // Without detailed landmarks, use geometric estimation
        let box = face.boundingBox
        
        // Eyes region (top 40% of face, maximum blur)
        let eyeRegion = CGRect(
            x: box.minX + box.width * 0.1,
            y: box.minY + box.height * 0.2,
            width: box.width * 0.8,
            height: box.height * 0.25
        )
        regions.append(BlurRegion(rect: eyeRegion, sigma: 22 * intensity, feather: 8))
        
        // Nose region (center)
        let noseRegion = CGRect(
            x: box.minX + box.width * 0.3,
            y: box.minY + box.height * 0.35,
            width: box.width * 0.4,
            height: box.height * 0.3
        )
        regions.append(BlurRegion(rect: noseRegion, sigma: 15 * intensity, feather: 10))
        
        // Mouth region (bottom)
        let mouthRegion = CGRect(
            x: box.minX + box.width * 0.2,
            y: box.minY + box.height * 0.65,
            width: box.width * 0.6,
            height: box.height * 0.2
        )
        regions.append(BlurRegion(rect: mouthRegion, sigma: 15 * intensity, feather: 10))
        
        return regions
    }
}
