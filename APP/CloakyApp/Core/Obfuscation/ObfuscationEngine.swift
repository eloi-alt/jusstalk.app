// ObfuscationEngine.swift
// Cloaky
//
// Orchestrates obfuscation methods across multiple detected biometric regions.
// Processes regions sequentially (state-dependent) with progress reporting.

import Foundation
import CoreImage

// MARK: - ObfuscationMethod Enum

/// Available obfuscation methods
enum ObfuscationMethod: String, CaseIterable, Identifiable {
    case intelligentBlur
    case blackBox
    case emojiOverlay  // Disabled
    case inpainting    // v2.0 stub
    
    var id: String { rawValue }
    
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .intelligentBlur:
            return String(localized: "method.intelligent.blur", defaultValue: "Intelligent Blur")
        case .blackBox:
            return String(localized: "method.black.box", defaultValue: "Black Box")
        case .emojiOverlay:
            return String(localized: "method.emoji.overlay", defaultValue: "Emoji Overlay")
        case .inpainting:
            return String(localized: "method.inpainting", defaultValue: "Inpainting")
        }
    }
    
    /// Human-readable description
    var description: String {
        switch self {
        case .intelligentBlur:
            return String(localized: "method.desc.intelligent.blur", defaultValue: "Variable blur with natural appearance")
        case .blackBox:
            return String(localized: "method.desc.black.box", defaultValue: "Solid black censoring (maximum protection)")
        case .emojiOverlay:
            return String(localized: "method.desc.emoji.overlay", defaultValue: "Fun emoji covers")
        case .inpainting:
            return String(localized: "method.desc.inpainting", defaultValue: "AI-powered context fill (coming soon)")
        }
    }
    
    /// SF Symbol icon name
    var iconName: String {
        switch self {
        case .intelligentBlur: return "eye.slash"
        case .blackBox: return "square.fill"
        case .emojiOverlay: return "face.smiling"
        case .inpainting: return "wand.and.stars"
        }
    }
    
    /// Whether this method is available in current version
    var isAvailable: Bool {
        self == .intelligentBlur || self == .blackBox
    }
}

// MARK: - ObfuscationEngine

/// Central orchestrator for applying obfuscation to detected biometric regions.
/// Processes regions sequentially (since each step modifies the image state)
/// and reports progress granularly per region.
final class ObfuscationEngine: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let intelligentBlur: IntelligentBlur
    private let blackBox: BlackBoxMethod
    private let emojiOverlay: EmojiOverlay
    
    // MARK: - Init
    
    init() {
        self.intelligentBlur = IntelligentBlur()
        self.blackBox = BlackBoxMethod()
        self.emojiOverlay = EmojiOverlay()
    }
    
    // MARK: - Obfuscation
    
    /// Apply obfuscation to all given regions on the image
    /// - Parameters:
    ///   - image: Source CIImage to process
    ///   - regions: Detected biometric regions to obfuscate
    ///   - method: The obfuscation method to use
    ///   - settings: Obfuscation intensity and behavior settings
    ///   - progressHandler: Callback reporting progress (0.0 - 1.0)
    /// - Returns: Processed CIImage with all regions obfuscated
    func obfuscate(
        _ image: CIImage,
        regions: [any BiometricRegion],
        method: ObfuscationMethod,
        settings: ObfuscationSettings = .default,
        progressHandler: ((Double) -> Void)? = nil
    ) async -> CIImage {
        guard !regions.isEmpty else {
            progressHandler?(1.0)
            return image
        }
        
        // Sort regions by priority (faces first, then text, then hands)
        let sortedRegions = regions.sorted { $0.type.priority < $1.type.priority }
        
        // Select method implementation
        let methodImpl: ObfuscationMethodProtocol = selectMethod(method)
        
        // Process regions sequentially (each step depends on previous state)
        var result = image
        let total = Double(sortedRegions.count)
        
        for (index, region) in sortedRegions.enumerated() {
            // Check for cancellation between regions
            guard !Task.isCancelled else { break }
            
            // Apply obfuscation
            result = methodImpl.apply(to: result, region: region, settings: settings)
            
            // Report progress
            progressHandler?(Double(index + 1) / total)
            
            // Yield to allow cancellation and UI updates
            await Task.yield()
        }
        
        return result
    }
    
    /// Apply obfuscation with per-region method override
    /// Useful when user wants different methods for different region types
    func obfuscateWithPerRegionMethod(
        _ image: CIImage,
        regions: [(region: any BiometricRegion, method: ObfuscationMethod)],
        settings: ObfuscationSettings = .default,
        progressHandler: ((Double) -> Void)? = nil
    ) async -> CIImage {
        guard !regions.isEmpty else {
            progressHandler?(1.0)
            return image
        }
        
        var result = image
        let total = Double(regions.count)
        
        for (index, item) in regions.enumerated() {
            guard !Task.isCancelled else { break }
            
            let methodImpl = selectMethod(item.method)
            result = methodImpl.apply(to: result, region: item.region, settings: settings)
            
            progressHandler?(Double(index + 1) / total)
            await Task.yield()
        }
        
        return result
    }
    
    // MARK: - Method Selection
    
    private func selectMethod(_ method: ObfuscationMethod) -> ObfuscationMethodProtocol {
        switch method {
        case .intelligentBlur:
            return intelligentBlur
        case .blackBox:
            return blackBox
        case .emojiOverlay:
            return emojiOverlay
        case .inpainting:
            return intelligentBlur // Fallback until v2.0
        }
    }
}
