//
//  APIEndpoint.swift
//  SpeakIT
//
//  Backend API endpoints configuration.
//

import Foundation

enum APIEndpoint {
    /// The backend API URL resolved based on environment:
    /// - During Simulator testing: Defaults to `http://localhost:8080`, but fully configurable
    ///   via `IOS_SIMULATOR_BASE_URL` in `Local.xcconfig` or Xcode Scheme Environment Variables.
    /// - During Physical iPhone testing: Uses `IOS_API_BASE_URL` (from `Local.xcconfig`),
    ///   with fallback to `IOS_API_BASE_BACKUP_URL`.
    static var baseURL: String {
        #if targetEnvironment(simulator)
        // 1. Process environment variable (Xcode Scheme > Run > Arguments > Environment Variables)
        // Allows instant runtime override in Xcode without editing any files.
        if let envURL = ProcessInfo.processInfo.environment["IOS_SIMULATOR_BASE_URL"] ?? ProcessInfo.processInfo.environment["IOS_API_BASE_URL"],
           !envURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return cleanURL(envURL)
        }
        
        // 2. Custom Simulator URL from Info.plist (configured via Local.xcconfig)
        if let plistSimURL = Bundle.main.object(forInfoDictionaryKey: "IOS_SIMULATOR_BASE_URL") as? String,
           !plistSimURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           plistSimURL != "$(IOS_SIMULATOR_BASE_URL)" {
            return cleanURL(plistSimURL)
        }
        
        // 3. Default fallback for Simulator
        return "http://localhost:8080"
        #else
        // 4. Physical iPhone: Use primary IOS_API_BASE_URL configured in Info.plist / Local.xcconfig
        if let plistURL = Bundle.main.object(forInfoDictionaryKey: "IOS_API_BASE_URL") as? String,
           !plistURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           plistURL != "$(IOS_API_BASE_URL)" {
            return cleanURL(plistURL)
        }
        
        // 5. Fallback: Process environment (if launched via Xcode debugger)
        if let envURL = ProcessInfo.processInfo.environment["IOS_API_BASE_URL"],
           !envURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return cleanURL(envURL)
        }
        
        // 6. Fallback: IOS_API_BASE_BACKUP_URL from Info.plist
        if let plistBackup = Bundle.main.object(forInfoDictionaryKey: "IOS_API_BASE_BACKUP_URL") as? String,
           !plistBackup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           plistBackup != "$(IOS_API_BASE_BACKUP_URL)" {
            return cleanURL(plistBackup)
        }
        
        // 7. Ultimate fallback
        return "http://localhost:8080"
        #endif
    }
    
    /// Sanitizes the base URL by trimming whitespace, ensuring scheme prefix, and stripping trailing slashes.
    private static func cleanURL(_ urlString: String) -> String {
        var trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.hasPrefix("http://") && !trimmed.hasPrefix("https://") {
            if trimmed.contains("localhost") || trimmed.hasPrefix("127.0.0.1") || trimmed.hasPrefix("192.168.") || trimmed.hasPrefix("10.") {
                trimmed = "http://" + trimmed
            } else {
                trimmed = "https://" + trimmed
            }
        }
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        return trimmed
    }
    
    // Auth
    case login
    case register
    
    // Users
    case userProfile
    case deleteAccount
    
    // TTS
    case voices
    case synthesize
    
    // STT
    case transcribeLive
    case transcribeFile
    case translate
    
    // History
    case history(page: Int, size: Int)
    case deleteHistory
    case clearAllHistory
    
    var path: String {
        switch self {
        case .login:
            return "/api/auth/login"
        case .register:
            return "/api/auth/register"
        case .userProfile:
            return "/api/v1/users/me"
        case .deleteAccount:
            return "/api/v1/users/me"
        case .voices:
            return "/api/tts/voices"
        case .synthesize:
            return "/api/tts/synthesize"
        case .transcribeLive:
            return "/api/stt/transcribe-live"
        case .transcribeFile:
            return "/api/stt/transcribe"
        case .translate:
            return "/api/stt/translate"
        case .history(let page, let size):
            return "/api/history?page=\(page)&size=\(size)"
        case .deleteHistory:
            return "/api/history/delete"
        case .clearAllHistory:
            return "/api/history/clear-all"
        }
    }
    
    var url: URL? {
        URL(string: APIEndpoint.baseURL + path)
    }
}
