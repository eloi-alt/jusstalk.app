// BlackBoxMethod.swift
// Cloaky
//
// Simple and effective: solid black rectangle over biometric regions.
// 99% protection effectiveness.

import Foundation
import CoreImage

// MARK: - BlackBoxMethod

/// Applies a solid black rectangle over detected biometric regions.
/// The simplest and most effective obfuscation method (99% protection).
final class BlackBoxMethod: ObfuscationMethodProtocol {
    
    func apply(to image: CIImage, region: any BiometricRegion, settings: ObfuscationSettings) -> CIImage {
        let blackColor = CIColor(red: 0, green: 0, blue: 0, alpha: 1)
        return image.applyColorBox(
            color: blackColor,
            region: region.boundingBox,
            feather: 0 // Sharp, clean edges — no feathering for black boxes
        )
    }
}
