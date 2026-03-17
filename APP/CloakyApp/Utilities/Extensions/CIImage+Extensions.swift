// CIImage+Extensions.swift
// Cloaky
//
// Core Image extensions for optimized image processing and obfuscation.
// Provides Gaussian blur, feathered masks, noise injection, and color box overlays.

import CoreImage
import CoreGraphics
import UIKit

// MARK: - CIImage Obfuscation Extensions

extension CIImage {
    
    // MARK: - Gaussian Blur with Region
    
    /// Apply Gaussian blur to a specific region with feathered edges
    /// - Parameters:
    ///   - sigma: Blur radius (higher = more blur)
    ///   - region: Area to blur in pixel coordinates
    ///   - feather: Edge feathering radius for smooth transitions
    /// - Returns: Image with the specified region blurred
    func applyGaussianBlur(sigma: Double, region: CGRect, feather: CGFloat) -> CIImage {
        #if DEBUG
        print("DEBUG applyGaussianBlur: sigma=\(sigma), region=\(region), imageExtent=\(self.extent)")
        #endif
        
        // 1. Apply Gaussian blur to entire image
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return self }
        blurFilter.setValue(self, forKey: kCIInputImageKey)
        blurFilter.setValue(sigma, forKey: kCIInputRadiusKey)
        
        guard let blurredImage = blurFilter.outputImage else { return self }
        
        #if DEBUG
        print("DEBUG applyGaussianBlur: blurredImage extent before crop = \(blurredImage.extent)")
        #endif
        
        // Crop blurred image to original extent (blur expands bounds)
        let croppedBlur = blurredImage.cropped(to: self.extent)
        
        #if DEBUG
        print("DEBUG applyGaussianBlur: croppedBlur extent = \(croppedBlur.extent)")
        #endif
        
        // 2. Create feathered mask for the region
        let mask = CIImage.createFeatheredMask(
            region: region,
            feather: feather,
            imageSize: self.extent.size
        )
        
        #if DEBUG
        print("DEBUG applyGaussianBlur: mask extent = \(mask.extent)")
        #endif
        
        // 3. Blend blurred with original using mask
        let result = self.blended(with: croppedBlur, mask: mask)
        #if DEBUG
        print("DEBUG applyGaussianBlur: result extent = \(result.extent)")
        #endif
        
