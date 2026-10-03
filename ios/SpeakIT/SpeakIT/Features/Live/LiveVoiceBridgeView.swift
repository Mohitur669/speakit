//
//  LiveVoiceBridgeView.swift
//  SpeakIT
//
//  Phase 4: Live Voice Bridge — real-time AI voice conversion.
//  Sarvam STT (live microphone) → ElevenLabs Flash TTS (AI voice) → audio playback.
//
//  Flow: Mic → Sarvam live STT → final transcript → ElevenLabs live TTS WebSocket
//        → binary MP3 audio → AVAudioEngine playback (< 800ms end-to-end target)
//
//  Plan Gate: PRO_PLUS only.
//  Accessible via navigation push from LiveTranscriptionView.
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Voice Bridge Mode

/// The active state of the Voice Bridge pipeline.
private enum BridgeState {
    case idle
    case listening          // Sarvam STT capturing microphone
    case converting         // Text sent to ElevenLabs TTS, awaiting audio
    case playing            // Audio streaming/playing
    case error(String)
}

// MARK: - LiveVoiceBridgeView

struct LiveVoiceBridgeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    // STT service for mic capture
    @State private var liveSTT = SarvamLiveSTTService()

    // TTS service for AI voice output
    @State private var liveTTS = ElevenLabsLiveStreamTTSService()

    // Selected ElevenLabs voice for output
    @State private var selectedVoice: Voice = Voice.elevenLabsFallback

    // STT language picker
    @State private var sourceLanguage: String = "en-IN"

    // UI state
    @State private var bridgeState: BridgeState = .idle
    @State private var lastSpokenText: String = ""
    @State private var showVoicePicker: Bool = false
    @State private var showLanguagePicker: Bool = false
    @State private var errorMessage: String? = nil

    // Waveform animation
    @State private var waveformPhase: Double = 0.0
    private let waveformTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    // Available source languages for STT
    private let availableLanguages: [(code: String, name: String)] = [
        ("en-IN", "English 🇬🇧"),
        ("hi-IN", "Hindi 🇮🇳"),
        ("ta-IN", "Tamil"),
        ("te-IN", "Telugu"),
        ("bn-IN", "Bengali"),
        ("mr-IN", "Marathi"),
        ("gu-IN", "Gujarati"),
        ("kn-IN", "Kannada"),
        ("pa-IN", "Punjabi"),
        ("auto", "Auto Detect")
    ]

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            ScrollView {
                VStack(spacing: 16) {
                    if !appState.isVoiceBridgeEnabled {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Color.speakitWarning)
                            Text("Voice Bridge is currently disabled by system administrator.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.speakitTextSecondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.speakitWarning.opacity(0.12))
                        .cornerRadius(SpeakITSpacing.cardRadius)
                    }
                    
                    planGateCard
                    voiceConfigCard
                    waveformCard
                    transcriptCard
                    controlButton
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
                .padding(.bottom, 32)
            }
        }
        .background(Color.speakitScreenBackground.ignoresSafeArea())
        .sheet(isPresented: $showVoicePicker) {
            VoiceBridgeVoicePickerSheet(selectedVoice: $selectedVoice)
        }
        .onChange(of: liveSTT.committedSegments.count) { _, _ in
            // React to each newly committed (finalized) segment
            if let lastSegment = liveSTT.committedSegments.last,
               !lastSegment.isTranslation {
                onFinalTranscript(lastSegment.text)
            }
        }
        .onChange(of: liveTTS.lastError) { _, err in
            if let err { errorMessage = err }
        }
        .onChange(of: liveSTT.errorMessage) { _, err in
            if let err { errorMessage = err }
        }
        .onReceive(waveformTimer) { _ in
            waveformPhase += 0.12
        }
        .onDisappear {
            stopBridge()
        }
        .speakITToast(message: $errorMessage, style: .error, bottomPadding: 16)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .center) {
            Text("Voice Bridge")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color.speakitTextPrimary)

            Spacer()

            let remaining = appState.currentUser?.remainingCharacters ?? 0
            SpeakITQuotaBadge(text: "\(remaining.formatted()) left")
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.25), value: remaining)
        }
        .padding(.horizontal, SpeakITSpacing.screenMargin)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Plan Gate Card

    @ViewBuilder
    private var planGateCard: some View {
        let plan = appState.currentUser?.planType ?? .free
        if plan < PlanType.proPlus {
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
                        Text("Pro Plus Required")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.speakitTextPrimary)
                        Text("Voice Bridge converts your voice into an AI voice in real time. Upgrade to unlock this feature.")
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
                        Text("Upgrade to Pro Plus")
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
    }

    // MARK: - Voice Configuration Card

    private var voiceConfigCard: some View {
        VStack(spacing: 12) {
            // AI Output Voice selector
            Button(action: {
                HapticManager.shared.selection()
                showVoicePicker = true
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.speakitPrimary.opacity(0.12))
                            .frame(width: 38, height: 38)
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.speakitPrimary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Output Voice")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.speakitTextTertiary)
                        Text(selectedVoice.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.speakitTextPrimary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.speakitTextTertiary)
                }
            }
            .buttonStyle(.plain)

            Divider()
                .background(Color.speakitBorder)

            // Source language selector
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.speakitBadgeBackground)
                        .frame(width: 38, height: 38)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.speakitPrimary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Microphone Language")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.speakitTextTertiary)
                    Menu {
                        ForEach(availableLanguages, id: \.code) { lang in
                            Button(lang.name) {
                                sourceLanguage = lang.code
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(availableLanguages.first(where: { $0.code == sourceLanguage })?.name ?? sourceLanguage)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.speakitTextPrimary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color.speakitTextTertiary)
                        }
                    }
                }
                Spacer()
            }
        }
        .padding(14)
        .background(Color.speakitCardSurface)
        .cornerRadius(SpeakITSpacing.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                .stroke(Color.speakitBorder, lineWidth: 1)
        )
    }

    // MARK: - Waveform Card

    private var waveformCard: some View {
        VStack(spacing: 10) {
            // Status label
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isActiveState ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                               value: isActiveState)
                Text(statusLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.speakitTextSecondary)
                Spacer()
                // Bytes received indicator
                if liveTTS.bytesReceived > 0 {
                    Text("\(liveTTS.bytesReceived / 1024) KB received")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color.speakitTextTertiary)
                }
            }

            // Waveform bars
            HStack(spacing: 3) {
                ForEach(0..<24, id: \.self) { i in
                    waveformBar(index: i)
                }
            }
            .frame(height: 52)
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .background(Color.speakitCardSurface)
        .cornerRadius(SpeakITSpacing.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                .stroke(Color.speakitBorder, lineWidth: 1)
        )
    }

    private func waveformBar(index: Int) -> some View {
        let phase = waveformPhase + Double(index) * 0.4
        let sttLevel = Double(liveSTT.audioLevel)
        let ttsLevel = Double(liveTTS.audioLevel)
        let combinedLevel = max(sttLevel, ttsLevel)
        let amplitude: Double = isActiveState ? combinedLevel * 0.7 + 0.15 : 0.08
        let height = amplitude * (0.5 + 0.5 * sin(phase)) * 44.0 + 4.0

        return RoundedRectangle(cornerRadius: 2)
            .fill(barColor(for: index))
            .frame(width: 3, height: CGFloat(max(4, height)))
            .animation(.easeInOut(duration: 0.08), value: height)
    }

    private func barColor(for index: Int) -> Color {
        switch bridgeState {
        case .listening: return Color.speakitPrimary.opacity(0.5 + 0.5 * Double(index % 3) / 2.0)
        case .converting: return Color.orange.opacity(0.6)
        case .playing: return Color.green.opacity(0.5 + 0.5 * Double(index % 5) / 4.0)
        default: return Color.speakitTextTertiary.opacity(0.3)
        }
    }

    // MARK: - Transcript Card

    @ViewBuilder
    private var transcriptCard: some View {
        if !lastSpokenText.isEmpty || !liveSTT.fullTranscriptText.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Last spoken")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.speakitTextTertiary)

                // Partial live transcript
                if !liveSTT.partialTranscript.isEmpty {
                    Text(liveSTT.partialTranscript)
                        .font(.system(size: 14))
                        .foregroundColor(Color.speakitTextSecondary)
                        .italic()
                }

                // Last committed text sent to TTS
                if !lastSpokenText.isEmpty {
                    Text(lastSpokenText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.speakitTextPrimary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.speakitCardSurface)
            .cornerRadius(SpeakITSpacing.cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                    .stroke(Color.speakitBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Control Button

    private var controlButton: some View {
        let plan = appState.currentUser?.planType ?? .free
        let isPro = plan >= PlanType.proPlus
        let isRunning = isActiveState
        let isEnabled = (isRunning || (isPro && appState.isVoiceBridgeEnabled))

        return SpeakITButton(
            title: isRunning ? "Stop Voice Bridge" : "Start Voice Bridge",
            icon: isRunning ? "stop.circle.fill" : "waveform.badge.mic",
            style: (isRunning || !isPro || !appState.isVoiceBridgeEnabled) ? .secondary : .primary,
            isLoading: false,
            isEnabled: isEnabled
        ) {
            if isRunning {
                stopBridge()
            } else {
                startBridge()
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Bridge Logic

    private func startBridge() {
        guard appState.isVoiceBridgeEnabled else {
            errorMessage = "Voice Bridge is currently disabled by system administrator."
            return
        }

        guard let token = KeychainHelper.shared.getToken() else {
            errorMessage = "Authentication required. Please sign in again."
            return
        }

        // Validate ElevenLabs voice
        let voiceId = selectedVoice.id
        guard selectedVoice.engine.lowercased() == "elevenlabs" else {
            errorMessage = "Please select an ElevenLabs voice for AI voice output."
            showVoicePicker = true
            return
        }

        HapticManager.shared.success()
        bridgeState = .listening

        // Start ElevenLabs TTS WebSocket
        liveTTS.connect(voiceId: voiceId, token: token)

        // Configure and start Sarvam live STT
        liveSTT.languageCode = sourceLanguage
        liveSTT.mode = "transcribe"
        Task {
            await liveSTT.startSession()
        }
    }

    private func stopBridge() {
        liveSTT.stopSession()
        liveTTS.disconnect()
        bridgeState = .idle
        HapticManager.shared.selection()
    }

    /// Called when Sarvam STT finalizes a sentence segment.
    private func onFinalTranscript(_ text: String) {
        guard !text.isEmpty else { return }
        lastSpokenText = text

        // Track character usage for billing
        appState.recordCharacterUsage(text.count)

        // Forward to ElevenLabs TTS if bridge is active
        guard liveTTS.isConnected else { return }

        bridgeState = .converting
        liveTTS.sendText(text)

        // Transition to playing state with a short delay (TTS latency ~75ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if case .converting = self.bridgeState {
                self.bridgeState = .playing
            }
        }
    }

    // MARK: - Computed State Helpers

    private var isActiveState: Bool {
        switch bridgeState {
        case .listening, .converting, .playing: return true
        default: return false
        }
    }

    private var statusLabel: String {
        switch bridgeState {
        case .idle: return "Ready — tap Start to begin"
        case .listening: return "Listening…"
        case .converting: return "Converting to AI voice…"
        case .playing: return "Playing AI voice output"
        case .error(let msg): return "Error: \(msg)"
        }
    }

    private var statusColor: Color {
        switch bridgeState {
        case .idle: return Color.speakitTextTertiary
        case .listening: return Color.speakitPrimary
        case .converting: return .orange
        case .playing: return .green
        case .error: return Color.speakitDestructive
        }
    }
}

// MARK: - Voice Picker Sheet for Bridge

/// Filtered voice picker showing only ElevenLabs voices (required for live TTS streaming).
private struct VoiceBridgeVoicePickerSheet: View {
    @Binding var selectedVoice: Voice
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var voices: [Voice] = []
    @State private var isLoading: Bool = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading voices…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if voices.isEmpty {
                    ContentUnavailableView(
                        "No ElevenLabs Voices",
                        systemImage: "waveform.slash",
                        description: Text("Voice Bridge requires an ElevenLabs voice. Check your plan or API configuration.")
                    )
                } else {
                    List(voices) { voice in
                        Button(action: {
                            selectedVoice = voice
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.speakitBadgeBackground)
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "waveform")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color.speakitPrimary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(voice.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color.speakitTextPrimary)
                                    Text("\(voice.gender) · \(voice.languageName)")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.speakitTextSecondary)
                                }
                                Spacer()
                                if voice.id == selectedVoice.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color.speakitPrimary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.speakitCardSurface)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.speakitScreenBackground)
                }
            }
            .navigationTitle("Select AI Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color.speakitPrimary)
                }
            }
        }
        .task {
            await loadVoices()
        }
    }

    private func loadVoices() async {
        isLoading = true
        do {
            let allVoices: [Voice] = try await HTTPClient.shared.request(.voices)
            voices = allVoices.filter { $0.engine.lowercased() == "elevenlabs" }
        } catch {
            voices = []
        }
        isLoading = false
    }
}

// MARK: - Voice fallback for bridge

private extension Voice {
    /// Default ElevenLabs fallback voice shown until the user selects one.
    static var elevenLabsFallback: Voice {
        Voice(id: "placeholder", name: "Select AI Voice…", engine: "elevenlabs", requiresPlan: .pro)
    }
}

#Preview {
    NavigationStack {
        LiveVoiceBridgeView()
            .environment(AppState.shared)
    }
}
