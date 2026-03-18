import Foundation

@MainActor
final class OfflineQueueProcessor {
    static let shared = OfflineQueueProcessor()

    private let queueManager = OfflineQueueManager.shared
    private let transcriptionService = TranscriptionService()
    private let networkMonitor = NetworkMonitor.shared
    private let historyManager = TranscriptionHistoryManager.shared

    var onTranscriptionCompleted: ((Transcription) -> Void)?

    private init() {}

    func processQueue() async {
        guard !queueManager.isProcessingQueue else { return }
        guard networkMonitor.isConnected else { return }
        guard queueManager.hasPendingItems else { return }

        queueManager.setProcessingQueue(true)

        let processable = queueManager.processableRecordings

        for recording in processable {
            queueManager.updateStatus(id: recording.id, status: .processing, errorMessage: nil)

            let audioURL = queueManager.audioURL(for: recording.audioFileName)

            guard FileManager.default.fileExists(atPath: audioURL.path) else {
                queueManager.dequeue(id: recording.id)
                continue
            }

            do {
                let transcribedText = try await transcriptionService.transcribe(audioURL: audioURL)
                let trimmedText = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)

                if trimmedText.isEmpty {
                    queueManager.updateStatus(id: recording.id, status: .failed, errorMessage: "Transcription vide")
                    if recording.retryCount >= 3 {
                        queueManager.dequeue(id: recording.id)
                    }
                    continue
                }

                let transcription = Transcription(
                    text: trimmedText,
                    audioURL: audioURL,
                    duration: recording.duration
                )

                TranscriptionHistoryManager.shared.add(transcription)
                onTranscriptionCompleted?(transcription)
                queueManager.dequeue(id: recording.id)

            } catch let error as URLError {
                if error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
                    queueManager.updateStatus(id: recording.id, status: .pending, errorMessage: "Pas de connexion")
                    break
                } else {
                    queueManager.updateStatus(id: recording.id, status: .failed, errorMessage: error.localizedDescription)
                    if recording.retryCount >= 3 {
                        queueManager.dequeue(id: recording.id)
                    }
                }
            } catch let error as TranscriptionError {
                queueManager.updateStatus(id: recording.id, status: .failed, errorMessage: error.localizedDescription ?? "Erreur de transcription")
                if recording.retryCount >= 3 {
                    queueManager.dequeue(id: recording.id)
                }
            } catch {
                queueManager.updateStatus(id: recording.id, status: .failed, errorMessage: error.localizedDescription)
                if recording.retryCount >= 3 {
                    queueManager.dequeue(id: recording.id)
                }
            }
        }

        queueManager.setProcessingQueue(false)
    }
}
