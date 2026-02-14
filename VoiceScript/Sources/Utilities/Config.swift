import Foundation

struct Config {
    static let voxtralAPIEndpoint = "https://api.mistral.ai/v1/audio/transcriptions"
    static let voxtralAPIKey = "pIqzJAM6C2J9Tn4PnTjOXd6EyEAqAeMJ"

    static var apiKey: String {
        #if DEBUG
        return voxtralAPIKey
        #else
        return KeychainManager.shared.retrieve(key: "voxtral_api_key") ?? voxtralAPIKey
        #endif
    }
}
