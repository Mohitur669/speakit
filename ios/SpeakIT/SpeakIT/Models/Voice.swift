//
//  Voice.swift
//  SpeakIT
//
//  Voice domain model matching GET /api/tts/voices.
//

import Foundation

enum VoiceCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case indian = "Indian"
    case international = "International"
    case pollyNeural = "Standard"
    
    var id: String { rawValue }
}

struct Voice: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let languageCode: String
    let languageName: String
    let gender: String
    let engine: String
    let isNeural: Bool
    let requiresPlan: PlanType
    var previewURL: String?
    
    init(
        id: String,
        name: String,
        languageCode: String = "en-US",
        languageName: String? = nil,
        gender: String = "FEMALE",
        engine: String? = nil,
        isNeural: Bool = true,
        requiresPlan: PlanType = .free,
        previewURL: String? = nil
    ) {
        self.id = id
        self.name = name
        self.languageCode = languageCode
        self.gender = gender
        self.previewURL = previewURL
        
        let resolvedEngine = engine ?? "neural"
        self.engine = resolvedEngine
        self.isNeural = isNeural
        self.requiresPlan = requiresPlan
        self.languageName = languageName ?? "English"
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, languageCode, languageName, gender, engine, isNeural, requiresPlan, previewURL
        case isElevenLabs, isSarvam
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.gender = (try? container.decode(String.self, forKey: .gender)) ?? "FEMALE"
        self.previewURL = try? container.decode(String.self, forKey: .previewURL)
        
        let isEleven = (try? container.decode(Bool.self, forKey: .isElevenLabs)) ?? false
        let isSarv = (try? container.decode(Bool.self, forKey: .isSarvam)) ?? false
        
        if let eng = try? container.decode(String.self, forKey: .engine) {
            self.engine = eng
        } else if isEleven {
            self.engine = "elevenlabs"
        } else if isSarv {
            self.engine = "sarvam"
        } else {
            self.engine = "neural"
        }
        
        self.languageCode = (try? container.decode(String.self, forKey: .languageCode)) ?? (isSarv ? "hi-IN" : "en-US")
        
        if let langName = try? container.decode(String.self, forKey: .languageName) {
            self.languageName = langName
        } else if isSarv {
            self.languageName = "Indian English"
        } else {
            self.languageName = "US English"
        }
        
        self.isNeural = (try? container.decode(Bool.self, forKey: .isNeural)) ?? true
        
        if let plan = try? container.decode(PlanType.self, forKey: .requiresPlan) {
            self.requiresPlan = plan
        } else if isEleven || isSarv {
            self.requiresPlan = .proPlus
        } else {
            self.requiresPlan = .pro
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(languageCode, forKey: .languageCode)
        try container.encode(languageName, forKey: .languageName)
        try container.encode(gender, forKey: .gender)
        try container.encode(engine, forKey: .engine)
        try container.encode(isNeural, forKey: .isNeural)
        try container.encode(requiresPlan, forKey: .requiresPlan)
        try container.encodeIfPresent(previewURL, forKey: .previewURL)
    }
    
    var subtitle: String {
        "\(languageName) • \(engineDisplayName)"
    }
    
    var engineDisplayName: String {
        switch engine.lowercased() {
        case "sarvam": return "Indian"
        case "elevenlabs": return "International"
        case "neural", "standard": return "Standard"
        default: return "Standard"
        }
    }
    
    var matchesCategory: (VoiceCategory) -> Bool {
        return { category in
            switch category {
            case .all: return true
            case .indian: return self.engine.lowercased() == "sarvam"
            case .international: return self.engine.lowercased() == "elevenlabs"
            case .pollyNeural: return self.engine.lowercased() == "neural" || self.engine.lowercased() == "standard"
            }
        }
    }
    
    // Sample voices matching the approved design reference
    static let samples: [Voice] = [
        Voice(
            id: "ritu:en-IN",
            name: "Aditi",
            languageCode: "en-IN",
            languageName: "Indian English",
            gender: "FEMALE",
            engine: "sarvam",
            isNeural: true,
            requiresPlan: .proPlus
        ),
        Voice(
            id: "aditya:en-IN",
            name: "Aditya",
            languageCode: "en-IN",
            languageName: "Indian English",
            gender: "MALE",
            engine: "sarvam",
            isNeural: true,
            requiresPlan: .proPlus
        ),
        Voice(
            id: "Joanna",
            name: "Joanna",
            languageCode: "en-US",
            languageName: "US English",
            gender: "FEMALE",
            engine: "neural",
            isNeural: true,
            requiresPlan: .pro
        ),
        Voice(
            id: "Matthew",
            name: "Matthew",
            languageCode: "en-US",
            languageName: "US English",
            gender: "MALE",
            engine: "neural",
            isNeural: true,
            requiresPlan: .pro
        ),
        Voice(
            id: "Rachel",
            name: "Rachel",
            languageCode: "en-US",
            languageName: "US English",
            gender: "FEMALE",
            engine: "elevenlabs",
            isNeural: true,
            requiresPlan: .proPlus
        ),
        Voice(
            id: "Josh",
            name: "Josh",
            languageCode: "en-US",
            languageName: "US English",
            gender: "MALE",
            engine: "elevenlabs",
            isNeural: true,
            requiresPlan: .proPlus
        ),
        Voice(
            id: "priya:hi-IN",
            name: "Ananya",
            languageCode: "hi-IN",
            languageName: "Hindi",
            gender: "FEMALE",
            engine: "sarvam",
            isNeural: true,
            requiresPlan: .proPlus
        ),
        Voice(
            id: "Aria",
            name: "Aria",
            languageCode: "en-GB",
            languageName: "British English",
            gender: "FEMALE",
            engine: "elevenlabs",
            isNeural: true,
            requiresPlan: .proPlus
        )
    ]
}
