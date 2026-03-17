// IntelligentBlur.swift
// Cloaky
//
// Intelligent blur with maximum security settings.
// Implements multi-pass Gaussian blur with noise injection for anti-forensics.
// Targets <5% restorability with sigma 35-60, multi-pass, and 2-4% noise.

import Foundation
import CoreImage
import Vision
import UIKit

// MARK: - ObfuscationMethodProtocol

protocol ObfuscationMethodProtocol {
    func apply(to image: CIImage, region: any BiometricRegion, settings: ObfuscationSettings) -> CIImage
}

// MARK: - ObfuscationSettings

struct ObfuscationSettings: Sendable {
    var intensity: Double
    var preserveAspect: Bool
    var addNoise: Bool
    var featherRadius: CGFloat
    var multiPassCount: Int
    var noiseLevel: Double
    
    static let `default` = ObfuscationSettings(
        intensity: 1.0,
        preserveAspect: true,
        addNoise: true,
        featherRadius: 0,
        multiPassCount: 2,
        noiseLevel: 0.025
    )
    
    static let maximum = ObfuscationSettings(
        intensity: 1.0,
        preserveAspect: true,
        addNoise: true,
        featherRadius: 0,
        multiPassCount: 3,
        noiseLevel: 0.04
    )
    
    static let subtle = ObfuscationSettings(
        intensity: 0.8,
        preserveAspect: true,
        addNoise: true,
        featherRadius: 0,
        multiPassCount: 2,
        noiseLevel: 0.02
    )
}

// MARK: - IntelligentBlur

final class IntelligentBlur: ObfuscationMethodProtocol {
    
    // Sigma ratios based on feature type (as percentage of region width)
    // Face: 0.13-0.15, Iris: 0.20-0.25, Text: 0.30-0.40
    private struct BlurConfig {
        static let faceRatio: Double = 0.14      // 14% of face width
        static let irisRatio: Double = 0.22      // 22% of iris region
        static let handRatio: Double = 0.12      // 12% of hand width
        static let textRatio: Double = 0.35      // 35% of text width
        
        // Minimum sigma for security (σ < 20 is dangerous)
        static let minSigma: Double = 35.0
        static let maxSigma: Double = 70.0
    }
    
    func apply(to image: CIImage, region: any BiometricRegion, settings: ObfuscationSettings) -> CIImage {
        let regionWidth = region.boundingBox.width
        let regionHeight = region.boundingBox.height
        
        #if DEBUG
        print("DEBUG IntelligentBlur: region=\(region.boundingBox), width=\(regionWidth), height=\(regionHeight), type=\(region.type)")
        #endif
        
        // Calculate base sigma from region width
        let baseSigma: Double
        switch region.type {
        case .face:
            baseSigma = max(regionWidth * BlurConfig.faceRatio, BlurConfig.minSigma)
        case .iris:
            baseSigma = max(regionWidth * BlurConfig.irisRatio, 20.0)
        case .hand:
            baseSigma = max(regionWidth * BlurConfig.handRatio, 25.0)
        case .text:
            baseSigma = max(regionWidth * BlurConfig.textRatio, 30.0)
        }
        
        // Apply intensity multiplier (0.8 - 1.2 range)
        let targetSigma = min(baseSigma * settings.intensity, BlurConfig.maxSigma)
        
        #if DEBUG
        print("DEBUG IntelligentBlur: baseSigma=\(baseSigma), targetSigma=\(targetSigma)")
        #endif
        
        // Multi-pass blur for equivalent sigma
        // σ_eq = √(σ₁² + σ₂² + ... + σₙ²) = σ × √N
        // For N passes with equal sigma: σ_pass = targetSigma / √N
        let passCount = max(settings.multiPassCount, 2)
        let sigmaPerPass = targetSigma / sqrt(Double(passCount))
        
        var result = image
        
        // Apply multiple blur passes
        for i in 0..<passCount {
            // Add spatial variation (±15%)
            let variation = Double.random(in: 0.85...1.15)
            let passSigma = sigmaPerPass * variation
            
            #if DEBUG
            print("DEBUG IntelligentBlur: pass \(i), sigma=\(passSigma)")
            #endif
            
            result = result.applyGaussianBlur(
                sigma: passSigma,
                region: region.boundingBox,
                feather: settings.featherRadius
            )
        }
        
        // Add anti-forensic noise AFTER blur (CRITICAL)
        if settings.addNoise {
            let noiseIntensity = settings.noiseLevel * Double.random(in: 0.8...1.2)
            result = result.addNoise(intensity: noiseIntensity, region: region.boundingBox)
        }
        
        return result
    }
}
