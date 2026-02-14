import Foundation
import AVFoundation

class AudioService: NSObject {
    private var audioRecorder: AVAudioRecorder?

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording() throws -> URL {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .default)
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

        audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
        audioRecorder?.record()
        return audioFilename
    }

    func stopRecording() -> URL? {
        audioRecorder?.stop()
        let url = audioRecorder?.url
        audioRecorder = nil
        try? AVAudioSession.sharedInstance().setActive(false)
        return url
    }

    func getAudioDuration(url: URL) -> TimeInterval {
        let asset = AVURLAsset(url: url)
        return CMTimeGetSeconds(asset.duration)
    }

    func cleanupAudioFile(url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