        return result
    }
    
    // MARK: - Feathered Mask Creation
    
    /// Create a feathered mask image: white in the region, black elsewhere, with soft edges
    /// - Parameters:
    ///   - region: The area to make white
    ///   - feather: Blur radius for soft edges
    ///   - imageSize: Size of the output mask
    /// - Returns: CIImage mask with feathered edges
    static func createFeatheredMask(
        region: CGRect,
        feather: CGFloat,
        imageSize: CGSize
    ) -> CIImage {
        #if DEBUG
        print("DEBUG createFeatheredMask: region=\(region), imageSize=\(imageSize)")
        #endif
        
        // Create white rectangle for the region
        let whiteImage = CIImage(color: CIColor.white)
            .cropped(to: region)
        
        #if DEBUG
        print("DEBUG createFeatheredMask: whiteImage extent = \(whiteImage.extent)")
        #endif
        
        // Create black background
        let blackImage = CIImage(color: CIColor.black)
            .cropped(to: CGRect(origin: .zero, size: imageSize))
        
        #if DEBUG
        print("DEBUG createFeatheredMask: blackImage extent = \(blackImage.extent)")
        #endif
        
        // Composite white region over black background
        guard let compositeFilter = CIFilter(name: "CISourceOverCompositing") else {
            return blackImage
        }
        compositeFilter.setValue(whiteImage, forKey: kCIInputImageKey)
        compositeFilter.setValue(blackImage, forKey: kCIInputBackgroundImageKey)
        
        guard let compositeMask = compositeFilter.outputImage else { return blackImage }
        
        #if DEBUG
        print("DEBUG createFeatheredMask: compositeMask extent = \(compositeMask.extent)")
        #endif
        
        // Apply Gaussian blur to create feathered edges
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return compositeMask }
        blurFilter.setValue(compositeMask, forKey: kCIInputImageKey)
        blurFilter.setValue(feather, forKey: kCIInputRadiusKey)
        
        guard let featheredMask = blurFilter.outputImage else { return compositeMask }
        
        #if DEBUG
        print("DEBUG createFeatheredMask: featheredMask extent before crop = \(featheredMask.extent)")
        #endif
        
        // Crop to image size (blur expands extent)
        let result = featheredMask.cropped(to: CGRect(origin: .zero, size: imageSize))
        #if DEBUG
        print("DEBUG createFeatheredMask: result extent = \(result.extent)")
        #endif
        
        return result
    }
    
    // MARK: - Blend with Mask
    
    /// Blend this image with another using a **luminance** mask.
    ///
    /// `CIBlendWithMask` uses the mask's **luminance** (not alpha) to interpolate:
    ///   result = inputImage × luminance + backgroundImage × (1 − luminance)
    ///
    /// Where the mask is white (luminance = 1) → show `image` (the effect).
    /// Where the mask is black (luminance = 0) → show `self` (the original).
    ///
    /// ⚠️ Do NOT use `CIBlendWithAlphaMask` here — the mask is made of opaque
    /// white and opaque black (both alpha = 1), so an alpha-based blend would
    /// always show the foreground and the mask would have no effect.
    ///
    /// - Parameters:
    ///   - image: The effect image (blur, color box, etc.) shown where the mask is white
    ///   - mask: Luminance mask controlling the blend (white = effect, black = original)
    /// - Returns: Blended image
    func blended(with image: CIImage, mask: CIImage) -> CIImage {
        #if DEBUG
        print("DEBUG blended: self extent=\(self.extent), image extent=\(image.extent), mask extent=\(mask.extent)")
        #endif
        
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { return self }
        blendFilter.setValue(image, forKey: kCIInputImageKey)           // foreground = effect (shown where mask is white)
        blendFilter.setValue(self, forKey: kCIInputBackgroundImageKey)  // background = original (shown where mask is black)
        blendFilter.setValue(mask, forKey: kCIInputMaskImageKey)
        
        let result = blendFilter.outputImage ?? self
        #if DEBUG
        print("DEBUG blended: result extent=\(result.extent)")
        #endif
        
        return result
    }
    
    // MARK: - Noise Injection
    
    /// Add random noise to a specific region (anti-forensic measure)
    /// - Parameters:
    ///   - intensity: Noise intensity (0.0 - 1.0)
    ///   - region: Area to add noise to
    /// - Returns: Image with noise added to the region
    func addNoise(intensity: Double, region: CGRect) -> CIImage {
        // Generate random noise
        guard let noiseFilter = CIFilter(name: "CIRandomGenerator") else { return self }
        guard let noiseImage = noiseFilter.outputImage else { return self }
        
        // Crop noise to region
        let croppedNoise = noiseImage.cropped(to: region)
        
        // Adjust noise intensity with color controls
        guard let colorFilter = CIFilter(name: "CIColorControls") else { return self }
        colorFilter.setValue(croppedNoise, forKey: kCIInputImageKey)
        colorFilter.setValue(0.0, forKey: kCIInputSaturationKey) // Grayscale noise
        colorFilter.setValue(intensity, forKey: kCIInputBrightnessKey)
        colorFilter.setValue(intensity * 2, forKey: kCIInputContrastKey)
        
        guard let adjustedNoise = colorFilter.outputImage else { return self }
        
        // Create feathered mask for subtle blending
        let mask = CIImage.createFeatheredMask(
            region: region,
            feather: 5,
            imageSize: self.extent.size
        )
        
        // Blend noise with original using soft light compositing
        guard let blendFilter = CIFilter(name: "CISoftLightBlendMode") else { return self }
        blendFilter.setValue(adjustedNoise, forKey: kCIInputImageKey)
        blendFilter.setValue(self, forKey: kCIInputBackgroundImageKey)
        
        guard let blendedNoise = blendFilter.outputImage else { return self }
        
        // Apply only in region using mask
        return self.blended(with: blendedNoise.cropped(to: self.extent), mask: mask)
    }
    
    // MARK: - Color Box Overlay
    
    /// Apply a solid color box over a specific region with feathered edges
    /// - Parameters:
    ///   - color: The solid color to apply
    ///   - region: Area to cover
    ///   - feather: Edge feathering radius
    /// - Returns: Image with color box applied
    func applyColorBox(color: CIColor, region: CGRect, feather: CGFloat) -> CIImage {
        // Create color rectangle covering the full image extent (will be masked to region)
        let colorImage = CIImage(color: color).cropped(to: self.extent)
        
        // Create feathered luminance mask (white in region, black outside)
        let mask = CIImage.createFeatheredMask(
            region: region,
            feather: feather,
            imageSize: self.extent.size
        )
        
        // Blend: show color where mask is white, original where mask is black
        return self.blended(with: colorImage, mask: mask)
    }
    
    // MARK: - Pixelation
    
    /// Apply pixelation effect to a specific region
    /// - Parameters:
    ///   - scale: Pixel block size
    ///   - region: Area to pixelate
    ///   - feather: Edge feathering radius
    /// - Returns: Image with the region pixelated
    func applyPixelation(scale: Double, region: CGRect, feather: CGFloat) -> CIImage {
        guard let pixelateFilter = CIFilter(name: "CIPixellate") else { return self }
        pixelateFilter.setValue(self, forKey: kCIInputImageKey)
        pixelateFilter.setValue(scale, forKey: kCIInputScaleKey)
        pixelateFilter.setValue(CIVector(cgPoint: CGPoint(x: region.midX, y: region.midY)),
                                forKey: kCIInputCenterKey)
        
        guard let pixelated = pixelateFilter.outputImage else { return self }
        let croppedPixelated = pixelated.cropped(to: self.extent)
        
        let mask = CIImage.createFeatheredMask(
            region: region,
            feather: feather,
            imageSize: self.extent.size
        )
        
        return self.blended(with: croppedPixelated, mask: mask)
    }
}

// MARK: - CGRect Extensions

extension CGRect {
    /// Inset rect by negative values (expand) or positive values (shrink)
    func expandedBy(dx: CGFloat, dy: CGFloat) -> CGRect {
        return insetBy(dx: -dx, dy: -dy)
    }
}
