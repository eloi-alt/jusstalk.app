import Foundation
import UIKit

@MainActor
class TranscriptionViewModel: ObservableObject {
    @Published var editedText: String
    @Published var selectedFormat: ExportFormat?
    @Published var isExporting = false
    @Published var showDownload = false
    @Published var exportedFileURL: URL?
    @Published var isEditingMode = false
    @Published var showCopiedAlert = false

    let transcription: Transcription
    let onComplete: () -> Void
    private let exportService = ExportService()
    private let lastRecordingManager = LastRecordingManager.shared

    init(transcription: Transcription, onComplete: @escaping () -> Void) {
        self.transcription = transcription
        self.editedText = transcription.text
        self.onComplete = onComplete
        
        let defaultFormatString = UserDefaults.standard.string(forKey: "defaultExportFormat") ?? "none"
        if defaultFormatString == "none" {
            self.selectedFormat = nil
        } else {
            self.selectedFormat = ExportFormat(rawValue: defaultFormatString)
        }
    }

    var hasDefaultFormat: Bool {
        selectedFormat != nil
    }

    func saveRecording() {
        let saved = SavedRecording(
            text: editedText,
            date: transcription.dateCreated,
            duration: transcription.duration
        )
        lastRecordingManager.save(saved)
    }

    func exportTranscription() async {
        guard let format = selectedFormat else { return }
        
        isExporting = true
        saveRecording()
        
        do {
            let fileURL = try await exportService.export(text: editedText, format: format, metadata: ["date": transcription.dateCreated, "duration": transcription.duration])
            exportedFileURL = fileURL
            showDownload = true
        } catch {
            print("Export failed")
        }
        isExporting = false
    }

    func copyToClipboard() {
        UIPasteboard.general.string = editedText
        showCopiedAlert = true
        saveRecording()
    }

    func shareText() -> String {
        saveRecording()
        return editedText
    }
}
