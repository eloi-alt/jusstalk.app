// MetadataHandler.swift
// Cloaky
//
// Strips all sensitive EXIF/IPTC/XMP metadata from images.
// Preserves only image orientation. Supports JPEG, PNG, HEIC.

import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

// MARK: - MetadataHandler

/// Handles complete removal of sensitive image metadata.
/// Strips GPS, EXIF, IPTC, XMP, maker notes, and embedded thumbnails.
/// Only preserves image orientation.
final class MetadataHandler: @unchecked Sendable {
    
    // MARK: - Strip from Data
    
    /// Strip all metadata from image data, preserving only orientation
    /// - Parameter imageData: Raw image data (JPEG, PNG, HEIC)
    /// - Returns: Clean image data with metadata removed
    func stripMetadata(from imageData: Data) -> Data? {
        // Create image source
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return nil
        }
        
        // Get image type
        guard let type = CGImageSourceGetType(source) else {
            return nil
        }
        
        // Get the image
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        
        // Get original orientation (only metadata we preserve)
        let originalProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation = originalProperties?[kCGImagePropertyOrientation] as? Int ?? 1
        
        // Create output data
        let outputData = NSMutableData()
        
        guard let destination = CGImageDestinationCreateWithData(
            outputData as CFMutableData,
            type,
            1,
            nil
        ) else {
            return nil
        }
        
        // Only include orientation — everything else is stripped
        let cleanProperties: [CFString: Any] = [
            kCGImagePropertyOrientation: orientation,
            // Explicitly strip these metadata dictionaries
            kCGImagePropertyExifDictionary: [:] as [String: Any],
            kCGImagePropertyGPSDictionary: [:] as [String: Any],
            kCGImagePropertyIPTCDictionary: [:] as [String: Any],
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFOrientation: orientation
            ] as [CFString: Any]
        ]
        
        // Add image with clean properties
        CGImageDestinationAddImage(destination, cgImage, cleanProperties as CFDictionary)
        
        // Finalize
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return outputData as Data
    }
    
    // MARK: - Strip from UIImage
    
    /// Strip all metadata from a UIImage
    /// - Parameter image: The UIImage to clean
    /// - Returns: Clean UIImage with metadata removed, or nil on failure
    func stripMetadata(from image: UIImage) -> UIImage? {
        // Convert to JPEG data with high quality
        guard let imageData = image.jpegData(compressionQuality: 0.92) else {
            return nil
        }
        
        // Strip metadata from data
        guard let cleanData = stripMetadata(from: imageData) else {
            return nil
        }
        
        // Convert back to UIImage
        return UIImage(data: cleanData)
    }
    
    // MARK: - Metadata Analysis
    
    /// Analyze what metadata exists in image data (for display to user)
    /// - Parameter imageData: Raw image data
    /// - Returns: Dictionary of metadata categories and whether they exist
    func analyzeMetadata(in imageData: Data) -> [String: Bool] {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return [:]
        }
        
        return [
            "GPS Location": properties[kCGImagePropertyGPSDictionary] != nil,
            "EXIF Data": properties[kCGImagePropertyExifDictionary] != nil,
            "IPTC Data": properties[kCGImagePropertyIPTCDictionary] != nil,
            "TIFF Data": properties[kCGImagePropertyTIFFDictionary] != nil,
            "Camera Make": (properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any])?[kCGImagePropertyTIFFMake] != nil,
            "Thumbnail": properties[kCGImagePropertyExifDictionary] != nil
        ]
    }
    
    // MARK: - Optional: Timestamp Randomization
    
    /// Create image data with a randomized timestamp (anti-correlation)
    /// - Parameters:
    ///   - imageData: Clean image data (already stripped)
    ///   - hoursRange: Range of hours to randomize (default ±24h)
    /// - Returns: Image data with fake timestamp
    func randomizeTimestamp(in imageData: Data, hoursRange: Int = 24) -> Data? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let type = CGImageSourceGetType(source),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        
        // Generate random date within range
        let randomOffset = TimeInterval(Int.random(in: -hoursRange * 3600...hoursRange * 3600))
        let fakeDate = Date().addingTimeInterval(randomOffset)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        let fakeDateString = formatter.string(from: fakeDate)
        
        // Create output
        let outputData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            outputData as CFMutableData, type, 1, nil
        ) else { return nil }
        
        let properties: [CFString: Any] = [
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifDateTimeOriginal: fakeDateString,
                kCGImagePropertyExifDateTimeDigitized: fakeDateString
            ] as [CFString: Any]
        ]
        
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else { return nil }
        return outputData as Data
    }
}
