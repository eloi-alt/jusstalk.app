// BiometricRegion.swift
// Cloaky
//
// Core data models for biometric detection results.

import Foundation
import CoreGraphics
import Vision

// MARK: - Biometric Types

/// Types of biometric data that can be detected in images
enum BiometricType: String, Codable, CaseIterable, Sendable {
    case face = "Face"
    case hand = "Hand"
    case text = "Text"
    case iris = "Iris"
    
    /// Processing priority (lower = higher priority)
    var priority: Int {
        switch self {
        case .face: return 1
        case .text: return 2
        case .hand: return 3
        case .iris: return 4
        }
    }
    
    /// Display icon (SF Symbol name)
    var iconName: String {
        switch self {
        case .face: return "face.dashed"
        case .hand: return "hand.raised"
        case .text: return "doc.text"
        case .iris: return "eye"
        }
    }
}

// MARK: - BiometricRegion Protocol

/// Protocol representing a detected biometric region in an image
protocol BiometricRegion: Identifiable {
    var id: UUID { get }
    /// Bounding box in pixel coordinates (top-left origin)
    var boundingBox: CGRect { get }
    /// Detection confidence (0.0 - 1.0)
    var confidence: Float { get }
    /// Type of biometric data
    var type: BiometricType { get }
}

// MARK: - Face Detection

/// Represents a detected face with landmarks
struct FaceDetection: BiometricRegion, Equatable {
    let id: UUID
    let boundingBox: CGRect
    let confidence: Float
    let type: BiometricType = .face

    /// Facial landmarks (eyes, nose, mouth, contour)
    let landmarks: VNFaceLandmarks2D?
    /// Head roll angle
    let roll: NSNumber?
    /// Head yaw angle
    let yaw: NSNumber?

    init(
        id: UUID = UUID(),
        boundingBox: CGRect,
        confidence: Float,
        landmarks: VNFaceLandmarks2D? = nil,
        roll: NSNumber? = nil,
        yaw: NSNumber? = nil
    ) {
        self.id = id
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.landmarks = landmarks
        self.roll = roll
        self.yaw = yaw
    }

    static func == (lhs: FaceDetection, rhs: FaceDetection) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hand Detection

/// Represents a detected hand with joint landmarks
struct HandDetection: BiometricRegion, Equatable {
    let id: UUID
    let boundingBox: CGRect
    let confidence: Float
    let type: BiometricType = .hand

    /// 21 hand joint landmarks as pixel points
    let landmarks: [String: CGPoint]
    /// Left or right hand
    let chirality: String

    init(
        id: UUID = UUID(),
        boundingBox: CGRect,
        confidence: Float,
        landmarks: [String: CGPoint] = [:],
        chirality: String = "unknown"
    ) {
        self.id = id
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.landmarks = landmarks
        self.chirality = chirality
    }

    static func == (lhs: HandDetection, rhs: HandDetection) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Text Detection

/// Represents detected sensitive text
struct TextDetection: BiometricRegion, Equatable {
    let id: UUID
    let boundingBox: CGRect
    let confidence: Float
    let type: BiometricType = .text

    /// The detected text string
    let text: String
    /// Whether the text is sensitive (license plates, phone numbers, emails, addresses)
    let isSensitive: Bool

    init(
        id: UUID = UUID(),
        boundingBox: CGRect,
        confidence: Float,
        text: String,
        isSensitive: Bool
    ) {
        self.id = id
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.text = text
        self.isSensitive = isSensitive
    }

    static func == (lhs: TextDetection, rhs: TextDetection) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Detection Results

/// Aggregated results from all biometric detectors
struct DetectionResults: Equatable {
    let faces: [FaceDetection]
    let hands: [HandDetection]
    let texts: [TextDetection]
    
    /// All detected regions sorted by priority
    var allRegions: [any BiometricRegion] {
        let all: [any BiometricRegion] = faces + hands + texts
        return all.sorted { $0.type.priority < $1.type.priority }
    }
    
    /// Total count of all detections
    var totalCount: Int {
        faces.count + hands.count + texts.count
    }
    
    /// Summary string for display
    var summary: String {
        var parts: [String] = []
        if !faces.isEmpty {
            let format = faces.count == 1 ?
                String(localized: "detection.summary.face.single", defaultValue: "%d face") :
                String(localized: "detection.summary.face.plural", defaultValue: "%d faces")
            parts.append(String(format: format, faces.count))
        }
        if !hands.isEmpty {
            let format = hands.count == 1 ?
                String(localized: "detection.summary.hand.single", defaultValue: "%d hand") :
                String(localized: "detection.summary.hand.plural", defaultValue: "%d hands")
            parts.append(String(format: format, hands.count))
        }
        if !texts.isEmpty {
            let format = texts.count == 1 ?
                String(localized: "detection.summary.text.single", defaultValue: "%d text") :
                String(localized: "detection.summary.text.plural", defaultValue: "%d texts")
            parts.append(String(format: format, texts.count))
        }
        return parts.isEmpty ? String(localized: "detection.summary.none", defaultValue: "No biometrics detected") : parts.joined(separator: ", ")
    }
    
    /// Empty results
    static let empty = DetectionResults(faces: [], hands: [], texts: [])
    
    /// Merge with another DetectionResults, combining all detections
    func mergingWith(_ other: DetectionResults) -> DetectionResults {
        return DetectionResults(
            faces: self.faces + other.faces,
            hands: self.hands + other.hands,
            texts: self.texts + other.texts
        )
    }
}

// MARK: - Detection Settings

/// Settings controlling which biometric types to detect
struct DetectionSettings {
    var detectFaces: Bool
    var detectHands: Bool
    var detectText: Bool
    var detectIris: Bool
    /// Sensitivity threshold (0.0 - 1.0). Lower = more detections
    var sensitivity: Double
    /// Text detection mode
    var textMode: TextDetector.DetectionMode
    
    static let `default` = DetectionSettings(
        detectFaces: true,
        detectHands: true,
        detectText: true,
        detectIris: false,
        sensitivity: 0.5,
        textMode: .sensitiveOnly
    )
    
    static let maskAllText = DetectionSettings(
        detectFaces: false,
        detectHands: false,
        detectText: true,
        detectIris: false,
        sensitivity: 0.5,
        textMode: .allText
    )
}
