//
//  TranscriptionResult.swift
//  SpeakIT
//
//  Transcription result domain model matching POST /api/stt/transcribe responses.
//

import Foundation

struct TranscriptionResult: Codable, Identifiable {
    var id: String = UUID().uuidString
    var text: String
    var language: String
    var durationSeconds: Int
    var wordCount: Int
    var timestamp: String
    var translatedText: String?
    var originalAudioURL: URL?
    
    var displayLanguage: String {
        LanguageHelper.displayName(for: language)
    }
    
    var formattedDuration: String {
        let totalSeconds = max(1, durationSeconds)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        
        if minutes > 0 {
            if seconds > 0 {
                return "\(minutes) min \(seconds) sec"
            } else {
                return "\(minutes) min"
            }
        } else {
            return "\(seconds) sec"
        }
    }
    
    // Sample matching 05_Transcription_Result.svg
    static var sample: TranscriptionResult {
        TranscriptionResult(
            text: "Innovation happens when\npeople can speak freely,\nshare ideas easily, and turn\nthoughts into action.",
            language: "English",
            durationSeconds: 12,
            wordCount: 39,
            timestamp: "Today, 10:24 AM",
            translatedText: nil,
            originalAudioURL: nil
        )
    }
}
