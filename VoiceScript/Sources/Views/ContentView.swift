import SwiftUI

struct ContentView: View {
    @StateObject private var recordingVM = RecordingViewModel()
    @State private var showSettings = false
    @State private var showTranscription = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                VStack {
                    HStack {
                        Spacer()
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }

                    Spacer()

                    VStack(spacing: 30) {
                        Button { Task { await recordingVM.toggleRecording() } } label: {
                            ZStack {
                                Circle()
                                    .fill(recordingVM.isRecording ? Color.red.opacity(0.2) : Color.blue.opacity(0.1))
                                    .frame(width: 120, height: 120)
                                Image(systemName: recordingVM.isRecording ? "stop.circle.fill" : "mic.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(recordingVM.isRecording ? .red : .blue)
                            }
                            .scaleEffect(recordingVM.isRecording ? 1.05 : 1.0)
                            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                        }
                        .disabled(recordingVM.isProcessing)

                        VStack(spacing: 8) {
                            Text(recordingVM.statusText)
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                            if recordingVM.isProcessing { ProgressView() }
                            if let error = recordingVM.errorMessage {
                                Text(error).font(.system(size: 14)).foregroundColor(.red)
                            }
                        }
                    }

                    Spacer()
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showTranscription) {
                if let transcription = recordingVM.currentTranscription {
                    TranscriptionView(transcription: transcription) { recordingVM.reset() }
                }
            }
            .onChange(of: recordingVM.transcriptionComplete) { if $0 { showTranscription = true } }
        }
    }
}
