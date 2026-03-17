// ProcessingView.swift
// Cloaky
//
// Processing screen with animated progress bar, step labels, and blurred preview.
// Handles both auto-detected regions and manual brush strokes.

import SwiftUI
import UIKit

// MARK: - ProcessingView

struct ProcessingView: View {
    
    let image: UIImage
    let regions: [any BiometricRegion]
    let brushStrokes: [BrushStroke]
    let brushIntensity: Double
    let canvasDisplaySize: CGSize
    let method: ObfuscationMethod
    let settings: ObfuscationSettings
    let pipeline: ProcessingPipeline
    
    @StateObject private var viewModel: ProcessingViewModel
    @State private var navigateToPreview = false
    @State private var showCheckmark = false
    
    init(
        image: UIImage,
        regions: [any BiometricRegion],
        brushStrokes: [BrushStroke] = [],
        brushIntensity: Double = 0.8,
        canvasDisplaySize: CGSize = .zero,
        method: ObfuscationMethod,
        settings: ObfuscationSettings,
        pipeline: ProcessingPipeline
    ) {
        self.image = image
        self.regions = regions
        self.brushStrokes = brushStrokes
        self.brushIntensity = brushIntensity
        self.canvasDisplaySize = canvasDisplaySize
        self.method = method
        self.settings = settings
        self.pipeline = pipeline
        self._viewModel = StateObject(wrappedValue: ProcessingViewModel(pipeline: pipeline))
    }
    
    var body: some View {
        ZStack {
            // Image d'arrière-plan nette (pas de flou)
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .ignoresSafeArea()
            
            // Overlay de traitement minimaliste
            if !viewModel.isComplete && viewModel.error == nil {
                processingOverlay
            }
            
            // Contenu central
            VStack(spacing: 24) {
                Spacer()
                
                if viewModel.isComplete {
                    completionView
                } else if viewModel.error != nil {
                    errorView
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle(String(localized: "processing.title", defaultValue: "Processing"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isProcessing)
        // Navigation Link (always present)
        .background(
            NavigationLink(
                destination: previewDestination,
                isActive: $navigateToPreview
            ) {
                EmptyView()
            }
            .hidden()
        )
        .onAppear {
            navigateToPreview = false
            startProcessing()
        }
    }
    
    // MARK: - Processing Overlay
    
    private var processingOverlay: some View {
        VStack {
            Spacer()
            
            // Indicateur avec barre de progression linéaire
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    // Cercle de progression animé
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 3)
                            .frame(width: 40, height: 40)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(viewModel.processingProgress))
                            .stroke(Color.indigo, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.2), value: viewModel.processingProgress)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.currentStep)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        // Barre de progression linéaire
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 4)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(
                                        LinearGradient(
                                            colors: [.indigo, .purple, .pink],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * CGFloat(viewModel.processingProgress), height: 4)
                                    .animation(.linear(duration: 0.3), value: viewModel.processingProgress)
                            }
                        }
                        .frame(height: 4)
                        
                        HStack {
                            Text("\(Int(viewModel.processingProgress * 100))%")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            // Message dynamique selon la progression
                            if viewModel.processingProgress < 0.3 {
                                Text(String(localized: "processing.initializing", defaultValue: "Initializing..."))
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                            } else if viewModel.processingProgress < 0.7 {
                                Text(String(localized: "processing.in.progress", defaultValue: "Processing..."))
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                            } else {
                                Text(String(localized: "processing.finalizing", defaultValue: "Finalizing..."))
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                    
                    Spacer()
                }
                
                // Bouton annuler
                Button(action: {
                    viewModel.cancel()
                }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text(String(localized: "cancel", defaultValue: "Cancel"))
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Preview Destination
    
    @ViewBuilder
    private var previewDestination: some View {
        if let processed = viewModel.processedImage {
            PreviewView(
                originalImage: image,
                processedImage: processed,
                detectionResults: viewModel.detectionResults,
                processingTime: viewModel.processingTime
            )
        } else if viewModel.error != nil {
            // CRITICAL: No processed image due to error - show error state
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(systemName: "xmark.octagon.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text(String(localized: "processing.failed", defaultValue: "FAILED"))
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(String(localized: "processing.preparing", defaultValue: "Preparing preview…"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        } else {
            // Loading fallback — never show a blank/black screen
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                    Text(String(localized: "processing.preparing", defaultValue: "Preparing preview…"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    

    
    // MARK: - Completion View
    
    private var completionView: some View {
        VStack(spacing: 20) {
            // Success checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
                .scaleEffect(showCheckmark ? 1.0 : 0.0)
                .opacity(showCheckmark ? 1.0 : 0.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCheckmark)
                .onAppear { showCheckmark = true }
            
            Text(String(localized: "processing.completed", defaultValue: "Completed"))
                .font(.title3)
                .fontWeight(.bold)
            
            Text(String(format: String(localized: "processing.time", defaultValue: "Processed in %.1fs"), viewModel.processingTime))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button {
                navigateToPreview = true
            } label: {
                HStack {
                    Image(systemName: "eye")
                    Text(String(localized: "processing.view.result", defaultValue: "View Result"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.indigo)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal, 40)
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)
            
            Text(String(localized: "processing.failed", defaultValue: "FAILED"))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.red)
            
            // Display detailed error from viewModel.currentStep
            Text(viewModel.currentStep.contains("ERROR") ? viewModel.currentStep : "ERROR: \(viewModel.error?.localizedDescription ?? "Unknown failure")")
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            
            HStack(spacing: 12) {
                Button {
                    startProcessing()
                } label: {
                    HStack {
                    Image(systemName: "arrow.clockwise")
                    Text(String(localized: "processing.retry", defaultValue: "Retry"))
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.indigo)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                // Back button to return to editor
                Button {
                    // Dismiss this view - will need to use presentationMode or similar
                } label: {
                    HStack {
                    Image(systemName: "arrow.left")
                    Text(String(localized: "processing.back", defaultValue: "Back"))
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
            }
        }
        .padding(28)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal, 32)
        .overlay(
            // Red border to emphasize critical error
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red.opacity(0.5), lineWidth: 2)
                .padding(.horizontal, 32)
        )
    }
    
    // MARK: - Start Processing
    
    private func startProcessing() {
        Task {
            await viewModel.process(
                image: image,
                regions: regions,
                brushStrokes: brushStrokes,
                brushIntensity: brushIntensity,
                canvasDisplaySize: canvasDisplaySize,
                method: method,
                settings: settings
            )
        }
    }
}
