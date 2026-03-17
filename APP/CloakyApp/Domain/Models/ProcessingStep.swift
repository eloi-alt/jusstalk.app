// ProcessingStep.swift
// Cloaky
//
// Multi-step processing workflow for image protection.
// 6 steps: Face -> Hand -> Text -> Brush -> Metadata -> Export

import SwiftUI
import UIKit

// MARK: - ProcessingStep

/// Represents each step in the image processing workflow
enum ProcessingStep: Int, Equatable, CaseIterable {
    case faceDetect = 1      // Step 1: Face detection
    case handDetect = 2      // Step 2: Hand detection
    case textDetect = 3      // Step 3: Text detection
    case manualBrush = 4     // Step 4: Manual brush editing
    case export = 5          // Step 5: Final export with before/after (metadata stripped automatically)
    
    static let totalSteps = 5
    
    var stepNumber: Int { rawValue }
    
    var next: ProcessingStep? {
        ProcessingStep(rawValue: rawValue + 1)
    }
    
    var previous: ProcessingStep? {
        ProcessingStep(rawValue: rawValue - 1)
    }
    
    var isFirst: Bool { self == .faceDetect }
    var isLast: Bool { self == .export }
}

// MARK: - ProcessingState

/// Holds the state throughout the multi-step workflow
@MainActor
class ProcessingState: ObservableObject {
    @Published var currentStep: ProcessingStep = .faceDetect
    @Published var originalImage: UIImage?
    
    // Detection results accumulated across steps
    @Published var faceDetections: [FaceDetection] = []
    @Published var handDetections: [HandDetection] = []
    @Published var textDetections: [TextDetection] = []
    
    // Processing results - intermediate images at each step
    @Published var faceBlurredImage: UIImage?       // After step 1 (faces blurred)
    @Published var handBlurredImage: UIImage?       // After step 2 (faces+hands blurred)
    @Published var textBlurredImage: UIImage?       // After step 3 (faces+hands+text blurred)
    @Published var finalProcessedImage: UIImage?    // After step 4 (all + brush)
    @Published var metadataCleanImage: UIImage?     // After step 5 (metadata stripped)
    @Published var brushStrokes: [BrushStroke] = []
    @Published var obfuscationMethod: ObfuscationMethod = .intelligentBlur
    
    // Metadata removal statistics
    @Published var removedMetadataTypes: [String] = []
    
    var pipeline: ProcessingPipeline?
    
    /// All detections combined
    var allDetections: DetectionResults {
        DetectionResults(
            faces: faceDetections,
            hands: handDetections,
            texts: textDetections
        )
    }
    
    /// Returns the image to display for the current step
    /// - Step 1: original
    /// - Step 2: faceBlurredImage (or original if nil)
    /// - Step 3: handBlurredImage (or best available)
    /// - Step 4: textBlurredImage (or best available)
    /// - Step 5: metadataCleanImage (final image with metadata stripped)
    var currentDisplayImage: UIImage? {
        switch currentStep {
        case .faceDetect:
            return originalImage
        case .handDetect:
            return faceBlurredImage ?? originalImage
        case .textDetect:
            return handBlurredImage ?? faceBlurredImage ?? originalImage
        case .manualBrush:
            return textBlurredImage ?? handBlurredImage ?? faceBlurredImage ?? originalImage
        case .export:
            return metadataCleanImage ?? finalProcessedImage ?? textBlurredImage ?? handBlurredImage ?? faceBlurredImage ?? originalImage
        }
    }
    
    func reset(with image: UIImage) {
        originalImage = image
        faceBlurredImage = nil
        handBlurredImage = nil
        textBlurredImage = nil
        finalProcessedImage = nil
        metadataCleanImage = nil
        faceDetections = []
        handDetections = []
        textDetections = []
        brushStrokes = []
        removedMetadataTypes = []
        currentStep = .faceDetect
    }
    
    func goToNext() {
        if let next = currentStep.next {
            currentStep = next
        }
    }
    
    func goToPrevious() {
        if let previous = currentStep.previous {
            currentStep = previous
        }
    }
    
    func applyFaceDetections(_ faces: [FaceDetection]) {
        self.faceDetections = faces
    }
    
    func applyHandDetections(_ hands: [HandDetection]) {
        self.handDetections = hands
    }
    
    func applyTextDetections(_ texts: [TextDetection]) {
        self.textDetections = texts
    }
    
    func applyProcessedImage(_ image: UIImage) {
        self.finalProcessedImage = image
    }
    
    func applyBrushStrokes(_ strokes: [BrushStroke]) {
        self.brushStrokes = strokes
    }
}

// MARK: - Step Configuration

/// Configuration for each step UI
struct StepConfiguration {
    let title: String
    let subtitle: String
    let icon: String
    let progress: Double
    let showBack: Bool
    let showSkip: Bool
    let showContinue: Bool
    let continueButtonTitle: String
    let accentColor: Color
}

extension ProcessingStep {
    var configuration: StepConfiguration {
        switch self {
        case .faceDetect:
            return StepConfiguration(
                title: String(localized: "step.face.title", defaultValue: "Face Detection"),
                subtitle: String(localized: "step.face.subtitle", defaultValue: "Scanning for faces in your image"),
                icon: "face.dashed",
                progress: 1.0 / Double(ProcessingStep.totalSteps),
                showBack: false,
                showSkip: true,
                showContinue: true,
                continueButtonTitle: String(localized: "button.continue", defaultValue: "Continue"),
                accentColor: .red
            )
        case .handDetect:
            return StepConfiguration(
                title: String(localized: "step.hand.title", defaultValue: "Hand Detection"),
                subtitle: String(localized: "step.hand.subtitle", defaultValue: "Scanning for hands in your image"),
                icon: "hand.raised",
                progress: 2.0 / Double(ProcessingStep.totalSteps),
                showBack: true,
                showSkip: true,
                showContinue: true,
                continueButtonTitle: String(localized: "button.continue", defaultValue: "Continue"),
                accentColor: .orange
            )
        case .textDetect:
            return StepConfiguration(
                title: String(localized: "step.text.title", defaultValue: "Text Detection"),
                subtitle: String(localized: "step.text.subtitle", defaultValue: "Scanning for sensitive text"),
                icon: "doc.text.viewfinder",
                progress: 3.0 / Double(ProcessingStep.totalSteps),
                showBack: true,
                showSkip: true,
                showContinue: true,
                continueButtonTitle: String(localized: "button.continue", defaultValue: "Continue"),
                accentColor: .blue
            )
        case .manualBrush:
            return StepConfiguration(
                title: String(localized: "step.brush.title", defaultValue: "Manual Brush"),
                subtitle: String(localized: "step.brush.subtitle", defaultValue: "Fine-tune with the brush tool"),
                icon: "paintbrush.pointed",
                progress: 4.0 / Double(ProcessingStep.totalSteps),
                showBack: true,
                showSkip: true,
                showContinue: true,
                continueButtonTitle: String(localized: "button.apply.export", defaultValue: "Apply & Export"),
                accentColor: .indigo
            )
        case .export:
            return StepConfiguration(
                title: String(localized: "step.export.title", defaultValue: "Export"),
                subtitle: String(localized: "step.export.subtitle", defaultValue: "Review and save your protected image"),
                icon: "square.and.arrow.up",
                progress: 1.0,
                showBack: true,
                showSkip: false,
                showContinue: false,
                continueButtonTitle: "",
                accentColor: .green
            )
        }
    }
}
