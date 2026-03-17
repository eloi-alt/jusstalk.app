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
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true)

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording_\(UUID().uuidString).m4a")

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
        
        audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
        audioRecorder?.record()
        currentAudioURL = audioFilename
        return audioFilename
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
}
