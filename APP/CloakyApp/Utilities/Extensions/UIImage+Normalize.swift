// UIImage+Normalize.swift
// Cloaky
//
// Shared utility for normalizing UIImage orientation and scale.
// Ensures pixel coordinates are unambiguous across the entire pipeline.

import UIKit

extension UIImage {
    
    /// Flattens orientation to `.up` and forces `scale = 1`
    /// so pixel coordinates are unambiguous across detection, obfuscation, and display.
    ///
    /// - Returns: A new UIImage with orientation `.up` and scale `1.0`,
    ///   or `self` if already normalized.
    func normalized() -> UIImage {
        let needsOrientationFix = imageOrientation != .up
        let needsScaleFix = scale != 1.0
        guard needsOrientationFix || needsScaleFix else { return self }
        
        // Render into a fresh bitmap at the visual pixel dimensions
        let pixelWidth = size.width * scale
        let pixelHeight = size.height * scale
        let pixelSize = CGSize(width: pixelWidth, height: pixelHeight)
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: pixelSize, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: pixelSize))
        }
    }
}
