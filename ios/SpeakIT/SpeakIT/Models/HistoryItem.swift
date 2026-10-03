//
//  HistoryItem.swift
//  SpeakIT
//
//  Generation history model matching GET /api/history.
//

import Foundation

struct HistoryItem: Codable, Identifiable {
    let id: Int64
    let sessionId: String?
    let textSnippet: String
    let fullText: String?
    let characterCount: Int
    let voiceId: String?
    let voiceName: String?
    let engineType: String // "TTS" or "STT"
    let createdAt: String
    let audioUrl: String?
    var localAudioURL: URL? = nil
    let transliteration: String?
    let mode: String?
    let filename: String?
    let status: String?
    
    init(
        id: Int64,
        sessionId: String? = nil,
        textSnippet: String,
        fullText: String? = nil,
        characterCount: Int = 0,
        voiceId: String? = nil,
        voiceName: String? = nil,
        engineType: String = "TTS",
        createdAt: String = "Just now",
        audioUrl: String? = nil,
        localAudioURL: URL? = nil,
        transliteration: String? = nil,
        mode: String? = nil,
        filename: String? = nil,
        status: String? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.textSnippet = textSnippet
        self.fullText = fullText
        self.characterCount = characterCount
        self.voiceId = voiceId
        self.voiceName = voiceName
        self.engineType = engineType
        self.createdAt = createdAt
        self.audioUrl = audioUrl
        self.localAudioURL = localAudioURL
        self.transliteration = transliteration
        self.mode = mode
        self.filename = filename
        self.status = status
    }
    
    enum CodingKeys: String, CodingKey {
        case id, sessionId, textSnippet, fullText, characterCount, voiceId, voiceName, engineType, voiceType, createdAt, audioUrl, transliteration, mode, filename, status
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let int64Id = try? container.decode(Int64.self, forKey: .id) {
            self.id = int64Id
        } else if let intId = try? container.decode(Int.self, forKey: .id) {
            self.id = Int64(intId)
        } else if let strId = try? container.decode(String.self, forKey: .id), let parsed = Int64(strId) {
            self.id = parsed
        } else {
            self.id = Int64(abs(UUID().hashValue))
        }
        self.textSnippet = (try? container.decode(String.self, forKey: .textSnippet)) ?? "Audio generation"
        self.sessionId = try? container.decode(String.self, forKey: .sessionId)
        self.fullText = try? container.decode(String.self, forKey: .fullText)
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
        self.audioUrl = try? container.decode(String.self, forKey: .audioUrl)
        self.localAudioURL = nil
        self.transliteration = try? container.decode(String.self, forKey: .transliteration)
        self.mode = try? container.decode(String.self, forKey: .mode)
        self.filename = try? container.decode(String.self, forKey: .filename)
        self.status = try? container.decode(String.self, forKey: .status)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(sessionId, forKey: .sessionId)
        try container.encode(textSnippet, forKey: .textSnippet)
        try container.encodeIfPresent(fullText, forKey: .fullText)
        try container.encode(characterCount, forKey: .characterCount)
        try container.encodeIfPresent(voiceId, forKey: .voiceId)
        try container.encodeIfPresent(voiceName, forKey: .voiceName)
        try container.encode(engineType, forKey: .engineType)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(audioUrl, forKey: .audioUrl)
        try container.encodeIfPresent(transliteration, forKey: .transliteration)
        try container.encodeIfPresent(mode, forKey: .mode)
        try container.encodeIfPresent(filename, forKey: .filename)
        try container.encodeIfPresent(status, forKey: .status)
    }
    
