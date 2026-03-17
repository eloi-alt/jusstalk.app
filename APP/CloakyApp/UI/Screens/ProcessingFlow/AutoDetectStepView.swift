// AutoDetectStepView.swift -> FaceDetectStepView.swift
// Cloaky
//
// Step 1: Face detection only. Shows detected faces with skip/continue options.

import SwiftUI
import CoreImage

// MARK: - FaceDetectStepView

struct FaceDetectStepView: View {
    let inputImage: UIImage
    let pipeline: ProcessingPipeline
    @ObservedObject var processingState: ProcessingState
    var onBack: (() -> Void)?
    var onSkip: (() -> Void)?
    var onContinue: (() -> Void)?
    
    @StateObject private var viewModel: EditorViewModel
    @State private var isProcessing = false
    @State private var canvasDisplaySize: CGSize = .zero
    
    private let step = DynamicProcessingStep.faceDetect
    private let stepsManager = ProcessingStepsManager()
    
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
            
            // Image canvas with face detections
            imageCanvas
                .frame(maxHeight: .infinity)
            
            // Detection status
            detectionStatusBar
            
            // Method selector
            if let detections = viewModel.detections, !detections.faces.isEmpty {
                methodSelector
            }
            
            // Navigation with dynamic buttons
            DynamicStepNavigationButtons(
                config: stepsManager.stepConfiguration(for: step),
                isProcessing: isProcessing || viewModel.isDetecting,
                onBack: onBack,
                onSkip: {
                    // Skip: pass original image forward without blur
                    processingState.faceBlurredImage = inputImage
                    processingState.finalProcessedImage = inputImage
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
                viewModel.startFaceOnlyDetection()
            }
        }
    }
    
    // MARK: - Actions
    
    private func applyAndContinue() {
        guard !isProcessing else { return }
        
        // Save face detections to state
        if let detections = viewModel.detections {
            processingState.applyFaceDetections(detections.faces)
        }
        processingState.obfuscationMethod = viewModel.selectedMethod
        
        // If faces detected, apply blur before continuing
        let faces = viewModel.detections?.faces ?? []
        if !faces.isEmpty {
            isProcessing = true
            
            Task {
                do {
                    let normalizedImage = inputImage.normalized()
                    guard let ciImage = CIImage(image: normalizedImage) else {
                        throw ProcessingError.imageConversionFailed
                    }
                    
                    var result: CIImage = ciImage
                    
                    // Apply obfuscation to faces
                    let faceRegions: [any BiometricRegion] = faces
                    result = await pipeline.obfuscationEngine.obfuscate(
                        result,
                        regions: faceRegions,
                        method: viewModel.selectedMethod,
                        settings: viewModel.obfuscationSettings
                    ) { _ in }
                    
                    // Render to UIImage
                    guard let cgImage = pipeline.ciContext.createCGImage(result, from: result.extent) else {
                        throw ProcessingError.imageConversionFailed
                    }
                    let blurredImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
                    
                    // Save the blurred image to state
                    await MainActor.run {
                        processingState.faceBlurredImage = blurredImage
                        processingState.finalProcessedImage = blurredImage
                        isProcessing = false
                        onContinue?()
                    }
                    
                } catch {
                    await MainActor.run {
                        isProcessing = false
                        // Even if blur fails, still continue
                        processingState.faceBlurredImage = inputImage
                        processingState.finalProcessedImage = inputImage
                        onContinue?()
                    }
                }
            }
        } else {
            // No faces detected - pass original forward
            processingState.faceBlurredImage = inputImage
            processingState.finalProcessedImage = inputImage
            onContinue?()
        }
    }
    
    // MARK: - Image Canvas
    
    private var imageCanvas: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemGroupedBackground)
                
                Image(uiImage: inputImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .overlay(
                        GeometryReader { imgGeo in
                            Color.clear.onAppear {
                                canvasDisplaySize = imgGeo.size
                            }
                        }
                    )
                
                // Face detection overlays only
                if let detections = viewModel.detections, !detections.faces.isEmpty {
                    let faceOnly = DetectionResults(
                        faces: detections.faces,
                        hands: [],
                        texts: []
                    )
                    DetectionOverlay(
                        detections: faceOnly,
                        imageSize: inputImage.size,
                        selectedRegions: Set(detections.faces.map(\.id)),
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
                
                Text(String(localized: "step.face.analyzing", defaultValue: "Analyzing..."))
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
                let faceCount = detections.faces.count
                HStack(spacing: 10) {
                    Image(systemName: faceCount > 0 ? "checkmark.circle.fill" : "checkmark.shield.fill")
                        .foregroundColor(.green)
                        .font(.callout)
                    
                    if faceCount == 0 {
                        Text(String(localized: "step.face.none", defaultValue: "No faces detected"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    } else {
                        Text("\(faceCount) face\(faceCount > 1 ? "s" : "") detected")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    if faceCount > 0 {
                        Text("\(faceCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(faceCount > 0 ? Color(.secondarySystemGroupedBackground) : Color.green.opacity(0.08))
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
