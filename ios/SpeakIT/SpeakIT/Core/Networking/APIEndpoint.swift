//
//  APIEndpoint.swift
//  SpeakIT
//
//  Backend API endpoints configuration.
//

import Foundation

enum APIEndpoint {
    /// The backend API URL resolved based on environment:
    /// - During Simulator testing: Automatically connects to `http://localhost:8080`.
    /// - During Physical iPhone testing: Uses `IOS_API_BASE_URL` (configured before compiling),
    ///   with fallback to `IOS_API_BASE_BACKUP_URL`.
    static var baseURL: String {
        #if targetEnvironment(simulator)
        // 1. On iOS Simulator: Automatically use localhost
        if let envURL = ProcessInfo.processInfo.environment["IOS_API_BASE_URL"],
           !envURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return cleanURL(envURL)
        }
        return "http://localhost:8080"
        #else
        // 2. On Physical iPhone: Use primary IOS_API_BASE_URL configured in Info.plist
        if let plistURL = Bundle.main.object(forInfoDictionaryKey: "IOS_API_BASE_URL") as? String,
           !plistURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return cleanURL(plistURL)
        }
        
        // 3. Fallback: Process environment
        if let envURL = ProcessInfo.processInfo.environment["IOS_API_BASE_URL"],
           !envURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return cleanURL(envURL)
        }
        
        // 4. Fallback: IOS_API_BASE_BACKUP_URL from Info.plist
        if let plistBackup = Bundle.main.object(forInfoDictionaryKey: "IOS_API_BASE_BACKUP_URL") as? String,
           !plistBackup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return cleanURL(plistBackup)
        }
        
        // 5. Ultimate fallback
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
