// ExportStepView.swift
// Cloaky
//
// Step 5: Final export with Before/After comparison.
// Save/Share/New Image actions with metadata already stripped.

import SwiftUI
import Photos

// MARK: - ExportStepView

struct ExportStepView: View {
    let originalImage: UIImage
    let processedImage: UIImage
    @ObservedObject var processingState: ProcessingState
    var onNewImage: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @State private var comparisonSplitRatio: Double = 0.5
    @State private var isSaving = false
    @State private var showSaveConfirmation = false
    @State private var showShareSheet = false
    
    private let step = DynamicProcessingStep.export
    private let stepsManager = ProcessingStepsManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // Dynamic Progress indicator
            DynamicStepProgressBar(
                currentStep: step,
                stepsManager: stepsManager
            )
            
            // Before/After slider
            BeforeAfterSlider(
                beforeImage: originalImage,
                afterImage: processedImage,
                sliderPosition: $comparisonSplitRatio
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .onAppear {
                if !showSaveConfirmation && !isSaving {
                    saveImage()
                }
            }
            .padding(.vertical, 8)
            
            Spacer()
            
            // Success message
            if showSaveConfirmation {
                successBanner
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Action buttons
            actionButtons
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .background(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: -2)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [processedImage])
        }
    }
    
    // MARK: - Success Banner
    
    private var successBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(.green)
            
            Text(String(localized: "step.export.saved", defaultValue: "Image saved to Photos"))
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.green.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Save button
            Button {
                saveImage()
            } label: {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.down.to.line.circle.fill")
                    }
                    
                    Text(String(localized: "step.save", defaultValue: "Save to Photos"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isSaving ? Color.gray : Color.indigo)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isSaving)
            
            // Share button
            Button {
                showShareSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text(String(localized: "step.export.share", defaultValue: "Share"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.tertiarySystemBackground))
                .foregroundColor(.primary)
                .cornerRadius(12)
            }
            
            // New image button
            Button {
                onNewImage?()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                    Text(String(localized: "step.export.new", defaultValue: "New Image"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.clear)
                .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Actions
    
    private func saveImage() {
        guard !isSaving else { return }
        
        isSaving = true
        
        Task {
            do {
                // Always save the processed image (blurs applied + metadata stripped)
                let imageToSave = processedImage
                
                try await PHPhotoLibrary.shared().performChanges {
                    let request = PHAssetCreationRequest.forAsset()
                    if let data = imageToSave.jpegData(compressionQuality: 1.0) {
                        request.addResource(with: .photo, data: data, options: nil)
                    }
                }
                
                // Success feedback
                await MainActor.run {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showSaveConfirmation = true
                    }
                    
                    // Hide confirmation after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showSaveConfirmation = false
                        }
                    }
                    
                    isSaving = false
                }
                
            } catch {
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}
