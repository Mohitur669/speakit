//
//  TranscriptionResultSheet.swift
//  SpeakIT
//
//  Transcription result and translation sheet matching 05_Transcription_Result.svg.
//  Includes language name display, translation target language picker,
//  and merged Sarvam & ElevenLabs voice selector with gender and language filtering.
//

import SwiftUI

struct TranscriptionResultSheet: View {
    @State var result: TranscriptionResult
    @Environment(\.dismiss) private var dismiss
    
    // Translation state
    @State private var selectedTargetLanguage: TranslationLanguage = LanguageHelper.supportedTranslationLanguages[1] // Default Hindi
    @State private var isTranslating: Bool = false
    @State private var translationError: String? = nil
    
    // Voice & TTS State
    @State private var voices: [Voice] = Voice.samples
    @State private var selectedVoice: Voice = Voice.samples[6] // Default Ananya / Hindi
    @State private var selectedGender: String = "ALL" // "ALL", "FEMALE", "MALE"
    @State private var isSynthesizingTranslation: Bool = false
    @State private var isSynthesizingOriginal: Bool = false
    @State private var showCopiedOriginalToast: Bool = false
    @State private var showCopiedTranslationToast: Bool = false
    
    private var playerManager = AudioPlayerManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color.speakitTextPrimary)
                        .frame(width: 44, height: 44)
                }
                
                Spacer()
                
                Text("Transcription")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.speakitTextPrimary)
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Text("Done")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.speakitPrimary)
                        .frame(height: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            ScrollView {
                VStack(spacing: 16) {
                    // Metadata Bar (Clean human-readable language name, duration, words)
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform")
                                .font(.system(size: 10, weight: .bold))
                            Text(result.displayLanguage)
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(Color.speakitPrimary)
                        
                        Spacer()
                        
                        Text(result.formattedDuration)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.speakitTextSecondary)
                        
                        Spacer()
                        
                        Text("\(result.wordCount) words")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.speakitTextSecondary)
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 36)
                    .background(Color.speakitCard)
                    .clipShape(Capsule())
                    .padding(.top, 8)
                    
                    // Original Transcribed Text Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("ORIGINAL TRANSCRIPT")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.speakitTextSecondary)
                                .tracking(0.8)
                            
                            Spacer()
                            
                            // Copy original button
                            Button(action: {
                                UIPasteboard.general.string = result.text
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showCopiedOriginalToast = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showCopiedOriginalToast = false
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: showCopiedOriginalToast ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(showCopiedOriginalToast ? "Copied" : "Copy")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundColor(Color.speakitPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.speakitBadgeBackground)
                                .clipShape(Capsule())
                            }
                        }
                        
                        Text(result.text)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Color.speakitTextPrimary)
                            .lineSpacing(5)
                            .textSelection(.enabled)
                        
                        HStack {
                            Text(result.timestamp)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.speakitTextTertiary)
                            
                            Spacer()
                            
                            // Listen to original transcript (TTS synthesize)
                            Button(action: {
                                speakOriginalTranscript()
                            }) {
                                HStack(spacing: 5) {
                                    if isSynthesizingOriginal {
                                        ProgressView().scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    Text(isSynthesizingOriginal ? "Generating..." : "Listen")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(Color.speakitPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.speakitBadgeBackground)
                                .cornerRadius(8)
                            }
                            .disabled(isSynthesizingOriginal)
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.speakitCard)
                    .cornerRadius(SpeakITSpacing.cardRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                            .stroke(Color.speakitBorder, lineWidth: 1)
                    )
                    
                    // Translation & Voice Controls Section
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("TRANSLATE & VOICE SYNTHESIS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.speakitTextSecondary)
                                .tracking(0.8)
                            
                            Spacer()
                        }
                        
                        // Row 1: Target Language Picker & Gender Filter
                        HStack(spacing: 8) {
                            // Target Language Dropdown Menu
                            Menu {
                                ForEach(LanguageHelper.supportedTranslationLanguages) { lang in
                                    Button(action: {
                                        UISelectionFeedbackGenerator().selectionChanged()
                                        selectedTargetLanguage = lang
                                        updateSelectedVoiceForLanguage(lang)
                                    }) {
                                        HStack {
                                            Text(lang.name)
                                            if selectedTargetLanguage.code == lang.code {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "globe")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(selectedTargetLanguage.name)
                                        .font(.system(size: 12, weight: .bold))
                                        .lineLimit(1)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .background(Color.speakitBadgeBackground)
                                .foregroundColor(Color.speakitPrimary)
                                .cornerRadius(10)
                            }
                            
                            Spacer()
                            
                            // Gender Filter Segmented Capsule (All, Female, Male)
                            HStack(spacing: 2) {
                                ForEach(["ALL", "FEMALE", "MALE"], id: \.self) { g in
                                    let isSelected = selectedGender == g
                                    Button(action: {
                                        UISelectionFeedbackGenerator().selectionChanged()
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            selectedGender = g
                                            ensureValidSelectedVoice()
                                        }
                                    }) {
                                        HStack(spacing: 3) {
                                            if g == "FEMALE" {
                                                Text("♀")
                                                    .font(.system(size: 10, weight: .bold))
                                            } else if g == "MALE" {
                                                Text("♂")
                                                    .font(.system(size: 10, weight: .bold))
                                            }
                                            Text(g == "ALL" ? "All" : (g == "FEMALE" ? "Female" : "Male"))
                                                .font(.system(size: 11, weight: isSelected ? .bold : .semibold))
                                        }
                                        .padding(.horizontal, 8)
                                        .frame(height: 30)
                                        .background(isSelected ? Color.speakitPrimary : Color.clear)
                                        .foregroundColor(isSelected ? .white : Color.speakitTextSecondary)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(2)
                            .background(Color.speakitBackground)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.speakitBorder, lineWidth: 1))
                        }
                        
                        // Row 2: Narrator Voice Selector Dropdown (Merged Sarvam, ElevenLabs & Standard)
                        Menu {
                            Section("Matching Voices (\(selectedTargetLanguage.name))") {
                                ForEach(filteredVoices) { voice in
                                    Button(action: {
                                        UISelectionFeedbackGenerator().selectionChanged()
                                        selectedVoice = voice
                                    }) {
                                        HStack {
                                            Text("\(voice.name) (\(voice.engineDisplayName) • \(voice.gender.capitalized))")
                                            if selectedVoice.id == voice.id {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                            
                            if filteredVoices.count < voices.count {
                                Section("All Available Voices") {
                                    ForEach(voices.filter { v in
                                        if selectedGender == "ALL" { return true }
                                        return v.gender.uppercased() == selectedGender
                                    }) { voice in
                                        Button(action: {
                                            UISelectionFeedbackGenerator().selectionChanged()
                                            selectedVoice = voice
                                        }) {
                                            HStack {
                                                Text("\(voice.name) (\(voice.languageName) • \(voice.engineDisplayName))")
                                                if selectedVoice.id == voice.id {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "person.wave.2.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.speakitPrimary)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Voice Narrator")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(Color.speakitTextSecondary)
                                    Text("\(selectedVoice.name) (\(selectedVoice.engineDisplayName) • \(selectedVoice.gender.capitalized))")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Color.speakitTextPrimary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color.speakitTextTertiary)
                            }
                            .padding(12)
                            .background(Color.speakitBackground)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.speakitBorder, lineWidth: 1))
                        }
                        
                        // Translate Button
                        Button(action: {
                            performTranslation()
                        }) {
                            HStack(spacing: 6) {
                                if isTranslating {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                Text(isTranslating ? "Translating..." : "Translate to \(selectedTargetLanguage.name)")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(Color.speakitPrimary)
                            .cornerRadius(10)
                        }
                        .disabled(isTranslating)
                        
                        // Translation Error Message
                        if let error = translationError {
                            Text(error)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.speakitDestructive)
                        }
                        
                        // Translated Text Display & Speech Controls
                        if let translated = result.translatedText {
                            VStack(alignment: .leading, spacing: 10) {
                                Divider()
                                    .padding(.vertical, 4)
                                
                                HStack {
                                    Text("\(selectedTargetLanguage.name.uppercased()) TRANSLATION")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Color.speakitPrimary)
                                        .tracking(0.6)
                                    
                                    Spacer()
                                    
                                    // Copy translated button
                                    Button(action: {
                                        UIPasteboard.general.string = translated
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        showCopiedTranslationToast = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            showCopiedTranslationToast = false
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: showCopiedTranslationToast ? "checkmark" : "doc.on.doc")
                                                .font(.system(size: 11, weight: .semibold))
                                            Text(showCopiedTranslationToast ? "Copied" : "Copy")
                                                .font(.system(size: 11, weight: .semibold))
                                        }
                                        .foregroundColor(Color.speakitPrimary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.speakitBadgeBackground)
                                        .clipShape(Capsule())
                                    }
                                }
                                
                                Text(translated)
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(Color.speakitTextPrimary)
                                    .lineSpacing(5)
                                    .textSelection(.enabled)
                                
                                // Listen to Translated Text Button
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        speakTranslatedText(translated)
                                    }) {
                                        HStack(spacing: 6) {
                                            if isSynthesizingTranslation {
                                                ProgressView().scaleEffect(0.7)
                                            } else {
                                                Image(systemName: "speaker.wave.3.fill")
                                                    .font(.system(size: 12, weight: .bold))
                                            }
                                            Text(isSynthesizingTranslation ? "Synthesizing Speech..." : "Listen with \(selectedVoice.name)")
                                                .font(.system(size: 12, weight: .bold))
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14)
                                        .frame(height: 38)
                                        .background(Color.speakitPrimary)
                                        .cornerRadius(10)
                                    }
                                    .disabled(isSynthesizingTranslation)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding(18)
                    .background(Color.speakitCard)
                    .cornerRadius(SpeakITSpacing.cardRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                            .stroke(Color.speakitBorder, lineWidth: 1)
                    )
                    
                    // Original Audio Replay Card (if recorded file exists)
                    if let audioURL = result.originalAudioURL {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("RECORDED AUDIO")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.speakitTextSecondary)
                                .tracking(0.8)
                            
                            HStack(spacing: 14) {
                                Button(action: {
                                 UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                 playerManager.loadAndPlay(url: audioURL, title: "Voice Memo", subtitle: "\(result.formattedDuration) recorded")
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.speakitPrimary)
                                            .frame(width: 40, height: 40)
                                        
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                            .offset(x: 1)
                                    }
                                }
                                
                                Text("\(result.formattedDuration) recorded")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.speakitTextPrimary)
                                
                                Spacer()
                            }
                        }
                        .padding(18)
                        .background(Color.speakitCard)
                        .cornerRadius(SpeakITSpacing.cardRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                                .stroke(Color.speakitBorder, lineWidth: 1)
                        )
                    }
                    
                    // New Recording CTA Button
                    SpeakITButton(
                        title: "New Recording",
                        style: .primary
                    ) {
                        dismiss()
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
            }
        }
        .background(Color.speakitBackground)
        .task {
            await loadVoicesFromBackend()
        }
    }
    
    // MARK: - Voice Filtering
    private var filteredVoices: [Voice] {
        let targetCode = selectedTargetLanguage.code.lowercased()
        let targetName = selectedTargetLanguage.name.lowercased()
        
        return voices.filter { voice in
            // Match gender
            if selectedGender != "ALL" && voice.gender.uppercased() != selectedGender {
                return false
            }
            
            // Match target language
            let vCode = voice.languageCode.lowercased()
            let vName = voice.languageName.lowercased()
            
            let matchesLang = vCode.contains(targetCode) ||
                              targetCode.contains(vCode) ||
                              vName.contains(targetName) ||
                              targetName.contains(vName)
            
            return matchesLang
        }
    }
    
    private func updateSelectedVoiceForLanguage(_ lang: TranslationLanguage) {
        if let match = filteredVoices.first {
            selectedVoice = match
        } else if let fallback = voices.first(where: { $0.languageCode.lowercased().contains(lang.code.lowercased()) }) {
            selectedVoice = fallback
        }
    }
    
    private func ensureValidSelectedVoice() {
        if !filteredVoices.isEmpty && !filteredVoices.contains(where: { $0.id == selectedVoice.id }) {
            if let first = filteredVoices.first {
                selectedVoice = first
            }
        }
    }
    
    // MARK: - Network Actions
    private func loadVoicesFromBackend() async {
        do {
            let fetchedVoices: [Voice] = try await HTTPClient.shared.request(.voices)
            if !fetchedVoices.isEmpty {
                await MainActor.run {
                    self.voices = fetchedVoices
                    updateSelectedVoiceForLanguage(selectedTargetLanguage)
                }
            }
        } catch {
            print("Failed to fetch voices for translation: \(error)")
        }
    }
    
    private func performTranslation() {
        isTranslating = true
        translationError = nil
        
        Task {
            do {
                struct TranslationRequest: Codable {
                    let text: String
                    let sourceLanguage: String
                    let targetLanguage: String
                }
                
                struct TranslationResponse: Codable {
                    let translatedText: String
                    let sourceLanguage: String?
                }
                
                let source = LanguageHelper.languageCode(for: result.language)
                let req = TranslationRequest(
                    text: result.text,
                    sourceLanguage: source,
                    targetLanguage: selectedTargetLanguage.code
                )
                let reqBody = try JSONEncoder().encode(req)
                let resp: TranslationResponse = try await HTTPClient.shared.request(.translate, method: "POST", body: reqBody)
                
                await MainActor.run {
                    self.isTranslating = false
                    self.result.translatedText = resp.translatedText
                    self.translationError = nil
                }
            } catch {
                await MainActor.run {
                    self.isTranslating = false
                    self.translationError = error.localizedDescription
                }
            }
        }
    }
    
    private func speakTranslatedText(_ text: String) {
        isSynthesizingTranslation = true
        synthesizeAndPlay(text: text, voice: selectedVoice) {
            self.isSynthesizingTranslation = false
        }
    }
    
    private func speakOriginalTranscript() {
        isSynthesizingOriginal = true
        // Pick an original voice matching result language
        let origVoice = voices.first(where: { v in
            v.languageName.localizedCaseInsensitiveContains(result.displayLanguage) ||
            result.displayLanguage.localizedCaseInsensitiveContains(v.languageName)
        }) ?? selectedVoice
        
        synthesizeAndPlay(text: result.text, voice: origVoice) {
            self.isSynthesizingOriginal = false
        }
    }
    
    private func synthesizeAndPlay(text: String, voice: Voice, completion: @escaping () -> Void) {
        Task {
            do {
                struct SynthesizeRequest: Codable {
                    let text: String
                    let voiceId: String
                    let voiceName: String
                    let voiceType: String
                    let outputFormat: String
                    let isElevenLabs: Bool
                    let isSarvam: Bool
                    let languageCode: String?
                }
                
                let isElevenLabs = voice.engine.lowercased() == "elevenlabs"
                let isSarvam = voice.engine.lowercased() == "sarvam"
                let voiceType = isElevenLabs ? "NATURAL" : (voice.isNeural ? "NEURAL" : "STANDARD")
                
                let req = SynthesizeRequest(
                    text: text,
                    voiceId: voice.id,
                    voiceName: voice.name,
                    voiceType: voiceType,
                    outputFormat: "mp3",
                    isElevenLabs: isElevenLabs,
                    isSarvam: isSarvam,
                    languageCode: voice.languageCode
                )
                
                let reqBody = try JSONEncoder().encode(req)
                let audioData = try await HTTPClient.shared.downloadBinary(.synthesize, body: reqBody)
                
                let tempDir = FileManager.default.temporaryDirectory
                let audioURL = tempDir.appendingPathComponent("speakit_tts_\(Date().timeIntervalSince1970).mp3")
                try audioData.write(to: audioURL, options: .atomic)
                
                await MainActor.run {
                    completion()
                    self.playerManager.loadAndPlay(
                        url: audioURL,
                        title: String(text.prefix(32)),
                        subtitle: "\(voice.name) (\(voice.engineDisplayName))"
                    )
                }
            } catch {
                await MainActor.run {
                    completion()
                    print("Speech synthesis failed: \(error)")
                }
            }
        }
    }
}

#Preview {
    TranscriptionResultSheet(result: TranscriptionResult.sample)
}
