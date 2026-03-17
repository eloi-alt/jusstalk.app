// ManualBrushStepView.swift
// Cloaky
//
// Step 4: Manual brush editing with back/skip/apply & export options.

import SwiftUI
import CoreImage

// MARK: - ManualBrushStepView

struct ManualBrushStepView: View {
    let inputImage: UIImage
    let pipeline: ProcessingPipeline
    @ObservedObject var processingState: ProcessingState
    var onBack: (() -> Void)?
    var onSkip: (() -> Void)?
    var onContinue: (() -> Void)?
    
    @StateObject private var viewModel: EditorViewModel
    @State private var isProcessing = false
    @State private var canvasDisplaySize: CGSize = .zero
    
    private let step = DynamicProcessingStep.manualBrush
    private let stepsManager = ProcessingStepsManager()
    
    /// The image to display: text-blurred from step 3, or best available
    private var displayImage: UIImage {
        processingState.textBlurredImage 
            ?? processingState.handBlurredImage 
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
            
            // Brush canvas
            brushCanvas
                .frame(maxHeight: .infinity)
            
            // Brush controls
            brushControls
            
            // Navigation: Back + Skip + Apply & Export
            DynamicStepNavigationButtons(
                config: stepsManager.stepConfiguration(for: step),
                isProcessing: isProcessing,
                onBack: onBack,
                onSkip: {
                    skipBrushAndContinue()
                },
                onContinue: {
                    applyBrushAndContinue()
                }
            )
        }
        .onAppear {
            viewModel.loadImage(displayImage)
            viewModel.brushStrokes = processingState.brushStrokes
        }
    }
    
    // MARK: - Brush Canvas
    
    private var brushCanvas: some View {
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
                
                BrushCanvasView(
                    originalImage: displayImage,
                    brushSettings: viewModel.brushSettings,
                    strokes: $viewModel.brushStrokes,
                    undoStack: $viewModel.brushUndoStack,
                    canvasDisplaySize: $canvasDisplaySize,
                    rebuildTrigger: $viewModel.brushRebuildTrigger
                )
            }
        }
    }
    
    // MARK: - Brush Controls
    
    private var brushControls: some View {
        VStack(spacing: 0) {
            // Brush size slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Brush Size")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(Int(viewModel.brushSettings.brushSize))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                
                Slider(
                    value: $viewModel.brushSettings.brushSize,
                    in: 10...100,
                    step: 1
                )
                .tint(.indigo)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
            
            // Blur intensity slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Blur Intensity")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(Int(viewModel.brushSettings.blurIntensity * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                
                Slider(
                    value: $viewModel.brushSettings.blurIntensity,
                    in: 0.1...1.0,
                    step: 0.05
                )
                .tint(.indigo)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Action buttons
            HStack(spacing: 16) {
                Button {
                    viewModel.undoBrushStroke()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.brushUndoStack.isEmpty)
                
                Button {
                    viewModel.clearBrushStrokes()
                } label: {
                    Label("Clear", systemImage: "trash")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(viewModel.brushStrokes.isEmpty)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Actions
    
    private func applyBrushAndContinue() {
        guard !isProcessing else { return }
        
        isProcessing = true
        
        Task {
            do {
                let processedImage: UIImage
                
                if viewModel.brushStrokes.isEmpty {
                    processedImage = displayImage
                } else {
                    let baseImage = displayImage
                    let normalizedImage = baseImage.normalized()
                    guard let ciImage = CIImage(image: normalizedImage) else {
                        throw ProcessingError.imageConversionFailed
                    }
                    
                    var result: CIImage = ciImage
                    
                    result = pipeline.applyBrushBlur(
                        to: result,
                        strokes: viewModel.brushStrokes,
                        intensity: viewModel.brushSettings.blurIntensity,
                        imageSize: normalizedImage.size,
                        displaySize: canvasDisplaySize
                    )
                    
                    guard let cgImage = pipeline.ciContext.createCGImage(result, from: result.extent) else {
                        throw ProcessingError.imageConversionFailed
                    }
                    processedImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
                }
                
                // Strip metadata (always enabled)
                let cleanImage = pipeline.metadataHandler.stripMetadata(from: processedImage) ?? processedImage
                
                if let imageData = processedImage.jpegData(compressionQuality: 0.92) {
                    let metadataInfo = pipeline.metadataHandler.analyzeMetadata(in: imageData)
                    let removedTypes = metadataInfo.filter { $0.value }.map { $0.key }
                    
                    await MainActor.run {
                        processingState.removedMetadataTypes = removedTypes
                    }
                }
                
                await MainActor.run {
                    processingState.applyBrushStrokes(viewModel.brushStrokes)
                    processingState.finalProcessedImage = processedImage
                    processingState.metadataCleanImage = cleanImage
                    isProcessing = false
                    onContinue?()
                }
                
            } catch {
                await MainActor.run {
                    isProcessing = false
                    // Even on error, pass through
                    processingState.finalProcessedImage = displayImage
                    processingState.metadataCleanImage = displayImage
                    onContinue?()
                }
            }
        }
    }
    
    private func skipBrushAndContinue() {
        guard !isProcessing else { return }
        
        isProcessing = true
        
        Task {
            // Strip metadata (always enabled)
            let cleanImage = pipeline.metadataHandler.stripMetadata(from: displayImage) ?? displayImage
            
            if let imageData = displayImage.jpegData(compressionQuality: 0.92) {
                let metadataInfo = pipeline.metadataHandler.analyzeMetadata(in: imageData)
                let removedTypes = metadataInfo.filter { $0.value }.map { $0.key }
                
                await MainActor.run {
                    processingState.removedMetadataTypes = removedTypes
                }
            }
            
            await MainActor.run {
                processingState.finalProcessedImage = displayImage
                processingState.metadataCleanImage = cleanImage
                isProcessing = false
                onContinue?()
            }
        }
    }
}
