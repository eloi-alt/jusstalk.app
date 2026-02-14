import Foundation

struct Transcription: Identifiable {
    let id: UUID
    var text: String
    let dateCreated: Date
    let audioURL: URL?
    let duration: TimeInterval
    let language: String?

    init(text: String, audioURL: URL? = nil, duration: TimeInterval = 0, language: String? = nil) {
        self.id = UUID()
        self.text = text
        self.dateCreated = Date()
        self.audioURL = audioURL
        self.duration = duration
        self.language = language
    }
}

enum ExportFormat: String, CaseIterable {
    case txt = "TXT"
    case md = "MD"
    case json = "JSON"
    case pdf = "PDF"
    case docx = "DOCX"
    case html = "HTML"
    case rtf = "RTF"
    case csv = "CSV"

    var fileExtension: String {
        self.rawValue.lowercased()
    }
}

enum AudioQuality: String, CaseIterable {
    case standard = "standard"
    case high = "high"

    var sampleRate: Double {
        switch self {
        case .standard: return 16000.0
        case .high: return 44100.0
        }
    }
}
