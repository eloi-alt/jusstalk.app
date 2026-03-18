import Foundation

enum Config {
    static let mistralAPIEndpoint = "https://api.mistral.ai/v1/audio/transcriptions"
    static let deepseekAPIEndpoint = "https://api.deepseek.com/v1/chat/completions"

    static var mistralAPIKey: String {
        if let key = KeychainManager.shared.retrieve(key: "mistral_api_key"),
           !key.isEmpty {
            return key
        }
        
        #if DEBUG
        let buildKey = Bundle.main.object(forInfoDictionaryKey: "MISTRAL_API_KEY") as? String
        if let k = buildKey, !k.isEmpty, k != "$(MISTRAL_API_KEY)" {
            return k
        }
        print("[Config] WARNING: MISTRAL_API_KEY not configured. Transcription will fail.")
        return ""
        #else
        if let key = Bundle.main.object(forInfoDictionaryKey: "MISTRAL_API_KEY") as? String,
           !key.isEmpty,
           key != "$(MISTRAL_API_KEY)" {
            return key
        }
        return ""
        #endif
    }

    static var deepseekAPIKey: String {
        if let key = KeychainManager.shared.retrieve(key: "deepseek_api_key"),
           !key.isEmpty {
            return key
        }
        
        #if DEBUG
        let buildKey = Bundle.main.object(forInfoDictionaryKey: "DEEPSEEK_API_KEY") as? String
        if let k = buildKey, !k.isEmpty, k != "$(DEEPSEEK_API_KEY)" {
            return k
        }
        print("[Config] WARNING: DEEPSEEK_API_KEY not configured.")
        return ""
        #else
        if let key = Bundle.main.object(forInfoDictionaryKey: "DEEPSEEK_API_KEY") as? String,
           !key.isEmpty,
           key != "$(DEEPSEEK_API_KEY)" {
            return key
        }
        return ""
        #endif
    }

    static func storeAPIKey(_ key: String, service: APIKeyService) {
        KeychainManager.shared.store(key: service.keychainKey, value: key)
    }

    enum APIKeyService {
        case mistral
        case deepseek
        
        var keychainKey: String {
            switch self {
            case .mistral: return "mistral_api_key"
            case .deepseek: return "deepseek_api_key"
            }
        }
    }

    static var apiKey: String {
        mistralAPIKey
    }

    static var deepseekKey: String {
        deepseekAPIKey
    }
}
