// EmojiOverlay.swift
// Cloaky
//
// Covers biometric regions with context-appropriate emoji overlays.
// Fun and effective alternative to blur/blackbox.

import Foundation
import CoreImage
import UIKit

// MARK: - EmojiOverlay

/// Overlays context-appropriate emojis over detected biometric regions.
final class EmojiOverlay: ObfuscationMethodProtocol {
    
    // MARK: - Emoji Options
    
    private let emojiOptions = ["😀", "🎭", "👤", "🔒", "🙈", "👻"]
    
    // MARK: - Emoji Selection
    
    /// Select an appropriate emoji for the given biometric type
    func selectEmoji(for type: BiometricType) -> String {
        switch type {
        case .face: return "😀"
        case .hand: return "👋"
        case .text: return "📝"
        case .iris: return "🔒"
        }
    }
    
    // MARK: - Apply
    
    func apply(to image: CIImage, region: any BiometricRegion, settings: ObfuscationSettings) -> CIImage {
        let emoji = selectEmoji(for: region.type)
        let regionSize = region.boundingBox.size
        
        guard let emojiImage = createEmojiImage(emoji: emoji, size: regionSize) else {
            // Fallback to black box if emoji rendering fails
            return image.applyColorBox(
                color: CIColor(red: 0, green: 0, blue: 0, alpha: 1),
                region: region.boundingBox,
                feather: settings.featherRadius
            )
        }
        
        // The emoji CIImage was rendered via UIKit (top-left origin) but CIImage uses
        // bottom-left origin. Flip the emoji vertically so it appears right-side-up.
        let flipped = emojiImage.transformed(by: CGAffineTransform(
            scaleX: 1, y: -1
        ).concatenating(CGAffineTransform(
            translationX: 0, y: regionSize.height
        )))
        
        // Position emoji at the region's location (CIImage bottom-left coordinates)
        let positioned = flipped.transformed(
            by: CGAffineTransform(
                translationX: region.boundingBox.origin.x,
                y: region.boundingBox.origin.y
            )
        )
        
        // Composite emoji over original image
        guard let compositeFilter = CIFilter(name: "CISourceOverCompositing") else { return image }
        compositeFilter.setValue(positioned, forKey: kCIInputImageKey)
        compositeFilter.setValue(image, forKey: kCIInputBackgroundImageKey)
        
        return compositeFilter.outputImage ?? image
    }
    
    // MARK: - Emoji Image Creation
    
    /// Render an emoji string into a CIImage of the specified size
    /// - Parameters:
    ///   - emoji: The emoji character to render
    ///   - size: Target size for the rendered image
    /// - Returns: CIImage of the rendered emoji, or nil if rendering fails
    func createEmojiImage(emoji: String, size: CGSize) -> CIImage? {
        // Ensure minimum size
        let renderWidth = max(size.width, 20)
        let renderHeight = max(size.height, 20)
        let renderSize = CGSize(width: renderWidth, height: renderHeight)
        
        // Use UIGraphics to render emoji
        let renderer = UIGraphicsImageRenderer(size: renderSize)
        
        let uiImage = renderer.image { context in
            // White semi-transparent background circle
            let bgRect = CGRect(origin: .zero, size: renderSize)
            UIColor.white.withAlphaComponent(0.9).setFill()
            UIBezierPath(ovalIn: bgRect).fill()
            
            // Calculate font size to fill ~80% of the region
            let fontSize = min(renderSize.width, renderSize.height) * 0.8
            let font = UIFont.systemFont(ofSize: fontSize)
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font
            ]
            
            let textSize = (emoji as NSString).size(withAttributes: attributes)
            
            // Center the emoji
            let origin = CGPoint(
                x: (renderSize.width - textSize.width) / 2,
                y: (renderSize.height - textSize.height) / 2
            )
            
            (emoji as NSString).draw(at: origin, withAttributes: attributes)
        }
        
        guard let cgImage = uiImage.cgImage else { return nil }
        return CIImage(cgImage: cgImage)
    }
}
