import Foundation

struct Config {
    static let voxtralAPIEndpoint = "https://api.mistral.ai/v1/audio/transcriptions"
    static let deepseekAPIEndpoint = "https://api.deepseek.com/v1/chat/completions"

    private static let envVoxtralKey = ProcessInfo.processInfo.environment["VOXTRAL_API_KEY"]
    private static let envDeepseekKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"]

    static var apiKey: String {
        return envVoxtralKey ?? "REDACTED_MISTRAL"
    }

    static var deepseekKey: String {
        return envDeepseekKey ?? "REDACTED_DEEPSEEK"
    }
}
