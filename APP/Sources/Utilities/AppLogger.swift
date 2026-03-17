import OSLog
import Foundation

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.jusstalk.app"
    
    static let transcription = Logger(subsystem: subsystem, category: "transcription")
    static let storeKit = Logger(subsystem: subsystem, category: "storekit")
    static let trial = Logger(subsystem: subsystem, category: "trial")
    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let general = Logger(subsystem: subsystem, category: "general")
    
    static func debug(_ message: String, category: Logger = general) {
        #if DEBUG
        category.debug("\(message, privacy: .public)")
        #endif
    }
    
    static func info(_ message: String, category: Logger = general) {
        #if DEBUG
        category.info("\(message, privacy: .public)")
        #endif
    }
    
    static func error(_ message: String, category: Logger = general) {
        #if DEBUG
        category.error("\(message, privacy: .public)")
        #else
        category.error("\(message, privacy: .private)")
        #endif
    }
    
    static func sensitive(_ message: String, category: Logger = general) {
        #if DEBUG
        category.debug("\(message, privacy: .private)")
        #endif
    }
}
