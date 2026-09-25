//
//  HistoryItem.swift
//  SpeakIT
//
//  Generation history model matching GET /api/history.
//

import Foundation

struct HistoryItem: Codable, Identifiable {
    let id: Int64
    let textSnippet: String
    let characterCount: Int
    let voiceId: String?
    let voiceName: String?
    let engineType: String // "TTS" or "STT"
    let createdAt: String
    var localAudioURL: URL? = nil
    
    init(
        id: Int64,
        textSnippet: String,
        characterCount: Int = 0,
        voiceId: String? = nil,
        voiceName: String? = nil,
        engineType: String = "TTS",
        createdAt: String = "Just now",
        localAudioURL: URL? = nil
    ) {
        self.id = id
        self.textSnippet = textSnippet
        self.characterCount = characterCount
        self.voiceId = voiceId
        self.voiceName = voiceName
        self.engineType = engineType
        self.createdAt = createdAt
        self.localAudioURL = localAudioURL
    }
    
    enum CodingKeys: String, CodingKey {
        case id, textSnippet, characterCount, voiceId, voiceName, engineType, voiceType, createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int64.self, forKey: .id)
        self.textSnippet = (try? container.decode(String.self, forKey: .textSnippet)) ?? "Audio generation"
        self.characterCount = (try? container.decode(Int.self, forKey: .characterCount)) ?? 0
        self.voiceId = try? container.decode(String.self, forKey: .voiceId)
        self.voiceName = try? container.decode(String.self, forKey: .voiceName)
        
        if let eng = try? container.decode(String.self, forKey: .engineType) {
            self.engineType = eng
        } else if let vType = try? container.decode(String.self, forKey: .voiceType) {
            self.engineType = vType
        } else {
            self.engineType = "TTS"
        }
        
        self.createdAt = (try? container.decode(String.self, forKey: .createdAt)) ?? "Recent"
        self.localAudioURL = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(textSnippet, forKey: .textSnippet)
        try container.encode(characterCount, forKey: .characterCount)
        try container.encodeIfPresent(voiceId, forKey: .voiceId)
        try container.encodeIfPresent(voiceName, forKey: .voiceName)
        try container.encode(engineType, forKey: .engineType)
        try container.encode(createdAt, forKey: .createdAt)
    }
    
    var subtitle: String {
        let name = voiceName ?? "Voice"
        return "\(name) • \(engineType)"
    }
    
    var timeAgoFormatted: String {
        return createdAt
    }
    
    // Samples matching 06_Activity.svg
    static let samples: [HistoryItem] = [
        HistoryItem(
            id: 1,
            textSnippet: "Good ideas can change the world…",
            characterCount: 34,
            voiceId: "Aditi",
            voiceName: "Aditi",
            engineType: "TTS",
            createdAt: "2h ago"
        ),
        HistoryItem(
            id: 2,
            textSnippet: "Meeting notes transcription",
            characterCount: 26,
            voiceId: "Whisper",
            voiceName: "Whisper",
            engineType: "STT",
            createdAt: "Yesterday"
        ),
        HistoryItem(
            id: 3,
            textSnippet: "Welcome to SpeakIT",
            characterCount: 18,
            voiceId: "Joanna",
            voiceName: "Joanna",
            engineType: "TTS",
            createdAt: "Nov 10"
        ),
        HistoryItem(
            id: 4,
            textSnippet: "Project discussion",
            characterCount: 19,
            voiceId: "Whisper",
            voiceName: "Whisper",
            engineType: "STT",
            createdAt: "Nov 10"
        ),
        HistoryItem(
            id: 5,
            textSnippet: "Exploring artificial intelligence and voice synthesis",
            characterCount: 54,
            voiceId: "Matthew",
            voiceName: "Matthew",
            engineType: "TTS",
            createdAt: "Nov 8"
        ),
        HistoryItem(
            id: 6,
            textSnippet: "Quarterly earnings call summary",
            characterCount: 32,
            voiceId: "Whisper",
            voiceName: "Whisper",
            engineType: "STT",
            createdAt: "Nov 7"
        ),
        HistoryItem(
            id: 7,
            textSnippet: "Your daily news briefing is ready to listen",
            characterCount: 42,
            voiceId: "Amy",
            voiceName: "Amy",
            engineType: "TTS",
            createdAt: "Nov 5"
        ),
        HistoryItem(
            id: 8,
            textSnippet: "Customer support audio log transcription",
            characterCount: 40,
            voiceId: "Whisper",
            voiceName: "Whisper",
            engineType: "STT",
            createdAt: "Nov 4"
        ),
        HistoryItem(
            id: 9,
            textSnippet: "Chapter one: The beginnings of audio engineering",
            characterCount: 48,
            voiceId: "Brian",
            voiceName: "Brian",
            engineType: "TTS",
            createdAt: "Nov 1"
        ),
        HistoryItem(
            id: 10,
            textSnippet: "Product launch keynote rehearsal speech",
            characterCount: 39,
            voiceId: "Kendra",
            voiceName: "Kendra",
            engineType: "TTS",
            createdAt: "Oct 28"
        )
    ]
}
