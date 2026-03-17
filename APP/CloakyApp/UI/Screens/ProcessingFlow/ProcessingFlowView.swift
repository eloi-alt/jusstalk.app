// ProcessingFlowView.swift
// Cloaky
//
// Main container view for the image processing workflow.
// Fixed order: Face -> Hand -> Text -> Brush -> Export.
// All features are always enabled.

import SwiftUI

// MARK: - ProcessingFlowView

struct ProcessingFlowView: View {
    let inputImage: UIImage
    let pipeline: ProcessingPipeline
    var onComplete: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var processingState = ProcessingState()
    @State private var showExitConfirmation = false
    @State private var currentDynamicStep: DynamicProcessingStep = .faceDetect
    
    private let stepsManager = ProcessingStepsManager()
    
    var body: some View {
        ZStack {
            switch currentDynamicStep {
            case .faceDetect:
                FaceDetectStepView(
                    inputImage: inputImage,
                    pipeline: pipeline,
                    processingState: processingState,
                    onBack: { goToPreviousStep() },
                    onSkip: { goToNextStep() },
                    onContinue: { goToNextStep() }
                )
                
            case .handDetect:
                HandDetectStepView(
                    inputImage: inputImage,
                    pipeline: pipeline,
                    processingState: processingState,
                    onBack: { goToPreviousStep() },
                    onSkip: { goToNextStep() },
                    onContinue: { goToNextStep() }
                )
                
            case .textDetect:
                TextDetectStepView(
                    inputImage: inputImage,
                    pipeline: pipeline,
                    processingState: processingState,
                    onBack: { goToPreviousStep() },
                    onSkip: { goToNextStep() },
                    onContinue: { goToNextStep() }
                )
                
            case .manualBrush:
                ManualBrushStepView(
                    inputImage: inputImage,
                    pipeline: pipeline,
                    processingState: processingState,
                    onBack: { goToPreviousStep() },
                    onSkip: { goToNextStep() },
                    onContinue: { goToNextStep() }
                )
                
            case .export:
                ExportStepView(
                    originalImage: inputImage,
                    processedImage: processingState.metadataCleanImage
                        ?? processingState.finalProcessedImage
                        ?? processingState.textBlurredImage
                        ?? processingState.handBlurredImage
                        ?? processingState.faceBlurredImage
                        ?? inputImage,
                    processingState: processingState,
                    onNewImage: {
                        dismiss()
                        onComplete?()
                    }
                )
            }
        }
        .navigationTitle(stepsManager.stepConfiguration(for: currentDynamicStep).title)
        .navigationBarTitleDisplayMode(.inline)

        .confirmationDialog(
            String(localized: "flow.exit.title", defaultValue: "Exit?"),
            isPresented: $showExitConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "flow.exit.confirm", defaultValue: "Exit without saving"), role: .destructive) {
                dismiss()
            }
            Button(String(localized: "flow.exit.cancel", defaultValue: "Continue editing"), role: .cancel) {}
        } message: {
            Text(String(localized: "flow.exit.message", defaultValue: "Your progress will be lost."))
        }
        .onAppear {
            processingState.reset(with: inputImage)
            processingState.pipeline = pipeline
            currentDynamicStep = .faceDetect
        }
    }
    
    private func goToNextStep() {
        if let nextStep = stepsManager.nextEnabledStep(after: currentDynamicStep) {
            currentDynamicStep = nextStep
        }
    }
    
    private func goToPreviousStep() {
        if let previousStep = stepsManager.previousEnabledStep(before: currentDynamicStep) {
            currentDynamicStep = previousStep
        }
    }
}

// MARK: - Progress Bar (Dynamic)

struct DynamicStepProgressBar: View {
    let currentStep: DynamicProcessingStep
    let stepsManager: ProcessingStepsManager
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(stepsManager.enabledSteps) { step in
                    let stepIndex = stepsManager.stepIndex(for: step) ?? 0
                    let currentIndex = stepsManager.stepIndex(for: currentStep) ?? 0
                    
                    ZStack {
                        Circle()
                            .fill(stepIndex <= currentIndex ? Color.indigo : Color(.systemGray5))
                            .frame(width: 10, height: 10)
                            .shadow(
                                color: stepIndex <= currentIndex ? Color.indigo.opacity(0.4) : Color.clear,
                                radius: 2,
                                x: 0,
                                y: 1
                            )
                    }
                    .frame(width: 24, height: 24)
                    
                    if stepIndex < stepsManager.totalEnabledSteps - 1 {
                        ZStack {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 3)
                            
                            if stepIndex < currentIndex {
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.indigo, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(height: 3)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            HStack {
                Label {
                    Text(String(format: String(localized: "step.indicator", defaultValue: "Step %d of %d"), 
                                stepsManager.stepNumber(currentStep), 
                                stepsManager.totalEnabledSteps))
                        .font(.system(size: 13, weight: .medium))
                } icon: {
                    Image(systemName: "number.circle.fill")
                        .foregroundColor(.indigo)
                }
                .foregroundColor(.primary)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 14)
        .background(
            Color(.systemBackground)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(.separator))
                        .opacity(0.5),
                    alignment: .bottom
                )
        )
    }
}

// MARK: - Step Navigation Buttons (Dynamic)

struct DynamicStepNavigationButtons: View {
    let config: StepConfiguration
    let isProcessing: Bool
    let onBack: (() -> Void)?
    let onSkip: (() -> Void)?
    let onContinue: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    if config.showBack, let onBack = onBack {
                        Button(action: onBack) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(String(localized: "button.back", defaultValue: "Back"))
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundColor(.primary)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(isProcessing)
                        .opacity(isProcessing ? 0.5 : 1.0)
                    }
                    
                    if config.showSkip, let onSkip = onSkip {
                        Button(action: onSkip) {
                            Text(String(localized: "button.skip", defaultValue: "Skip"))
                                .font(.system(size: 15, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(isProcessing)
                        .opacity(isProcessing ? 0.5 : 1.0)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if config.showContinue, let onContinue = onContinue {
                    Button(action: onContinue) {
                        HStack(spacing: 6) {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                            }
                            
                            Text(config.continueButtonTitle)
                                .font(.system(size: 16, weight: .bold))
                            
                            if !isProcessing {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isProcessing ? Color.gray : config.accentColor)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isProcessing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 8)
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - Button Styles

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}
