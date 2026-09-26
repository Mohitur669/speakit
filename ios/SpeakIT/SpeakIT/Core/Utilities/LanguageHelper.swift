//
//  LanguageHelper.swift
//  SpeakIT
//
//  Language resolution and translation helper mapping raw ISO language codes
//  into clean, user-friendly language names.
//

import Foundation

struct TranslationLanguage: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String { code }
}

enum LanguageHelper {
    
    private static let explicitNames: [String: String] = [
        "en": "English",
        "en-us": "English (US)",
        "en-in": "English (India)",
        "en-gb": "English (UK)",
        "hi": "Hindi",
        "hi-in": "Hindi",
        "bn": "Bengali",
        "bn-in": "Bengali",
        "ta": "Tamil",
        "ta-in": "Tamil",
        "te": "Telugu",
        "te-in": "Telugu",
        "mr": "Marathi",
        "mr-in": "Marathi",
        "gu": "Gujarati",
        "gu-in": "Gujarati",
        "kn": "Kannada",
        "kn-in": "Kannada",
        "ml": "Malayalam",
        "ml-in": "Malayalam",
        "pa": "Punjabi",
        "pa-in": "Punjabi",
        "or": "Odia",
        "or-in": "Odia",
        "od": "Odia",
        "od-in": "Odia",
        "es": "Spanish",
        "es-es": "Spanish",
        "fr": "French",
        "fr-fr": "French",
        "de": "German",
        "de-de": "German",
        "ja": "Japanese",
        "ja-jp": "Japanese",
        "it": "Italian",
        "it-it": "Italian",
        "pt": "Portuguese",
        "pt-br": "Portuguese (Brazil)",
        "ru": "Russian",
        "ar": "Arabic",
        "zh": "Chinese",
        "ko": "Korean",
        "auto": "Auto detected"
    ]
    
    /// Converts any language code or identifier (e.g. "en", "hi-IN", "ta") into a human-readable language name.
    static func displayName(for rawCode: String?) -> String {
        guard let code = rawCode?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty else {
            return "English"
        }
        
        let lower = code.lowercased()
        
        // 1. Direct match in curated dictionary
        if let direct = explicitNames[lower] {
            return direct
        }
        
        // 2. Base language prefix match (e.g., "en-AU" -> "en")
        let baseCode = lower.split(separator: "-").first.map(String.init) ?? lower
        if let baseMatch = explicitNames[baseCode] {
            return baseMatch
        }
        
        // 3. Apple Foundation Locale resolution
        let enLocale = Locale(identifier: "en_US")
        if let localized = enLocale.localizedString(forIdentifier: code), !localized.isEmpty {
            return localized.capitalized
        }
        if let localizedLang = enLocale.localizedString(forLanguageCode: baseCode), !localizedLang.isEmpty {
            return localizedLang.capitalized
        }
        
        return code.uppercased()
    }
    
    /// Converts a language code, identifier, or language display name (e.g. "English (India)", "Hindi", "hi-IN", "en")
    /// into a valid standard BCP-47 language code (e.g. "en-IN", "hi-IN") or "auto".
    static func languageCode(for identifier: String?) -> String {
        guard let raw = identifier?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return "auto"
        }
        
        let lower = raw.lowercased()
        if lower == "auto" { return "auto" }
        
        // Exact and substring checks for names
        if lower.contains("english") || lower.hasPrefix("en") { return "en-IN" }
        if lower.contains("hindi") || lower.hasPrefix("hi") { return "hi-IN" }
        if lower.contains("bengali") || lower.hasPrefix("bn") { return "bn-IN" }
        if lower.contains("tamil") || lower.hasPrefix("ta") { return "ta-IN" }
        if lower.contains("telugu") || lower.hasPrefix("te") { return "te-IN" }
        if lower.contains("marathi") || lower.hasPrefix("mr") { return "mr-IN" }
        if lower.contains("gujarati") || lower.hasPrefix("gu") { return "gu-IN" }
        if lower.contains("kannada") || lower.hasPrefix("kn") { return "kn-IN" }
        if lower.contains("malayalam") || lower.hasPrefix("ml") { return "ml-IN" }
        if lower.contains("punjabi") || lower.hasPrefix("pa") { return "pa-IN" }
        if lower.contains("odia") || lower.hasPrefix("od") || lower.hasPrefix("or") { return "od-IN" }
        if lower.contains("urdu") || lower.hasPrefix("ur") { return "ur-IN" }
        if lower.contains("assamese") || lower.hasPrefix("as") { return "as-IN" }
        
        // Remove spaces and parentheses
        let sanitized = lower.replacingOccurrences(of: " ", with: "-")
                             .replacingOccurrences(of: "(", with: "")
                             .replacingOccurrences(of: ")", with: "")
        return sanitized
    }
    static let supportedTranslationLanguages: [TranslationLanguage] = [
        TranslationLanguage(code: "hi-IN", name: "Hindi"),
        TranslationLanguage(code: "en-IN", name: "English"),
        TranslationLanguage(code: "bn-IN", name: "Bengali"),
        TranslationLanguage(code: "ta-IN", name: "Tamil"),
        TranslationLanguage(code: "te-IN", name: "Telugu"),
        TranslationLanguage(code: "mr-IN", name: "Marathi"),
        TranslationLanguage(code: "gu-IN", name: "Gujarati"),
        TranslationLanguage(code: "kn-IN", name: "Kannada"),
        TranslationLanguage(code: "ml-IN", name: "Malayalam"),
        TranslationLanguage(code: "pa-IN", name: "Punjabi"),
        TranslationLanguage(code: "od-IN", name: "Odia"),
        TranslationLanguage(code: "ur-IN", name: "Urdu"),
        TranslationLanguage(code: "as-IN", name: "Assamese")
    ]
}
