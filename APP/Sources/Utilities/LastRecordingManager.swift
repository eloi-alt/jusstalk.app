import Foundation

struct SavedRecording: Codable {
    let text: String
    let date: Date
    let duration: TimeInterval
}

class LastRecordingManager {
    static let shared = LastRecordingManager()
    private let userDefaultsKey = "lastRecording"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {}

    func save(_ recording: SavedRecording) {
        do {
            let data = try encoder.encode(recording)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Failed to save recording: \(error)")
        }
    }

    func load() -> SavedRecording? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return nil
        }
        do {
            return try decoder.decode(SavedRecording.self, from: data)
        } catch {
            print("Failed to load recording: \(error)")
            return nil
        }
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    var hasLastRecording: Bool {
        load() != nil
    }
}
