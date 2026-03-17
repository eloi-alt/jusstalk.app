// TextDetector.swift
// Cloaky
//
// Text detection and OCR using Vision Framework.
// Detects sensitive text: license plates, phone numbers, emails, addresses.

import Foundation
import Vision
import CoreImage

// MARK: - TextDetector

/// Detects and classifies sensitive text using Vision OCR
final class TextDetector: BiometricDetectorProtocol, @unchecked Sendable {
    
    // MARK: - Detection Mode
    
    enum DetectionMode {
        case sensitiveOnly
        case allText
    }
    
    private let processingQueue = DispatchQueue(
        label: "com.cloak.textDetector",
        qos: .userInitiated
    )
    
    // MARK: - Sensitive Text Patterns
    
    /// License plate patterns (various formats)
    private static let licensePlatePattern = #"[A-Z]{1,3}[\s\-]?[0-9]{1,4}[\s\-]?[A-Z]{0,3}"#
    /// Phone numbers (international)
    private static let phonePattern = #"[\+]?[\d\s\-\(\)]{10,15}"#
    /// Email addresses
    private static let emailPattern = #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#
    /// Street addresses
    private static let addressKeywords = ["street", "avenue", "road", "blvd", "boulevard", "drive",
                                           "lane", "court", "rue", "avenue", "chemin", "place",
                                           "allée", "impasse", "straße", "calle"]
    /// Social security / ID number patterns
    private static let idNumberPattern = #"\d{3}[\s\-]?\d{2}[\s\-]?\d{4}"#
    
    init() {}
    
    // MARK: - BiometricDetectorProtocol Conformance
    
    func detect(in image: CIImage) async throws -> [TextDetection] {
        return try await detect(in: image, mode: .sensitiveOnly)
    }
    
    // MARK: - Detection with Mode
    
    /// Detect text in the provided CIImage
    /// - Parameters:
    ///   - image: The CIImage to analyze
    ///   - mode: Detection mode - .sensitiveOnly for privacy-sensitive text, .allText for all text
    /// - Returns: Array of detected text regions
    func detect(in image: CIImage, mode: DetectionMode) async throws -> [TextDetection] {
        try Task.checkCancellation()
        
        let imageSize = image.extent.size
        
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                do {
                    let textRequest = VNRecognizeTextRequest()
                    textRequest.recognitionLevel = .accurate
                    textRequest.recognitionLanguages = ["en-US", "fr-FR", "de-DE", "es-ES"]
                    textRequest.usesLanguageCorrection = true
                    
                    let handler = VNImageRequestHandler(ciImage: image, options: [:])
                    try handler.perform([textRequest])
                    
                    guard let observations = textRequest.results else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    // Process and filter based on mode
                    let detections = observations.compactMap { observation -> TextDetection? in
                        guard let candidate = observation.topCandidates(1).first else { return nil }
                        
                        let text = candidate.string
                        var isSensitive = Self.isSensitiveText(text)
                        
                        switch mode {
                        case .sensitiveOnly:
                            // Only return sensitive text
                            guard isSensitive else { return nil }
                            
                        case .allText:
                            // Filter only by very low confidence (permissive)
                            if candidate.confidence < 0.1 { return nil }
                        }
                        
                        // Convert bounding box
                        let pixelBox = self.convertBoundingBox(
                            observation.boundingBox,
                            imageSize: imageSize
                        )
                        
                        #if DEBUG
                        print("DEBUG: TextDetector found: \(text) (confidence: \(candidate.confidence))")
                        #endif
                        
                        return TextDetection(
                            boundingBox: pixelBox,
                            confidence: candidate.confidence,
                            text: text,
                            isSensitive: isSensitive
                        )
                    }
                    
                    continuation.resume(returning: detections)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Sensitive Text Classification
    
    /// Determines if a text string contains sensitive information
    /// - Parameter text: The text to classify
    /// - Returns: true if text matches sensitive patterns
    static func isSensitiveText(_ text: String) -> Bool {
        let uppercased = text.uppercased()
        
        // Check license plate
        if matches(pattern: licensePlatePattern, in: uppercased) {
            return true
        }
        
        // Check phone number
        if matches(pattern: phonePattern, in: text) {
            return true
        }
        
        // Check email
        if matches(pattern: emailPattern, in: text) {
            return true
        }
        
        // Check ID numbers (SSN-like)
        if matches(pattern: idNumberPattern, in: text) {
            return true
        }
        
        // Check address keywords
        let lowercased = text.lowercased()
        for keyword in addressKeywords {
            if lowercased.contains(keyword) {
                // Also check if there's a number nearby (likely an address)
                if lowercased.range(of: #"\d+"#, options: .regularExpression) != nil {
                    return true
                }
            }
        }
        
        return false
    }
    
    // MARK: - Helpers
    
    /// Check if text matches a regex pattern
    private static func matches(pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return false
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
    
    /// Convert Vision normalized bounding box to pixel coordinates (bottom-left origin).
    /// Vision and CIImage share the same coordinate system — no Y-flip needed.
    private func convertBoundingBox(_ box: CGRect, imageSize: CGSize) -> CGRect {
        let x = box.origin.x * imageSize.width
        let y = box.origin.y * imageSize.height
        let width = box.width * imageSize.width
        let height = box.height * imageSize.height
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
