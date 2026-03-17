// Route.swift
// Cloaky
//
// Navigation routes for the app flow.

import Foundation
import UIKit

// MARK: - Route

/// Navigation routes for app flow
enum Route: Hashable {
    case gallery
    case editor(image: UIImage)
    case processing(image: UIImage, regions: [RegionInfo], method: ObfuscationMethod)
    case preview(original: UIImage, processed: UIImage, results: DetectionResults)
    
    // Hashable conformance for NavigationStack
    func hash(into hasher: inout Hasher) {
        switch self {
        case .gallery:
            hasher.combine("gallery")
        case .editor:
            hasher.combine("editor")
        case .processing:
            hasher.combine("processing")
        case .preview:
            hasher.combine("preview")
        }
    }
    
    static func == (lhs: Route, rhs: Route) -> Bool {
        switch (lhs, rhs) {
        case (.gallery, .gallery):
            return true
        case (.editor, .editor):
            return true
        case (.processing, .processing):
            return true
        case (.preview, .preview):
            return true
        default:
            return false
        }
    }
}

// MARK: - RegionInfo (Hashable wrapper)

/// Lightweight info about a biometric region for navigation
struct RegionInfo: Hashable, Identifiable {
    let id: UUID
    let boundingBox: CGRect
    let confidence: Float
    let type: BiometricType
    
    init(from region: any BiometricRegion) {
        self.id = region.id
        self.boundingBox = region.boundingBox
        self.confidence = region.confidence
        self.type = region.type
    }
}

// MARK: - Alert Item

/// Model for presenting alerts
struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let dismissButtonTitle: String
    
    init(title: String, message: String, dismissButtonTitle: String = "OK") {
        self.title = title
        self.message = message
        self.dismissButtonTitle = dismissButtonTitle
    }
    
    static func error(_ error: Error) -> AlertItem {
        AlertItem(
            title: "Error",
            message: error.localizedDescription
        )
    }
}
