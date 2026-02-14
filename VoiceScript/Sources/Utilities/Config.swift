import Foundation

struct Config {
    static let voxtralAPIEndpoint = "https://api.mistral.ai/v1/audio/transcriptions"
    static let deepseekAPIEndpoint = "https://api.deepseek.com/v1/chat/completions"

    private static let envVoxtralKey = ProcessInfo.processInfo.environment["VOXTRAL_API_KEY"]
    private static let envDeepseekKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"]

    static var apiKey: String {
        return envVoxtralKey ?? "pIqzJAM6C2J9Tn4PnTjOXd6EyEAqAeMJ"
    }

    static var deepseekKey: String {
        return envDeepseekKey ?? "sk-6148e7e824b544709cccde31f6478210"
    }
}
