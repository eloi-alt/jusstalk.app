import Foundation
import AVFoundation

class AudioService: NSObject {
    private var audioRecorder: AVAudioRecorder?
    private var currentAudioURL: URL?

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording() throws -> URL {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try audioSession.setActive(true)

        let audioURL = AudioService.temporaryAudioURL()
        AudioService.markAsExcludedFromBackup(url: audioURL)
        AudioService.setFileProtection(url: audioURL)

        let qualityString = UserDefaults.standard.string(forKey: "audioQuality") ?? "standard"
        let quality = AudioQuality(rawValue: qualityString) ?? .standard

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: quality.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        if audioRecorder != nil {
            audioRecorder?.stop()
            audioRecorder = nil
        }
        
        audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
        audioRecorder?.record()
        currentAudioURL = audioURL
        return audioURL
    }

    func stopRecording() -> URL? {
        audioRecorder?.stop()
        let url = currentAudioURL
        audioRecorder = nil
        currentAudioURL = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return url
    }

    func getAudioDuration(url: URL) -> TimeInterval {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return 0
        }
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        return duration.isNaN ? 0 : duration
    }

    func cleanupAudioFile(url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func temporaryAudioURL() -> URL {
        let cachesPath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let audioDir = cachesPath[0].appendingPathComponent("AudioTemp", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
        
        return audioDir.appendingPathComponent("recording_\(UUID().uuidString).m4a")
    }

    static func markAsExcludedFromBackup(url: URL) {
        var urlToUpdate = url
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? urlToUpdate.setResourceValues(resourceValues)
    }

    static func setFileProtection(url: URL) {
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
    }

    static func cleanupAudioCacheDirectory() {
        let cachesPath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let audioDir = cachesPath[0].appendingPathComponent("AudioTemp")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: audioDir,
            includingPropertiesForKeys: nil
        ) else { return }
        
        for file in files where file.pathExtension == "m4a" {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
