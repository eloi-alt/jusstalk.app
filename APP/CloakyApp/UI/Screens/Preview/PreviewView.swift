// PreviewView.swift
// Cloaky
//
// Preview screen with before/after slider, protection stats, and export options.

import SwiftUI

// MARK: - PreviewView

struct PreviewView: View {
    
    let originalImage: UIImage
    let processedImage: UIImage
    let detectionResults: DetectionResults?
    let processingTime: TimeInterval
    
    @StateObject private var viewModel = PreviewViewModel()
    @State private var sliderPosition: Double = 0.5
    @State private var showShareSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Before/After comparison
            BeforeAfterSlider(
                beforeImage: originalImage,
                afterImage: processedImage,
                sliderPosition: $sliderPosition
            )
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            // Stats card
            statsCard
            
            // Export buttons
            exportButtons
        }
        .navigationTitle(String(localized: "preview.title", defaultValue: "Preview"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .onAppear {
            viewModel.configure(
                original: originalImage,
                processed: processedImage,
                results: detectionResults,
                processingTime: processingTime
            )
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityViewController(activityItems: [processedImage])
        }
        .alert(isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Alert(
                title: Text(String(localized: "error", defaultValue: "Error")),
                message: Text(viewModel.errorMessage ?? ""),
                dismissButton: .default(Text(String(localized: "ok", defaultValue: "OK"))) {
                    viewModel.errorMessage = nil
                }
            )
        }
    }
    
    // MARK: - Stats Card
    
    private var statsCard: some View {
        VStack(spacing: 8) {
            ForEach(viewModel.protectionSummary.indices, id: \.self) { index in
                let item = viewModel.protectionSummary[index]
                HStack(spacing: 10) {
                    Image(systemName: item.icon)
                        .foregroundColor(.green)
                        .font(.callout)
                        .frame(width: 20)
                    
                    Text(item.text)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    // MARK: - Export Buttons
    
    private var exportButtons: some View {
        HStack(spacing: 12) {
            // Save to Photos
            Button {
                Task {
                    await viewModel.saveToPhotos()
                }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else if viewModel.isSaved {
                        Image(systemName: "checkmark")
                    } else {
                        Image(systemName: "arrow.down.circle")
                    }
                    Text(viewModel.isSaved ? String(localized: "preview.saved", defaultValue: "Saved") : String(localized: "preview.save", defaultValue: "Save"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(viewModel.isSaved ? Color.green : Color.indigo)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.isSaving)
            
            // Share
            Button {
                showShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.body)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                    .background(Color(.tertiarySystemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
}

// MARK: - Activity View Controller (Share Sheet)

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
