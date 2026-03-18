import Foundation
import SwiftUI

@MainActor
final class TranscriptionHistoryManager: ObservableObject {
    static let shared = TranscriptionHistoryManager()

    @Published private(set) var transcriptions: [Transcription] = []

    private let storageKey = "transcription_history"
    private let maxStored = 10

    private init() {
        loadTranscriptions()
    }

    func add(_ transcription: Transcription) {
        transcriptions.insert(transcription, at: 0)
        if transcriptions.count > maxStored {
            transcriptions = Array(transcriptions.prefix(maxStored))
        }
        saveTranscriptions()
    }

    func delete(_ transcription: Transcription) {
        transcriptions.removeAll { $0.id == transcription.id }
        saveTranscriptions()
    }

    func delete(at offsets: IndexSet) {
        transcriptions.remove(atOffsets: offsets)
        saveTranscriptions()
    }

    private func loadTranscriptions() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        transcriptions = (try? JSONDecoder().decode([Transcription].self, from: data)) ?? []
    }

    private func saveTranscriptions() {
        guard let data = try? JSONEncoder().encode(transcriptions) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func clear() {
        transcriptions = []
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
