import Foundation

struct Config {
    static let voxtralAPIEndpoint = "https://api.mistral.ai/v1/audio/transcriptions"
    static let deepseekAPIEndpoint = "https://api.deepseek.com/v1/chat/completions"

    private static let envVoxtralKey = ProcessInfo.processInfo.environment["VOXTRAL_API_KEY"]
    private static let envDeepseekKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"]

    private static let voxtralAPIKey = envVoxtralKey ?? ""
    private static let deepseekAPIKey = envDeepseekKey ?? ""

    static var apiKey: String {
        #if DEBUG
        if !voxtralAPIKey.isEmpty {
            return voxtralAPIKey
        }
        return loadDebugKey(named: "voxtral_api_key") ?? "pIqzJAM6C2J9Tn4PnTjOXd6EyEAqAeMJ"
        #else
        return KeychainManager.shared.retrieve(key: "voxtral_api_key") ?? voxtralAPIKey
        #endif
    }

    static var deepseekKey: String {
        #if DEBUG
        if !deepseekAPIKey.isEmpty {
            return deepseekAPIKey
        }
        return loadDebugKey(named: "deepseek_api_key") ?? "sk-6148e7e824b544709cccde31f6478210"
        #else
        return KeychainManager.shared.retrieve(key: "deepseek_api_key") ?? deepseekAPIKey
        #endif
    }

    #if DEBUG
    private static func loadDebugKey(named key: String) -> String? {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let docPath = paths.first else { return nil }
        let keyPath = docPath.appendingPathComponent(".env_\(key)")
        return try? String(contentsOf: keyPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    #endif
}
