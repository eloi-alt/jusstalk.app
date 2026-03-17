import SwiftUI
import UIKit

struct TranscriptionView: View {
    @StateObject private var viewModel: TranscriptionViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextEditorFocused: Bool
    @State private var showShareSheet = false
    @State private var shareText: String = ""

    init(transcription: Transcription, onComplete: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: TranscriptionViewModel(transcription: transcription, onComplete: onComplete))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                contentArea
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                characterCountBar

                if !viewModel.hasDefaultFormat {
                    formatSelector
                }

                Spacer()

                quickActionsBar
            }
            .navigationTitle("Transcription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { 
                        viewModel.saveRecording()
                        dismiss(); viewModel.onComplete() 
                    }
                }
                ToolbarItem(placement: .principal) {
                    modeToggleButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") { Task { await viewModel.exportTranscription() } }
                        .disabled(viewModel.editedText.isEmpty || viewModel.isExporting || viewModel.selectedFormat == nil)
                }
            }
            .sheet(isPresented: $viewModel.showDownload) {
                if let fileURL = viewModel.exportedFileURL {
                    DownloadView(fileURL: fileURL, format: viewModel.selectedFormat ?? .txt) {
                        dismiss(); viewModel.onComplete()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [shareText])
            }
            .alert("Copied!", isPresented: $viewModel.showCopiedAlert) {
                Button("OK", role: .cancel) { }
            }
            .onAppear {
                if viewModel.hasDefaultFormat {
                    Task {
                        await viewModel.exportTranscription()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        if viewModel.isEditingMode {
            editingView
        } else {
            readingView
        }
    }

    private var readingView: some View {
        ScrollView {
            Text(viewModel.editedText)
                .font(.body)
                .foregroundColor(.primary)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private var editingView: some View {
        TextEditor(text: $viewModel.editedText)
            .font(.body)
            .padding(12)
            .focused($isTextEditorFocused)
            .onTapGesture {
                if viewModel.isEditingMode {
                    isTextEditorFocused = true
                }
            }
    }

    private var modeToggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.isEditingMode.toggle()
                if !viewModel.isEditingMode {
                    isTextEditorFocused = false
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: viewModel.isEditingMode ? "eye.fill" : "pencil")
                Text(viewModel.isEditingMode ? "Reading" : "Editing")
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray5))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }

    private var characterCountBar: some View {
        HStack {
            Text("\(viewModel.editedText.count) characters")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            if viewModel.isEditingMode {
                Button("Hide Keyboard") {
                    isTextEditorFocused = false
                }
                .font(.system(size: 12))
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }

    private var formatSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Format")
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Button {
                            viewModel.selectedFormat = format
                            viewModel.saveRecording()
                        } label: {
                            Text(format.rawValue)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(viewModel.selectedFormat == format ? Color.blue : Color(.systemGray5))
                                .foregroundColor(viewModel.selectedFormat == format ? .white : .primary)
                                .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private var quickActionsBar: some View {
        HStack(spacing: 20) {
            actionButton(icon: "doc.on.doc", label: "Copy") {
                viewModel.copyToClipboard()
            }

            actionButton(icon: "square.and.arrow.up", label: "Share") {
                shareText = viewModel.shareText()
                showShareSheet = true
            }

            actionButton(icon: "arrow.clockwise", label: "Restart") {
                viewModel.saveRecording()
                dismiss()
                viewModel.onComplete()
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .background(Color(.systemBackground))
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 11))
            }
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
