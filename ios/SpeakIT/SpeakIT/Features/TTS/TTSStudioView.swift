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
    @AppStorage("autoPlayPreview") private var autoPlayPreview: Bool = true
    
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
                    HapticManager.shared.selection()
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
                    .background(Color.speakitCardSurface)
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
                                HapticManager.shared.light()
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
                                HapticManager.shared.light()
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
                        let currentPlan = appState.currentUser?.planType ?? .free
                        let maxChars = appState.getMaxCharacters(for: currentPlan)
                        Text("\(inputText.count) / \(maxChars)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(inputText.count > maxChars ? Color.speakitDestructive : Color.speakitPrimary)
                    }
                }
                .padding(16)
                .background(Color.speakitCardSurface)
                .cornerRadius(SpeakITSpacing.cardRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                        .stroke(Color.speakitBorder, lineWidth: 1)
                )
                
                let currentPlan = appState.currentUser?.planType ?? .free
                let maxChars = appState.getMaxCharacters(for: currentPlan)
                let isVoiceLocked = currentPlan < selectedVoice.requiresPlan
                let isCharLimitExceeded = inputText.count > maxChars
                
                // Plan Feature Lock Card for Selected Voice
                if isVoiceLocked {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.speakitPrimary.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color.speakitPrimary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(selectedVoice.name) requires \(selectedVoice.requiresPlan.displayName)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color.speakitTextPrimary)
                                Text("Standard voices are available in Free. Upgrade to unlock \(selectedVoice.engineDisplayName) AI voices.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.speakitTextSecondary)
                            }
                        }
                        
                        Button(action: {
                            HapticManager.shared.selection()
                            appState.showPaywallSheet = true
                        }) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Upgrade to \(selectedVoice.requiresPlan.displayName)")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color.speakitPrimary)
                            .cornerRadius(10)
                        }
                    }
                    .padding(14)
                    .background(Color.speakitCardSurface)
                    .cornerRadius(SpeakITSpacing.cardRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                            .stroke(Color.speakitPrimary.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // Character Limit Warning & Upgrade Card
                if isCharLimitExceeded {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.speakitWarning.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color.speakitWarning)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Character limit exceeded (\(inputText.count)/\(maxChars))")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color.speakitTextPrimary)
                                Text("\(currentPlan.displayName) allows up to \(maxChars) characters per request. Upgrade for up to 2,000 characters.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.speakitTextSecondary)
                            }
                        }
                        
                        Button(action: {
                            HapticManager.shared.selection()
                            appState.showPaywallSheet = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Upgrade Plan for Higher Limits")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color.speakitPrimary)
                            .cornerRadius(10)
                        }
                    }
                    .padding(14)
                    .background(Color.speakitCardSurface)
                    .cornerRadius(SpeakITSpacing.cardRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                            .stroke(Color.speakitWarning.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // Generate Speech CTA
                let canGenerate = !inputText.trimmingCharacters(in: .whitespaces).isEmpty && !isVoiceLocked && !isCharLimitExceeded
                let buttonTitle: String = {
                    if isVoiceLocked {
                        return "Locked — \(selectedVoice.requiresPlan.displayName) Required"
                    } else if isCharLimitExceeded {
                        return "Exceeds \(maxChars) Characters"
                    } else {
                        return "Generate Speech"
                    }
                }()
                
                SpeakITButton(
                    title: buttonTitle,
                    icon: isVoiceLocked ? "lock.fill" : "speaker.wave.3.fill",
                    style: canGenerate ? .primary : .secondary,
                    isLoading: isSynthesizing,
                    isEnabled: canGenerate
                ) {
                    generateSpeech()
                }
                .accessibilityIdentifier("tts.generate")
                .padding(.top, 4)
                .padding(.bottom, synthesizedAudioURL == nil ? 32 : 0)
                
                // Inline Audio Player Card (Only visible once speech has been generated)
                if synthesizedAudioURL != nil {
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
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, SpeakITSpacing.screenMargin)
        }
        .background(Color.speakitScreenBackground.ignoresSafeArea())
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
            await appState.loadPlanPricing()
        }
        .speakITToast(message: $errorMessage, style: .error, bottomPadding: 16)
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
                
                // Save binary stream to temporary MP3 file (integer timestamp avoids floating-point dots in filename)
                let tempDir = FileManager.default.temporaryDirectory
                let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
                let audioURL = tempDir.appendingPathComponent("speakit_synthesis_\(timestamp).mp3")
                try audioData.write(to: audioURL, options: .atomic)
                
                await MainActor.run {
                    self.isSynthesizing = false
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        self.synthesizedAudioURL = audioURL
                    }
                    // Deduct credit immediately at the top bar
                    self.appState.recordCharacterUsage(inputText.count)
                    HapticManager.shared.success()
                    self.playerManager.load(
                        url: audioURL,
                        title: String(inputText.prefix(40)),
                        subtitle: "\(selectedVoice.name) (\(selectedVoice.engineDisplayName))",
                        autoPlay: self.autoPlayPreview
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
                        HapticManager.shared.warning()
                    } else {
                        self.errorMessage = error.userFriendlyMessage
                        HapticManager.shared.error()
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
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            self.synthesizedAudioURL = fallbackURL
        }
        self.playerManager.load(
            url: fallbackURL,
            title: String(inputText.prefix(40)),
            subtitle: selectedVoice.name,
            autoPlay: self.autoPlayPreview
        )
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
