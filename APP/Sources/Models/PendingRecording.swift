import Foundation

enum PendingRecordingStatus: String, Codable {
    case pending
    case processing
    case failed
}

struct PendingRecording: Identifiable, Codable {
    let id: UUID
    let audioFileName: String
    let duration: TimeInterval
    let recordedAt: Date
    var status: PendingRecordingStatus
    var retryCount: Int
    var errorMessage: String?

    init(audioFileName: String, duration: TimeInterval) {
        self.id = UUID()
        self.audioFileName = audioFileName
        self.duration = duration
        self.recordedAt = Date()
        self.status = .pending
        self.retryCount = 0
        self.errorMessage = nil
    }
}
