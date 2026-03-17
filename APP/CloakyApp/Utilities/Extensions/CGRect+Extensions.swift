// CGRect+Extensions.swift
// Cloaky
//
// CGRect utility extensions for coordinate manipulation.

import CoreGraphics

extension CGRect {
    
    /// Center point of the rectangle
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
    
    /// Area of the rectangle
    var area: CGFloat {
        width * height
    }
    
    /// Returns a rect padded by the given amount on all sides
    func padded(by padding: CGFloat) -> CGRect {
        CGRect(
            x: origin.x - padding,
            y: origin.y - padding,
            width: width + padding * 2,
            height: height + padding * 2
        )
    }
    
    /// Clamp rect to be within the given bounds
    func clamped(to bounds: CGRect) -> CGRect {
        let clampedX = max(bounds.minX, min(origin.x, bounds.maxX - width))
        let clampedY = max(bounds.minY, min(origin.y, bounds.maxY - height))
        let clampedWidth = min(width, bounds.width)
        let clampedHeight = min(height, bounds.height)
        return CGRect(x: clampedX, y: clampedY, width: clampedWidth, height: clampedHeight)
    }
    
    /// Check if this rect overlaps significantly with another
    func significantlyOverlaps(_ other: CGRect, threshold: CGFloat = 0.5) -> Bool {
        let intersection = self.intersection(other)
        guard !intersection.isNull else { return false }
        let overlapArea = intersection.area
        let smallerArea = min(self.area, other.area)
        return smallerArea > 0 && (overlapArea / smallerArea) > threshold
    }
}
