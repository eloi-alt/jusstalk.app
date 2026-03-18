import Foundation
import os.log

enum OfflineQueueError: LocalizedError {
    case queueFull
    case notPremium
    case fileSystemError
    case alreadyProcessing

    var errorDescription: String? {
        switch self {
        case .queueFull:
            return "La limite de 10 vocaux hors-ligne est atteinte"
        case .notPremium:
            return "Fonctionnalité réservée aux membres premium"
        case .fileSystemError:
            return "Impossible de sauvegarder le fichier audio"
        case .alreadyProcessing:
            return "Un traitement est déjà en cours"
        }
    }
}

@MainActor
final class OfflineQueueManager: ObservableObject {
    static let shared = OfflineQueueManager()

    static let maxPendingRecordings = 10

    @Published private(set) var pendingRecordings: [PendingRecording] = []
    @Published private(set) var isProcessingQueue: Bool = false

    private let queueFileName = "offline_queue.json"
    private let audioDirectoryName = "PendingAudios"

    private var applicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }

    var audioDirectory: URL {
        applicationSupportDirectory.appendingPathComponent(audioDirectoryName)
    }

    var queueFileURL: URL {
        applicationSupportDirectory.appendingPathComponent(queueFileName)
    }

    private init() {
        createAudioDirectoryIfNeeded()
        loadQueue()
    }

    func loadQueue() {
        guard FileManager.default.fileExists(atPath: queueFileURL.path) else {
            pendingRecordings = []
            return
        }

        do {
            let data = try Data(contentsOf: queueFileURL)
            var recordings = try JSONDecoder().decode([PendingRecording].self, from: data)

            for i in recordings.indices {
                if recordings[i].status == .processing {
                    recordings[i].status = .pending
                }
            }

            recordings.sort { $0.recordedAt < $1.recordedAt }
            pendingRecordings = recordings
        } catch {
            pendingRecordings = []
        }
    }

    func saveQueue() {
        do {
            let data = try JSONEncoder().encode(pendingRecordings)
            try data.write(to: queueFileURL, options: .atomic)

            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            var mutableURL = queueFileURL
            try mutableURL.setResourceValues(resourceValues)
        } catch {
            #if DEBUG
            print("[OfflineQueueManager] Failed to save queue: \(error)")
            #endif
        }
    }

    func createAudioDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: audioDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)

                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                var mutableURL = audioDirectory
                try mutableURL.setResourceValues(resourceValues)
            } catch {
                #if DEBUG
                print("[OfflineQueueManager] Failed to create audio directory: \(error)")
                #endif
            }
        }
    }

    func audioURL(for fileName: String) -> URL {
        audioDirectory.appendingPathComponent(fileName)
    }

    func enqueue(audioURL: URL, duration: TimeInterval, isPremium: Bool) throws -> PendingRecording {
        guard pendingRecordings.count < Self.maxPendingRecordings else {
            throw OfflineQueueError.queueFull
        }

        let fileName = "\(UUID().uuidString).m4a"
        let destinationURL = audioDirectory.appendingPathComponent(fileName)

        do {
            try FileManager.default.copyItem(at: audioURL, to: destinationURL)

            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            var mutableURL = destinationURL
            try mutableURL.setResourceValues(resourceValues)
        } catch {
            throw OfflineQueueError.fileSystemError
        }

        let pending = PendingRecording(audioFileName: fileName, duration: duration)
        pendingRecordings.append(pending)
        pendingRecordings.sort { $0.recordedAt < $1.recordedAt }
        saveQueue()

        return pending
    }

    func dequeue(id: UUID) {
        guard let index = pendingRecordings.firstIndex(where: { $0.id == id }) else { return }

        let recording = pendingRecordings[index]
        let fileURL = audioDirectory.appendingPathComponent(recording.audioFileName)

        try? FileManager.default.removeItem(at: fileURL)

        pendingRecordings.remove(at: index)
        saveQueue()
    }

    func updateStatus(id: UUID, status: PendingRecordingStatus, errorMessage: String?) {
        guard let index = pendingRecordings.firstIndex(where: { $0.id == id }) else { return }

        pendingRecordings[index].status = status
        pendingRecordings[index].errorMessage = errorMessage

        if status == .failed {
            pendingRecordings[index].retryCount += 1
        }

        saveQueue()
    }

    func setProcessingQueue(_ isProcessing: Bool) {
        isProcessingQueue = isProcessing
    }

    var remainingSlots: Int {
        Self.maxPendingRecordings - pendingRecordings.count
    }

    var hasPendingItems: Bool {
        pendingRecordings.contains { $0.status == .pending || $0.status == .failed }
    }

    var processableRecordings: [PendingRecording] {
        pendingRecordings
            .filter { $0.status == .pending || $0.status == .failed }
            .sorted { $0.recordedAt < $1.recordedAt }
    }
}
