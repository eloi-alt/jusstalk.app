import Foundation

@MainActor
class RecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var statusText = "Tap to record"
    @Published var errorMessage: String?
    @Published var currentTranscription: Transcription?
    @Published var transcriptionComplete = false

    private let audioService = AudioService()
    private let transcriptionService = TranscriptionService()

    func toggleRecording() async {
        if isRecording {
            await stopRecording()
        } else {
            await startRecording()
        }
    }

    private func startRecording() async {
        errorMessage = nil
        let hasPermission = await audioService.requestMicrophonePermission()
        guard hasPermission else {
            errorMessage = "Microphone access required"
            return
        }

        do {
            _ = try audioService.startRecording()
            isRecording = true
            statusText = "Recording... Tap to stop"
        } catch {
            errorMessage = "Failed to start recording"
        }
    }

    private func stopRecording() async {
        isRecording = false
        statusText = "Transcribing..."
        isProcessing = true

        guard let audioURL = audioService.stopRecording() else {
            errorMessage = "Failed to save recording"
            isProcessing = false
            statusText = "Tap to record"
            return
        }

        do {
            let transcribedText = try await transcriptionService.transcribe(audioURL: audioURL)
            let duration = audioService.getAudioDuration(url: audioURL)
            currentTranscription = Transcription(text: transcribedText, audioURL: audioURL, duration: duration)
            transcriptionComplete = true
            statusText = "Tap to record"
        } catch {
            errorMessage = "Transcription failed"
            statusText = "Tap to record"
        }

        isProcessing = false
        audioService.cleanupAudioFile(url: audioURL)
    }

    func reset() {
        currentTranscription = nil
        transcriptionComplete = false
        errorMessage = nil
        statusText = "Tap to record"
    }
}
