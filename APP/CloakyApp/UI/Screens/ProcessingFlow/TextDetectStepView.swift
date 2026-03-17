// TextDetectStepView.swift
// Cloaky
//
// Step 3: Text detection only. Shows detected text regions with back/skip/continue options.

import SwiftUI
import CoreImage

// MARK: - TextDetectStepView

struct TextDetectStepView: View {
    let inputImage: UIImage
    let pipeline: ProcessingPipeline
    @ObservedObject var processingState: ProcessingState
    var onBack: (() -> Void)?
    var onSkip: (() -> Void)?
    var onContinue: (() -> Void)?
    
    @StateObject private var viewModel: EditorViewModel
    @State private var isProcessing = false
    @State private var canvasDisplaySize: CGSize = .zero
    
    private let step = DynamicProcessingStep.textDetect
    private let stepsManager = ProcessingStepsManager()
    
    /// The image to display: hand-blurred from step 2, or face-blurred, or original
    private var displayImage: UIImage {
        processingState.handBlurredImage 
            ?? processingState.faceBlurredImage 
            ?? inputImage
    }
    
    init(inputImage: UIImage, pipeline: ProcessingPipeline, processingState: ProcessingState, onBack: (() -> Void)? = nil, onSkip: (() -> Void)? = nil, onContinue: (() -> Void)? = nil) {
        self.inputImage = inputImage
        self.pipeline = pipeline
        self.processingState = processingState
        self.onBack = onBack
        self.onSkip = onSkip
        self.onContinue = onContinue
        self._viewModel = StateObject(wrappedValue: EditorViewModel(pipeline: pipeline))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Dynamic Progress bar
            DynamicStepProgressBar(
                currentStep: step,
                stepsManager: stepsManager
            )
            
            // Image canvas with text detections
            imageCanvas
                .frame(maxHeight: .infinity)
            
            // Detection status
            detectionStatusBar
            
            // Method selector
            if let detections = viewModel.detections, !detections.texts.isEmpty {
                methodSelector
            }
            
            // Navigation: Back + Skip + Continue
            DynamicStepNavigationButtons(
                config: stepsManager.stepConfiguration(for: step),
                isProcessing: isProcessing || viewModel.isDetecting,
                onBack: onBack,
                onSkip: {
                    // Skip: pass current image forward without text blur
                    let currentImage = displayImage
                    processingState.textBlurredImage = currentImage
                    processingState.finalProcessedImage = currentImage
                    onSkip?()
                },
                onContinue: {
                    applyAndContinue()
                }
            )
        }
        .onAppear {
            viewModel.loadImage(inputImage)
            if viewModel.detections == nil {
                viewModel.startTextOnlyDetection()
            }
        }
    }
    
    // MARK: - Actions
    
    private func applyAndContinue() {
        guard !isProcessing else { return }
        
        // Save text detections to state
        if let detections = viewModel.detections {
            processingState.applyTextDetections(detections.texts)
        }
        
        // If texts detected, apply blur before continuing
        let texts = viewModel.detections?.texts ?? []
        if !texts.isEmpty {
            isProcessing = true
            
            Task {
                do {
                    let normalizedImage = displayImage.normalized()
                    guard let ciImage = CIImage(image: normalizedImage) else {
                        throw ProcessingError.imageConversionFailed
                    }
                    
                    var result: CIImage = ciImage
                    
                    // Apply obfuscation to text
                    let textRegions: [any BiometricRegion] = texts
                    result = await pipeline.obfuscationEngine.obfuscate(
                        result,
                        regions: textRegions,
                        method: viewModel.selectedMethod,
                        settings: viewModel.obfuscationSettings
                    ) { _ in }
                    
                    // Render to UIImage
                    guard let cgImage = pipeline.ciContext.createCGImage(result, from: result.extent) else {
                        throw ProcessingError.imageConversionFailed
                    }
                    let blurredImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
                    
                    await MainActor.run {
                        processingState.textBlurredImage = blurredImage
                        processingState.finalProcessedImage = blurredImage
                        isProcessing = false
                        onContinue?()
                    }
                    
                } catch {
                    await MainActor.run {
                        isProcessing = false
                        // Even if blur fails, pass through
                        processingState.textBlurredImage = displayImage
                        processingState.finalProcessedImage = displayImage
                        onContinue?()
                    }
                }
            }
        } else {
            // No text detected - pass current image forward
            processingState.textBlurredImage = displayImage
            processingState.finalProcessedImage = displayImage
            onContinue?()
        }
    }
    
    // MARK: - Image Canvas
    
    private var imageCanvas: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemGroupedBackground)
                
                Image(uiImage: displayImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .overlay(
                        GeometryReader { imgGeo in
                            Color.clear.onAppear {
                                canvasDisplaySize = imgGeo.size
                            }
                        }
                    )
                
                // Text detection overlays
                if let detections = viewModel.detections, !detections.texts.isEmpty {
                    let textOnly = DetectionResults(
                        faces: [],
                        hands: [],
                        texts: detections.texts
                    )
                    DetectionOverlay(
                        detections: textOnly,
                        imageSize: displayImage.size,
                        selectedRegions: Set(detections.texts.map(\.id)),
                        deselectedRegions: Set<UUID>(),
                        onToggleRegion: { _ in },
                        allowToggle: false
                    )
                }
                
                // Loading overlay
                if viewModel.isDetecting {
                    detectionLoadingOverlay
                }
            }
        }
    }
    
    // MARK: - Detection Loading Overlay
    
    private var detectionLoadingOverlay: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                
                Text(String(localized: "step.text.analyzing", defaultValue: "Analyzing..."))
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(Int(viewModel.detectionProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Detection Status Bar
    
    private var detectionStatusBar: some View {
        Group {
            if let detections = viewModel.detections {
                let textCount = detections.texts.count
                HStack(spacing: 10) {
                    Image(systemName: textCount > 0 ? "checkmark.circle.fill" : "checkmark.shield.fill")
                        .foregroundColor(.green)
                        .font(.callout)
                    
                    if textCount == 0 {
                        Text(String(localized: "step.text.none", defaultValue: "No text detected"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    } else {
                        Text("\(textCount) text region\(textCount > 1 ? "s" : "") detected")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    if textCount > 0 {
                        Text("\(textCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(textCount > 0 ? Color(.secondarySystemGroupedBackground) : Color.green.opacity(0.08))
            }
        }
    }
    
    // MARK: - Method Selector
    
    private var methodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ObfuscationMethod.allCases.filter(\.isAvailable)) { method in
                    MethodChip(
                        method: method,
                        isSelected: viewModel.selectedMethod == method,
                        onTap: { viewModel.selectedMethod = method }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
}
