import SwiftUI

struct TranscriptionView: View {
    @StateObject private var viewModel: TranscriptionViewModel
    @Environment(\.dismiss) private var dismiss

    init(transcription: Transcription, onComplete: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: TranscriptionViewModel(transcription: transcription, onComplete: onComplete))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextEditor(text: $viewModel.editedText)
                    .font(.system(size: 16))
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .frame(minHeight: 200)
                    .padding(.horizontal)

                HStack {
                    Text("\(viewModel.editedText.count) characters")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 24)

                if !viewModel.hasDefaultFormat {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Export Format").font(.system(size: 14, weight: .semibold)).padding(.horizontal, 24)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(ExportFormat.allCases, id: \.self) { format in
                                    Button { viewModel.selectedFormat = format } label: {
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
                Spacer()
            }
            .navigationTitle("Review Transcription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss(); viewModel.onComplete() }
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
            .onAppear {
                if viewModel.hasDefaultFormat {
                    Task {
                        await viewModel.exportTranscription()
                    }
                }
            }
        }
    }
}
