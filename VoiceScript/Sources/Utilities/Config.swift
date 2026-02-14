import Foundation

struct Config {
    static let voxtralAPIEndpoint = "https://api.mistral.ai/v1/audio/transcriptions"
    static let deepseekAPIEndpoint = "https://api.deepseek.com/v1/chat/completions"

    private static let voxtralAPIKey = ProcessInfo.processInfo.environment["VOXTRAL_API_KEY"] ?? ""

    private static let deepseekAPIKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] ?? ""

    static var apiKey: String {
        #if DEBUG
        return voxtralAPIKey
        #else
        return KeychainManager.shared.retrieve(key: "voxtral_api_key") ?? voxtralAPIKey
        #endif
    }

    static var deepseekKey: String {
        #if DEBUG
        return deepseekAPIKey
        #else
        return KeychainManager.shared.retrieve(key: "deepseek_api_key") ?? deepseekAPIKey
        #endif
    }
}
