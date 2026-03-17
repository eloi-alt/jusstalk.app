// ProcessingStepsManager.swift
// Cloaky
//
// Manages the fixed processing steps. All features are always enabled.

import Foundation
import SwiftUI

enum DynamicProcessingStep: Int, CaseIterable, Identifiable {
    case faceDetect = 1
    case handDetect = 2
    case textDetect = 3
    case manualBrush = 4
    case export = 5
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .faceDetect: return "Face Detection"
        case .handDetect: return "Hand Detection"
        case .textDetect: return "Text Detection"
        case .manualBrush: return "Manual Brush"
        case .export: return "Export"
        }
    }
    
    var icon: String {
        switch self {
        case .faceDetect: return "face.dashed"
        case .handDetect: return "hand.raised"
        case .textDetect: return "doc.text.viewfinder"
        case .manualBrush: return "paintbrush.pointed"
        case .export: return "square.and.arrow.up"
        }
    }
}

struct ProcessingStepsManager {
    
    // Fixed order: face -> hand -> text -> brush -> export
    // All steps are always enabled
    static let allSteps: [DynamicProcessingStep] = [
        .faceDetect, .handDetect, .textDetect, .manualBrush, .export
    ]
    
    var enabledSteps: [DynamicProcessingStep] {
        Self.allSteps
    }
    
    var totalEnabledSteps: Int {
        enabledSteps.count
    }
    
    func stepIndex(for step: DynamicProcessingStep) -> Int? {
        enabledSteps.firstIndex(of: step)
    }
    
    func nextEnabledStep(after current: DynamicProcessingStep) -> DynamicProcessingStep? {
        guard let currentIndex = stepIndex(for: current) else { return nil }
        let nextIndex = currentIndex + 1
        guard nextIndex < enabledSteps.count else { return nil }
        return enabledSteps[nextIndex]
    }
    
    func previousEnabledStep(before current: DynamicProcessingStep) -> DynamicProcessingStep? {
        guard let currentIndex = stepIndex(for: current) else { return nil }
        guard currentIndex > 0 else { return nil }
        return enabledSteps[currentIndex - 1]
    }
    
    func stepProgress(_ step: DynamicProcessingStep) -> Double {
        guard let index = stepIndex(for: step), totalEnabledSteps > 0 else { return 0 }
        return Double(index + 1) / Double(totalEnabledSteps)
    }
    
    func stepNumber(_ step: DynamicProcessingStep) -> Int {
        guard let index = stepIndex(for: step) else { return 1 }
        return index + 1
    }
    
    func stepConfiguration(for step: DynamicProcessingStep) -> StepConfiguration {
        let index = stepIndex(for: step) ?? 0
        let progress = Double(index + 1) / Double(totalEnabledSteps)
        
        let isFirst = index == 0
        let isLast = index == totalEnabledSteps - 1
        
        return StepConfiguration(
            title: step.title,
            subtitle: stepSubtitle(for: step),
            icon: step.icon,
            progress: progress,
            showBack: !isFirst,
            showSkip: !isLast,
            showContinue: !isLast,
            continueButtonTitle: isLast ?
                String(localized: "button.apply.export", defaultValue: "Apply & Export") :
                String(localized: "button.continue", defaultValue: "Continue"),
            accentColor: stepAccentColor(for: step)
        )
    }
    
    private func stepSubtitle(for step: DynamicProcessingStep) -> String {
        switch step {
        case .faceDetect:
            return String(localized: "step.face.subtitle", defaultValue: "Scanning for faces in your image")
        case .handDetect:
            return String(localized: "step.hand.subtitle", defaultValue: "Scanning for hands in your image")
        case .textDetect:
            return String(localized: "step.text.subtitle", defaultValue: "Scanning for sensitive text")
        case .manualBrush:
            return String(localized: "step.brush.subtitle", defaultValue: "Fine-tune with the brush tool")
        case .export:
            return String(localized: "step.export.subtitle.metadata", defaultValue: "Review and save (metadata will be stripped)")
        }
    }
    
    private func stepAccentColor(for step: DynamicProcessingStep) -> Color {
        switch step {
        case .faceDetect: return .red
        case .handDetect: return .orange
        case .textDetect: return .blue
        case .manualBrush: return .indigo
        case .export: return .green
        }
    }
}
