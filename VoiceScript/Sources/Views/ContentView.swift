import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var recordingVM = RecordingViewModel()
    @State private var showSettings = false
    @State private var showTranscription = false
    @State private var showLastRecording = false
    
    private let lastRecordingManager = LastRecordingManager.shared

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()

                VStack {
                    headerBar

                    Spacer()

                    if lastRecordingManager.hasLastRecording {
                        lastRecordingCard
                    }

                    Spacer()

                    recordingButton

                    statusSection
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showTranscription) {
                if let transcription = recordingVM.currentTranscription {
                    TranscriptionView(transcription: transcription) { 
                        recordingVM.reset()
                    }
                }
            }
            .sheet(isPresented: $showLastRecording) {
                if let saved = lastRecordingManager.load() {
                    let transcription = Transcription(
                        text: saved.text,
                        duration: saved.duration
                    )
                    TranscriptionView(transcription: transcription) {
                        lastRecordingManager.clear()
                        showLastRecording = false
                    }
                }
            }
            .onChange(of: recordingVM.transcriptionComplete) { if $0 { showTranscription = true } }
        }
    }

    private var headerBar: some View {
        HStack {
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }

    private var lastRecordingCard: some View {
        Button {
            showLastRecording = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.blue)
                    Text("Continue Last Recording")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                if let saved = lastRecordingManager.load() {
                    Text(previewText(saved.text))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(formattedDate(saved.date))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    private var recordingButton: some View {
        Button { Task { await recordingVM.toggleRecording() } } label: {
            ZStack {
                Circle()
                    .fill(recordingVM.isRecording ? Color.red.opacity(0.2) : Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: recordingVM.isRecording ? "stop.circle.fill" : "mic.fill")
                    .font(.system(size: 44))
                    .foregroundColor(recordingVM.isRecording ? .red : .blue)
            }
            .scaleEffect(recordingVM.isRecording ? 1.05 : 1.0)
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        }
        .disabled(recordingVM.isProcessing)
    }

    private var statusSection: some View {
        VStack(spacing: 8) {
            Text(recordingVM.statusText)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            if recordingVM.isProcessing { ProgressView() }
            if let error = recordingVM.errorMessage {
                Text(error).font(.system(size: 14)).foregroundColor(.red)
            }
        }
        .padding(.bottom, 40)
    }

    private func previewText(_ text: String) -> String {
        let maxLength = 100
        if text.count <= maxLength {
            return text
        }
        return String(text.prefix(maxLength)) + "..."
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
