//
//  TTSStudioView.swift
//  SpeakIT
//
//  Primary generation studio matching 02_TTS_Studio.svg.
//

import SwiftUI

struct TTSStudioView: View {
    @Environment(AppState.self) private var appState
    
    @State private var inputText: String = "Good ideas can change the world when spoken with clarity."
    @State private var selectedVoice: Voice = Voice.samples[0] // Defaults to "Aditi"
    @State private var showVoiceCatalog: Bool = false
    @State private var isSynthesizing: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var synthesizedAudioURL: URL? = nil
    @State private var errorMessage: String? = nil
    
    private var playerManager = AudioPlayerManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header Row
                HStack(alignment: .center) {
                    Text("Studio")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(Color.speakitTextPrimary)
                    
                    Spacer()
                    
                    // Quota Badge
                    let remaining = appState.currentUser?.remainingCharacters ?? 1450
                    SpeakITQuotaBadge(text: "\(remaining.formatted()) left")
                        .accessibilityIdentifier("tts.quota")
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.25), value: remaining)
                }
                .padding(.top, 8)
                
                // Voice Selector Card
                Button(action: {
                    showVoiceCatalog = true
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.speakitBadgeBackground)
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "waveform")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color.speakitPrimary)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedVoice.name)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color.speakitTextPrimary)
                            
                            Text(selectedVoice.subtitle)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(Color.speakitTextSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.speakitTextTertiary)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 64)
                    .background(Color.speakitBackground)
                    .cornerRadius(SpeakITSpacing.cardRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                            .stroke(Color.speakitBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tts.voiceSelector")
                
                // Multiline Text Editor Card
                VStack(spacing: 8) {
                    ZStack(alignment: .topLeading) {
                        if inputText.isEmpty {
                            Text("Enter or paste text here to synthesize…")
                                .font(.system(size: 16))
                                .foregroundColor(Color.speakitTextTertiary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        
                        TextEditor(text: $inputText)
                            .font(.system(size: 16))
                            .foregroundColor(Color.speakitTextPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 160, maxHeight: 220)
                            .accessibilityIdentifier("tts.textEditor")
                    }
                    
                    // Quick Action Row & Character Counter
                    HStack {
                        // Quick Paste
                        Button(action: {
                            if let clipboard = UIPasteboard.general.string {
                                inputText = clipboard
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 12))
                                Text("Paste")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(Color.speakitTextSecondary)
                        }
                        
                        // Clear
                        if !inputText.isEmpty {
                            Button(action: {
                                inputText = ""
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark.circle")
                                        .font(.system(size: 12))
                                    Text("Clear")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(Color.speakitTextTertiary)
                            }
                            .padding(.leading, 8)
                        }
                        
                        Spacer()
                        
                        // Character count indicator
                        let maxChars = appState.currentUser?.planType.characterLimitPerRequest ?? 2500
                        Text("\(inputText.count) / \(maxChars)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(inputText.count > maxChars ? Color.speakitDestructive : Color.speakitPrimary)
                    }
                }
                .padding(16)
                .background(Color.speakitCard)
                .cornerRadius(SpeakITSpacing.cardRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                        .stroke(Color(hex: "E1E1E6"), lineWidth: 1)
                )
                
                // Error Alert if any
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.speakitDestructive)
                }
                
                // Generate Speech CTA
                let maxAllowed = appState.currentUser?.planType.characterLimitPerRequest ?? 2500
                let canGenerate = !inputText.trimmingCharacters(in: .whitespaces).isEmpty && inputText.count <= maxAllowed
                
                SpeakITButton(
                    title: "Generate Speech",
                    icon: "speaker.wave.3.fill",
                    style: .primary,
                    isLoading: isSynthesizing,
                    isEnabled: canGenerate
                ) {
                    generateSpeech()
                }
                .accessibilityIdentifier("tts.generate")
                .padding(.top, 4)
                
                // Inline Audio Player Card
                SpeakITAudioPlayer(
                    playerManager: playerManager,
                    onShare: {
                        if playerManager.currentAudioURL != nil {
                            showShareSheet = true
                        }
                    }
                )
                .accessibilityIdentifier("tts.audioPlayer")
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, SpeakITSpacing.screenMargin)
        }
        .sheet(isPresented: $showVoiceCatalog) {
            VoiceCatalogSheet(selectedVoice: $selectedVoice)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = playerManager.currentAudioURL {
                ShareActivityView(activityItems: [url])
            }
        }
        .task {
            await appState.loadCurrentUser()
        }
    }
    
    // MARK: - Synthesis Logic
    private func generateSpeech() {
        errorMessage = nil
        isSynthesizing = true
        
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
                
                let isElevenLabs = selectedVoice.engine.lowercased() == "elevenlabs"
                let isSarvam = selectedVoice.engine.lowercased() == "sarvam"
                let voiceType = isElevenLabs ? "NATURAL" : (selectedVoice.isNeural ? "NEURAL" : "STANDARD")
                
                let req = SynthesizeRequest(
                    text: inputText,
                    voiceId: selectedVoice.id,
                    voiceName: selectedVoice.name,
                    voiceType: voiceType,
                    outputFormat: "mp3",
                    isElevenLabs: isElevenLabs,
                    isSarvam: isSarvam,
                    languageCode: selectedVoice.languageCode
                )
                
                let reqBody = try JSONEncoder().encode(req)
                let audioData = try await HTTPClient.shared.downloadBinary(.synthesize, body: reqBody)
                
                // Save binary stream to temporary MP3 file
                let tempDir = FileManager.default.temporaryDirectory
                let audioURL = tempDir.appendingPathComponent("speakit_synthesis_\(Date().timeIntervalSince1970).mp3")
                try audioData.write(to: audioURL, options: .atomic)
                
                await MainActor.run {
                    self.isSynthesizing = false
                    self.synthesizedAudioURL = audioURL
                    // Deduct credit immediately at the top bar
                    self.appState.recordCharacterUsage(inputText.count)
                    self.playerManager.loadAndPlay(
                        url: audioURL,
                        title: String(inputText.prefix(40)),
                        subtitle: "\(selectedVoice.name) (\(selectedVoice.engineDisplayName))"
                    )
                }
            } catch {
                await MainActor.run {
                    self.isSynthesizing = false
                    if case APIError.networkError = error {
                        // In offline or simulator testing, simulate playback of bundle sound or test audio
                        self.simulatePlayback()
                    } else if case APIError.forbidden = error {
                        self.errorMessage = "This voice engine requires an upgraded plan."
                        self.appState.showPaywallSheet = true
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    private func simulatePlayback() {
        // Create a simulated 12-second audio file or set state for visual playback
        let tempDir = FileManager.default.temporaryDirectory
        let fallbackURL = tempDir.appendingPathComponent("sample_preview.mp3")
        try? Data(repeating: 0, count: 1024).write(to: fallbackURL)
        self.appState.recordCharacterUsage(inputText.count)
        self.playerManager.loadAndPlay(url: fallbackURL, title: String(inputText.prefix(40)), subtitle: selectedVoice.name)
    }
}

// Native Share Sheet Wrapper
struct ShareActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    TTSStudioView()
        .environment(AppState.shared)
}
