//
//  APIEndpoint.swift
//  SpeakIT
//
//  Backend API endpoints configuration.
//

import Foundation

enum APIEndpoint {
    static var baseURL = "http://localhost:8080"
    
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