    var displayText: String {
        if let ft = fullText, !ft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ft
        }
        return textSnippet
    }
    
    var subtitle: String {
        if isLiveChat {
            let turns = liveChatTurnCount
            return "\(turns) \(turns == 1 ? "turn" : "turns") • Live Session"
        }
        let name = voiceName ?? "Voice"
        return "\(name) • \(engineType)"
    }
    
    // MARK: - Date & Time Formatting (AM/PM Direct Stamping)
    private static let candidateDateFormats = [
        "yyyy-MM-dd HH:mm:ss.SSSSSS Z",
        "yyyy-MM-dd HH:mm:ss.SSS Z",
        "yyyy-MM-dd HH:mm:ss.SSSZ",
        "yyyy-MM-dd HH:mm:ss.SSSSSS",
        "yyyy-MM-dd HH:mm:ss.SSS",
        "yyyy-MM-dd HH:mm:ss Z",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
        "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ssZ",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd"
    ]
    
    var parsedDate: Date? {
        let clean = createdAt.trimmingCharacters(in: .whitespacesAndNewlines)
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        for format in Self.candidateDateFormats {
            parser.dateFormat = format
            if let date = parser.date(from: clean) {
                return date
            }
        }
        return nil
    }
    
    var formattedDateAndTime: String {
        guard let date = parsedDate else {
            return createdAt
        }
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_US_POSIX")
        out.dateFormat = "MMM d, yyyy, h:mm a"
        return out.string(from: date)
    }
    
    var formattedDate: String {
        guard let date = parsedDate else {
            return createdAt
        }
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_US_POSIX")
        out.dateFormat = "MMM d, yyyy"
        return out.string(from: date)
    }
    
    var formattedTime: String {
        guard let date = parsedDate else {
            return ""
        }
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_US_POSIX")
        out.dateFormat = "h:mm a"
        return out.string(from: date)
    }
    
    var timeAgoFormatted: String {
        return formattedDateAndTime
    }

    var isLiveChat: Bool {
        if engineType.uppercased() == "LIVE" { return true }
        if mode?.lowercased() == "conversation" { return true }
        if let fn = filename, fn.lowercased().contains("live conversation") || fn.lowercased().contains("live session") { return true }
        if let vn = voiceName, vn.lowercased().contains("live conversation") || vn.lowercased().contains("live session") { return true }
        if let ft = fullText, ft.contains("↳ [") || (ft.contains("[Speaker") || ft.contains("[Person")) { return true }
        return false
    }

    var isTTS: Bool {
        return engineType.uppercased() == "TTS"
    }

    var isSTT: Bool {
        return (engineType.uppercased() == "STT" || engineType.uppercased() == "SARVAM") && !isLiveChat
    }

    var liveChatTitle: String {
        if let fn = filename, !fn.isEmpty, fn != "Audio Transcription" && fn != "Live Session" {
            return fn
        }
        if let vn = voiceName, !vn.isEmpty, vn != "Sarvam Saaras" && vn != "STT" && vn != "Live Session" {
            return vn
        }
        let turns = parsedLiveChatTurns
        if !turns.isEmpty {
            let s1 = turns.first?.speakerName ?? "Speaker 1"
            let s2 = turns.first(where: { !$0.isSpeakerA })?.speakerName ?? "Speaker 2"
            return "\(s1) & \(s2)"
        }
        return "Live Conversation"
    }

    var liveChatTurnCount: Int {
        let turns = parsedLiveChatTurns
        return turns.isEmpty ? 1 : turns.count
    }

    var parsedLiveChatTurns: [LiveChatTurn] {
        guard let text = fullText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let blocks = text.components(separatedBy: "\n\n")
        var turns: [LiveChatTurn] = []
        var firstSpeakerName: String? = nil
        
        for block in blocks {
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            let lines = trimmed.components(separatedBy: "\n")
            guard let firstLine = lines.first else { continue }
            
            var speaker = "Speaker 1"
            var lang = "auto"
            var original = firstLine
            var targetLang: String? = nil
            var translated: String? = nil
            
            // Format: [Speaker Name] (lang): Text
            if let closingBracket = firstLine.firstIndex(of: "]"),
               firstLine.hasPrefix("[") {
                let nameStart = firstLine.index(after: firstLine.startIndex)
                speaker = String(firstLine[nameStart..<closingBracket])
                
                let remainder = firstLine[closingBracket...]
                if let openParen = remainder.firstIndex(of: "("),
                   let closeParen = remainder.firstIndex(of: ")"),
                   let colon = remainder.firstIndex(of: ":") {
                    let langStart = remainder.index(after: openParen)
                    lang = String(remainder[langStart..<closeParen])
                    
                    let textStart = remainder.index(after: colon)
                    original = String(remainder[textStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            // Check for translation line: "↳ [targetLang]: translatedText"
            if lines.count > 1 {
                for line in lines.dropFirst() {
                    let tLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if tLine.contains("↳") || tLine.contains("->") {
                        if let openB = tLine.firstIndex(of: "["),
                           let closeB = tLine.firstIndex(of: "]"),
                           let colon = tLine.firstIndex(of: ":") {
                            let lStart = tLine.index(after: openB)
                            targetLang = String(tLine[lStart..<closeB])
                            let txtStart = tLine.index(after: colon)
                            translated = String(tLine[txtStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                }
            }
            
            if firstSpeakerName == nil {
                firstSpeakerName = speaker
            }
            let isSpeakerA = (speaker == firstSpeakerName)
            
            turns.append(LiveChatTurn(
                speakerName: speaker,
                speakerLanguage: lang,
                originalText: original,
                targetLanguage: targetLang,
                translatedText: translated,
                isSpeakerA: isSpeakerA
            ))
        }
        
        return turns
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

// MARK: - LiveChatTurn
/// Represents a single parsed turn in a Live Chat / face-to-face session.
/// Used by `HistoryItem.parsedLiveChatTurns` and `LiveChatDetailView`.
struct LiveChatTurn: Identifiable {
    let id: UUID = UUID()
    let speakerName: String
    let speakerLanguage: String
    let originalText: String
    let targetLanguage: String?
    let translatedText: String?
    let isSpeakerA: Bool
}
