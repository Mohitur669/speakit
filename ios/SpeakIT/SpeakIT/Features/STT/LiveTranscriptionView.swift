//
//  LiveTranscriptionView.swift
//  SpeakIT
//
//  Live real-time speech transcription, translation & Face-to-Face Conversation (Option 3 in iOS Navigation).
//  Features dynamic audio waveform visualizer, continuous caption streaming,
//  Face-to-Face two-person interpreter mode, plan gating, and instant session export.
//

import SwiftUI
import AVFoundation

enum LiveStudioMode: String, CaseIterable, Identifiable {
    case conversation = "Face-to-Face"
    case solo = "Solo Dictation"
    
    var id: String { rawValue }
}

enum SpeakerSide: String {
    case personA = "Speaker 1"
    case personB = "Speaker 2"
}

struct ConversationBubble: Identifiable {
    let id = UUID()
    let speakerSide: SpeakerSide
    let speakerName: String
    let speakerLanguage: String
    let targetLanguage: String
    let originalText: String
    var translatedText: String
    var isTranslating: Bool = false
    let timestamp: Date = Date()
}

final class LocalSpeechSpeaker: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = LocalSpeechSpeaker()
    private let synthesizer = AVSpeechSynthesizer()
    
    override private init() {
        super.init()
        synthesizer.delegate = self
    }
    
    func speak(text: String, languageCode: String = "en-US") {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // Industry Standard (Apple Audio Session Guidelines for Live Speech):
        // 1. Force audio output to primary loudspeaker (bypassing the telephone earpiece receiver)
        // 2. Use .spokenAudio mode to apply speech-optimized dynamic range compression and loudness normalization
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
            try session.overrideOutputAudioPort(.speaker)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("LocalSpeechSpeaker: Audio session routing failed: \(error)")
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0 // Full digital gain
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.04 // Prevents clipping initial phonemes on hardware DAC wake
        
        let bcp47 = languageCode == "auto" ? "en-US" : languageCode
        utterance.voice = AVSpeechSynthesisVoice(language: bcp47) ?? AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }
}

struct LiveTranscriptionView: View {
    @Environment(AppState.self) private var appState
    @State private var liveService = SarvamLiveSTTService()
    
    @State private var studioMode: LiveStudioMode = .conversation
    @State private var showClearConfirmation: Bool = false
    @State private var copiedToClipboard: Bool = false
    @State private var bannerMessage: String? = nil
    
    // Conversation Mode States & Editable Speaker Names
    @State private var isConversationSessionStarted: Bool = false
    @State private var sessionTitle: String = ""
    @State private var showNewSessionConfirmation: Bool = false
    
    @State private var speaker1Name: String = "Speaker 1"
    @State private var speaker2Name: String = "Speaker 2"
    @State private var editingSpeaker: SpeakerSide? = nil
    @State private var tempSpeakerName: String = ""
    @State private var showRenameAlert: Bool = false
    
    @State private var personALang: String = "hi-IN"
    @State private var personBLang: String = "en-IN"
    @State private var activeSpeaker: SpeakerSide? = nil
    @State private var conversationHistory: [ConversationBubble] = []
    @State private var swapRotation: Double = 0
    
    // Previous Sessions Hub & Duplicate Save Guard
    @State private var previousLiveSessions: [HistoryItem] = []
    @State private var isLoadingPreviousSessions: Bool = false
    @State private var currentSessionId: Int64? = nil
    @State private var lastPersistedTranscript: String? = nil
    @State private var isPersistingSession: Bool = false
    
    private let availableLanguages: [(code: String, name: String)] = [
        ("auto", "Auto (Detect)"),
        ("hi-IN", "Hindi"),
        ("en-IN", "English"),
        ("ta-IN", "Tamil"),
        ("te-IN", "Telugu"),
        ("bn-IN", "Bengali"),
        ("mr-IN", "Marathi"),
        ("gu-IN", "Gujarati"),
        ("kn-IN", "Kannada"),
        ("ml-IN", "Malayalam"),
        ("pa-IN", "Punjabi"),
        ("or-IN", "Odia")
    ]
    
    @State private var showVoiceBridge: Bool = false
    
    private var currentUserPlan: PlanType {
        appState.currentUser?.planType ?? .free
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Row (Matches TTSStudioView and STTStudioView design language)
            HStack(alignment: .center) {
                Text("Live Studio")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(Color.speakitTextPrimary)
                
                Spacer()
                
                // Real-time Live Quota Badge
                let remaining = appState.currentUser?.remainingCharacters ?? 1450
                SpeakITQuotaBadge(text: "\(remaining.formatted()) left")
                    .accessibilityIdentifier("live.quota")
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.25), value: remaining)
                
                // Phase 4: Voice Bridge entry point — pushes LiveVoiceBridgeView (gated by VOICE_BRIDGE_FLAG)
                if appState.isVoiceBridgeEnabled {
                    NavigationLink(destination: LiveVoiceBridgeView()) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color.speakitPrimary)
                            .padding(.leading, 6)
                    }
                    .accessibilityLabel("Voice Bridge")
                }
                
                if canExport {
                    exportMenuButton
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal, SpeakITSpacing.screenMargin)
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            // Top Mode Switcher: Solo Dictation vs Face-to-Face
            modeSwitcherBar
                .padding(.horizontal, SpeakITSpacing.screenMargin)
                .padding(.bottom, 10)
            
            if studioMode == .solo {
                // Header & Settings Strip for Solo
                soloHeaderControlsStrip
                    .padding(.horizontal, SpeakITSpacing.screenMargin)
                    .padding(.vertical, 6)
                
                // Real-time Audio Level Waveform
                liveWaveformVisualizer
                    .padding(.vertical, 4)
                
                // Live Captioning Area
                transcriptScrollArea
                
                // Bottom Dock with Big Record Button
                soloBottomDock
            } else {
                // Face-to-Face Two-Person Conversation Mode
                conversationView
            }
        }
        .background(Color.speakitScreenBackground.ignoresSafeArea())
        .alert("Clear Live Session", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                persistCurrentSessionHistory()
                liveService.clearTranscript()
                conversationHistory.removeAll()
            }
        } message: {
            Text("Are you sure you want to clear the current live session history?")
        }
        .alert("Rename Speaker", isPresented: $showRenameAlert) {
            TextField("Speaker Name", text: $tempSpeakerName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = tempSpeakerName.trimmingCharacters(in: .whitespacesAndNewlines)
                if editingSpeaker == .personA {
                    speaker1Name = trimmed.isEmpty ? "Speaker 1" : trimmed
                } else if editingSpeaker == .personB {
                    speaker2Name = trimmed.isEmpty ? "Speaker 2" : trimmed
                }
            }
        } message: {
            Text("Enter a custom name for this speaker.")
        }
        .alert("Start New Session?", isPresented: $showNewSessionConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Save & Start New", role: .none) {
                persistCurrentSessionHistory()
                conversationHistory.removeAll()
                sessionTitle = ""
                withAnimation {
                    isConversationSessionStarted = false
                }
            }
        } message: {
            Text("Your current conversation will be saved to your Activity history logs.")
        }
        .speakITToast(message: $liveService.errorMessage, style: .error, bottomPadding: 90)
        .speakITToast(message: $bannerMessage, style: .info, bottomPadding: 90)
        .onAppear {
            Task {
                await fetchPreviousLiveSessions()
            }
        }
        .onDisappear {
            if liveService.isRecording {
                liveService.stopSession()
            }
            persistCurrentSessionHistory()
        }
    }
    
    private var exportMenuButton: some View {
        Menu {
            Button(action: {
                persistCurrentSessionHistory()
                withAnimation {
                    bannerMessage = "Live session saved to Activity history."
                }
                HapticManager.shared.success()
            }) {
                Label("Save to History", systemImage: "square.and.arrow.down")
            }
            
            Button(action: copyAllTranscript) {
                Label("Copy All Text", systemImage: "doc.on.doc")
            }
            
            ShareLink(item: exportContent, subject: Text("SpeakIT Live Session")) {
                Label("Share Transcript", systemImage: "square.and.arrow.up")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                showClearConfirmation = true
            }) {
                Label("Clear All", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color.speakitTextSecondary)
                .frame(width: 36, height: 36)
                .background(Color.speakitCardSurface)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.speakitBorder, lineWidth: 1))
        }
    }
    
    private var canExport: Bool {
        if studioMode == .solo {
            return !liveService.committedSegments.isEmpty || !liveService.partialTranscript.isEmpty
        } else {
            return !conversationHistory.isEmpty
        }
    }
    
    private var exportContent: String {
        if studioMode == .solo {
            return liveService.fullTranscriptText
        } else {
            return conversationHistory.map { bubble in
                "[\(bubble.speakerName) - \(bubble.speakerLanguage)]\nOriginal: \(bubble.originalText)\nTranslated: \(bubble.translatedText)\n"
            }.joined(separator: "\n")
        }
    }
    
    // MARK: - 1. Top Mode Switcher Bar
    private var modeSwitcherBar: some View {
        HStack(spacing: 0) {
            ForEach(LiveStudioMode.allCases) { mode in
                let isSelected = studioMode == mode
                Button(action: {
                    HapticManager.shared.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        studioMode = mode
                    }
                    if liveService.isRecording {
                        liveService.stopSession()
                    }
                    if mode == .conversation && !currentUserPlan.allowsLiveTranslation {
                        bannerMessage = "Face-to-Face Conversation requires Pro Plus."
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: mode == .solo ? "waveform.badge.mic" : "person.2.wave.2.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text(mode.rawValue)
                            .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    }
                    .foregroundColor(isSelected ? Color.speakitPrimary : Color.speakitTextSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(isSelected ? Color.speakitCardSurface : Color.clear)
                    .cornerRadius(19)
                    .overlay(
                        RoundedRectangle(cornerRadius: 19)
                            .stroke(isSelected ? Color.speakitBorder : Color.clear, lineWidth: 1)
                    )
                    .shadow(color: isSelected ? Color.black.opacity(0.06) : Color.clear, radius: 4, x: 0, y: 2)
                }
            }
        }
        .padding(3)
        .background(Color.speakitCard)
        .cornerRadius(22)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.speakitBorder, lineWidth: 1)
        )
    }
    
    // MARK: - 2. Solo Header Strip
    private var soloHeaderControlsStrip: some View {
        HStack(spacing: 10) {
            // Mode Dropdown Menu: Transcribe vs Translate
            Menu {
                Button(action: {
                    guard liveService.mode != "transcribe" else { return }
                    HapticManager.shared.selection()
                    liveService.mode = "transcribe"
                }) {
                    HStack {
                        Label("Transcribe", systemImage: "waveform")
                        if liveService.mode == "transcribe" {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                Button(action: {
                    guard liveService.mode != "translate" else { return }
                    if !currentUserPlan.allowsLiveTranslation {
                        HapticManager.shared.warning()
                        appState.showPaywallSheet = true
                        bannerMessage = "Live Translation requires Pro Plus or Enterprise."
                        return
                    }
                    HapticManager.shared.selection()
                    liveService.mode = "translate"
                }) {
                    HStack {
                        if !currentUserPlan.allowsLiveTranslation {
                            Label("Translate (Pro Plus)", systemImage: "lock.fill")
                        } else {
                            Label("Translate", systemImage: "character.bubble")
                        }
                        if liveService.mode == "translate" {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: liveService.mode == "translate" ? "character.bubble" : "waveform")
                        .font(.system(size: 12, weight: .semibold))
                    Text(liveService.mode == "translate" ? "Translate" : "Transcribe")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(Color.speakitTextPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.speakitCardSurface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.speakitBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(liveService.isRecording)
            
            Spacer()
            
            // Language Picker Menu
            Menu {
                ForEach(availableLanguages, id: \.code) { item in
                    Button(action: {
                        HapticManager.shared.selection()
                        liveService.languageCode = item.code
                    }) {
                        HStack {
                            Text(item.name)
                            if liveService.languageCode == item.code {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "globe")
                        .font(.system(size: 12, weight: .semibold))
                    Text(availableLanguages.first(where: { $0.code == liveService.languageCode })?.name ?? "Language")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(Color.speakitPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.speakitBadgeBackground)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.speakitPrimary.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(liveService.isRecording)
        }
    }
    
    // MARK: - 3. Dynamic Audio Waveform Visualizer
    private var liveWaveformVisualizer: some View {
        HStack(spacing: 5) {
            ForEach(0..<11, id: \.self) { i in
                let factor = Float(sin(Double(i) * 0.7 + Double(Date().timeIntervalSince1970 * 5)))
                let height = liveService.isRecording
                    ? max(6, CGFloat(liveService.audioLevel * 44 * (0.5 + abs(factor) * 0.6)))
                    : 4
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        liveService.isRecording
                            ? LinearGradient(
                                colors: [Color.speakitPrimary, Color(hex: "818CF8")],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                            : LinearGradient(
                                colors: [Color.speakitBorder, Color.speakitBorder],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                    )
                    .frame(width: 4, height: height)
                    .animation(.easeOut(duration: 0.12), value: liveService.audioLevel)
            }
        }
        .frame(height: 38)
    }
    
    // MARK: - 4. Live Caption Area (Solo)
    private var transcriptScrollArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if liveService.committedSegments.isEmpty && liveService.partialTranscript.isEmpty {
                        soloEmptyState
                    } else {
                        ForEach(liveService.committedSegments) { segment in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(segment.timeString)
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundColor(Color.speakitTextTertiary)
                                    
                                    if segment.isTranslation {
                                        Text("EN")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.speakitPrimary)
                                            .clipShape(Capsule())
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        LocalSpeechSpeaker.shared.speak(text: segment.text)
                                    }) {
                                        Image(systemName: "speaker.wave.2")
                                            .font(.system(size: 13))
                                            .foregroundColor(Color.speakitPrimary)
                                    }
                                }
                                
                                Text(segment.text)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.speakitTextPrimary)
                                    .lineSpacing(4)
                                    .textSelection(.enabled)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.speakitCardSurface)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.speakitBorder, lineWidth: 1)
                            )
                            .id(segment.id)
                        }
                        
                        if !liveService.partialTranscript.isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(Color.speakitPrimary)
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 6)
                                
                                Text(liveService.partialTranscript)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(Color.speakitTextPrimary)
                                    .lineSpacing(4)
                                    .italic()
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.speakitBadgeBackground.opacity(0.6))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.speakitPrimary.opacity(0.3), lineWidth: 1)
                            )
                            .id("partial")
                        }
                    }
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
                .padding(.vertical, 12)
            }
            .onChange(of: liveService.committedSegments.count) { oldCount, newCount in
                if newCount > oldCount, let last = liveService.committedSegments.last {
                    appState.recordCharacterUsage(last.text.count)
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: liveService.partialTranscript) { _, _ in
                withAnimation {
                    proxy.scrollTo("partial", anchor: .bottom)
                }
            }
        }
    }
    
    private var soloEmptyState: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 40)
            
            ZStack {
                Circle()
                    .fill(Color.speakitBadgeBackground)
                    .frame(width: 72, height: 72)
                
                Image(systemName: "waveform.badge.mic")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(Color.speakitPrimary)
            }
            
            VStack(spacing: 4) {
                Text(liveService.mode == "translate" ? "Live English Translation" : "Live Speech Transcription")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.speakitTextPrimary)
                
                Text("Tap the record button below and begin speaking in your natural language. Real-time captions will stream instantly.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.speakitTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            // Plan Quota Badge
            HStack(spacing: 6) {
                Image(systemName: currentUserPlan.allowsLiveTranscription ? "checkmark.seal.fill" : "lock.fill")
                    .font(.system(size: 11))
                Text(currentUserPlan.allowsLiveTranscription
                     ? "\(currentUserPlan.displayName) Plan: \(currentUserPlan.liveMinutesMonthlyQuota) mins/mo live"
                     : "Free Plan: Upgrade to Pro for Live mode")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(currentUserPlan.allowsLiveTranscription ? Color.speakitPrimary : Color.speakitTextSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.speakitCardSurface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.speakitBorder, lineWidth: 1))
            
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 5. Solo Bottom Dock
    private var soloBottomDock: some View {
        VStack(spacing: 12) {
            if liveService.isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text(formatSeconds(liveService.elapsedSeconds))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.speakitTextPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.speakitCardSurface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.speakitBorder, lineWidth: 1))
                .transition(.scale.combined(with: .opacity))
            }
            
            Button(action: {
                if liveService.isRecording {
                    let text = liveService.fullTranscriptText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        appState.recordCharacterUsage(text.count)
                    }
                    liveService.stopSession()
                    persistCurrentSessionHistory()
                } else {
                    if !currentUserPlan.allowsLiveTranscription {
                        HapticManager.shared.warning()
                        appState.showPaywallSheet = true
                        bannerMessage = "Live Transcription requires a Pro plan or higher."
                        return
                    }
                    if let user = appState.currentUser, user.remainingCharacters <= 0 {
                        HapticManager.shared.warning()
                        appState.showPaywallSheet = true
                        bannerMessage = "Character quota exhausted. Please upgrade your plan."
                        return
                    }
                    Task {
                        await liveService.startSession()
                    }
                }
            }) {
                ZStack {
                    if liveService.isRecording {
                        Circle()
                            .stroke(Color.red.opacity(0.3), lineWidth: 4)
                            .frame(width: 84, height: 84)
                        
                        Circle()
                            .fill(Color.red)
                            .frame(width: 68, height: 68)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .frame(width: 22, height: 22)
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.speakitPrimary, Color(hex: "4338CA")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 68, height: 68)
                            .shadow(color: Color.speakitPrimary.opacity(0.35), radius: 10, y: 4)
                        
                        Image(systemName: "mic.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(liveService.isRecording ? "Stop Live Session" : "Start Live Session")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
    
    // MARK: - 6. Face-to-Face Two-Person Conversation View
    private var conversationView: some View {
        VStack(spacing: 0) {
            if !isConversationSessionStarted {
                faceToFaceSessionLauncher
            } else {
                activeConversationDialogueView
            }
        }
    }
    
    // MARK: - Active Session Top Toolbar
    private var activeConversationTopBar: some View {
        HStack(spacing: 8) {
            // Live indicator & title
            HStack(spacing: 6) {
                Circle()
                    .fill(liveService.isRecording ? Color.red : Color.speakitSuccess)
                    .frame(width: 8, height: 8)
                
                Text(resolvedSessionTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.speakitTextPrimary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // "New Session" button
            Button(action: {
                showNewSessionConfirmation = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text("New")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(Color.speakitPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.speakitBadgeBackground)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            // "End & Save" button
            Button(action: {
                persistCurrentSessionHistory()
                withAnimation {
                    isConversationSessionStarted = false
                    conversationHistory.removeAll()
                    sessionTitle = ""
                    currentSessionId = nil
                    lastPersistedTranscript = nil
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("End")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(Color.speakitTextSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.speakitCardSurface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.speakitBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, SpeakITSpacing.screenMargin)
        .padding(.vertical, 8)
        .background(Color.speakitCardSurface)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(Color.speakitBorder),
            alignment: .bottom
        )
    }
    
    // MARK: - Face-to-Face Session Setup Launcher
    private var faceToFaceSessionLauncher: some View {
        ScrollView {
            VStack(spacing: 24) {

                // ── Title ──────────────────────────────────────────────────
                VStack(spacing: 4) {
                    Text("New Session")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color.speakitTextPrimary)
                    Text("Set up speakers before starting.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.speakitTextSecondary)
                }
                .padding(.top, 8)

                // ── Grouped Setup Card ─────────────────────────────────────
                VStack(spacing: 0) {

                    // Session Name row
                    rowContainer {
                        HStack(spacing: 8) {
                            Text("Session Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.speakitTextPrimary)
                            Spacer()
                            TextField("Optional name…", text: $sessionTitle)
                                .font(.system(size: 13))
                                .foregroundColor(Color.speakitTextSecondary)
                                .multilineTextAlignment(.trailing)
                            
                            Button(action: {
                                HapticManager.shared.light()
                                sessionTitle = generateDefaultSessionName()
                            }) {
                                Image(systemName: "dice")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.speakitTextTertiary)
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Generate random session name")
                        }
                    }

                    rowDivider

                    // Speaker 1 row
                    rowContainer {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.speakitPrimary)
                                .frame(width: 8, height: 8)

                            HStack(spacing: 4) {
                                TextField("Speaker 1", text: $speaker1Name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.speakitTextPrimary)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)

                                Button(action: {
                                    tempSpeakerName = speaker1Name
                                    editingSpeaker = .personA
                                    showRenameAlert = true
                                }) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Color.speakitTextTertiary)
                                        .frame(width: 18, height: 18)
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(maxWidth: 170, alignment: .leading)

                            Spacer()
                            languagePicker(code: $personALang, accentColor: Color.speakitPrimary)
                        }
                    }

                    // Swap button — flush between the two speaker rows
                    HStack {
                        Spacer()
                        Button(action: {
                            HapticManager.shared.selection()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                swapRotation += 180
                                let tmp = personALang
                                personALang = personBLang
                                personBLang = tmp
                            }
                        }) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color.speakitPrimary)
                                .rotationEffect(.degrees(swapRotation))
                        }
                        .padding(.horizontal, SpeakITSpacing.screenMargin)
                        .padding(.vertical, 2)
                        Spacer()
                    }
                    .background(Color.speakitCardSurface)
                    .overlay(Rectangle().frame(height: 0.4).foregroundColor(Color.speakitBorder), alignment: .top)
                    .overlay(Rectangle().frame(height: 0.4).foregroundColor(Color.speakitBorder), alignment: .bottom)

                    // Speaker 2 row
                    rowContainer {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.speakitSecondary)
                                .frame(width: 8, height: 8)

                            HStack(spacing: 4) {
                                TextField("Speaker 2", text: $speaker2Name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.speakitTextPrimary)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)

                                Button(action: {
                                    tempSpeakerName = speaker2Name
                                    editingSpeaker = .personB
                                    showRenameAlert = true
                                }) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Color.speakitTextTertiary)
                                        .frame(width: 18, height: 18)
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(maxWidth: 170, alignment: .leading)

                            Spacer()
                            languagePicker(code: $personBLang, accentColor: Color.speakitSecondary)
                        }
                    }
                }
                .background(Color.speakitCardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.speakitBorder, lineWidth: 0.5))

                // ── Start CTA ──────────────────────────────────────────────
                Button(action: {
                    if let user = appState.currentUser, user.remainingCharacters <= 0 {
                        HapticManager.shared.warning()
                        appState.showPaywallSheet = true
                        bannerMessage = "Character quota exhausted. Please upgrade your plan."
                        return
                    }
                    HapticManager.shared.success()
                    withAnimation {
                        currentSessionId = nil
                        lastPersistedTranscript = nil
                        conversationHistory.removeAll()
                        if sessionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            sessionTitle = generateDefaultSessionName()
                        }
                        isConversationSessionStarted = true
                    }
                }) {
                    Text("Start Session")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.speakitPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // ── Previous Sessions Section ──────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("PREVIOUS SESSIONS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.speakitTextTertiary)
                        
                        Spacer()
                        
                        if isLoadingPreviousSessions {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Button(action: {
                                Task {
                                    await fetchPreviousLiveSessions()
                                }
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color.speakitTextTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)
                    
                    if previousLiveSessions.isEmpty && !isLoadingPreviousSessions {
                        HStack {
                            Spacer()
                            VStack(spacing: 6) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color.speakitTextTertiary.opacity(0.6))
                                Text("No previous sessions found")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color.speakitTextSecondary)
                                Text("Completed conversations will appear here so you can continue them anytime.")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.speakitTextTertiary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 20)
                            Spacer()
                        }
                        .background(Color.speakitCardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.speakitBorder, lineWidth: 0.5))
                    } else {
                        VStack(spacing: 8) {
                            ForEach(previousLiveSessions) { item in
                                Button(action: {
                                    HapticManager.shared.selection()
                                    continuePreviousSession(item)
                                }) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.speakitBadgeBackground)
                                                .frame(width: 38, height: 38)
                                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(Color.speakitPrimary)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.liveChatTitle)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(Color.speakitTextPrimary)
                                                .lineLimit(1)
                                            
                                            HStack(spacing: 6) {
                                                Text("\(item.liveChatTurnCount) \(item.liveChatTurnCount == 1 ? "turn" : "turns")")
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundColor(Color.speakitTextSecondary)
                                                Text("•")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(Color.speakitTextTertiary)
                                                Text(item.formattedDateAndTime)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(Color.speakitTextTertiary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        // "Continue" pill action
                                        HStack(spacing: 4) {
                                            Text("Continue")
                                                .font(.system(size: 11, weight: .semibold))
                                            Image(systemName: "arrow.right")
                                                .font(.system(size: 9, weight: .bold))
                                        }
                                        .foregroundColor(Color.speakitPrimary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.speakitBadgeBackground)
                                        .clipShape(Capsule())
                                    }
                                    .padding(12)
                                    .background(Color.speakitCardSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.speakitBorder, lineWidth: 0.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, SpeakITSpacing.screenMargin)
            .padding(.bottom, 24)
        }
        .refreshable {
            await fetchPreviousLiveSessions()
        }
    }

    // MARK: - Launcher Helpers

    /// A settings-style row container with standard horizontal padding and height.
    @ViewBuilder
    private func rowContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(Color.speakitCardSurface)
    }

    private var rowDivider: some View {
        Divider()
            .padding(.leading, 14)
            .background(Color.speakitBorder)
    }

    /// Compact language picker pill — tinted with speaker accent colour.
    @ViewBuilder
    private func languagePicker(code: Binding<String>, accentColor: Color) -> some View {
        Menu {
            ForEach(availableLanguages, id: \.code) { item in
                Button(action: {
                    HapticManager.shared.selection()
                    code.wrappedValue = item.code
                }) {
                    HStack {
                        Text(item.name)
                        if code.wrappedValue == item.code {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(availableLanguages.first(where: { $0.code == code.wrappedValue })?.name ?? "—")
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundColor(accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(accentColor.opacity(0.1))
            .clipShape(Capsule())
        }
    }
    
    // MARK: - Active Conversation Dialogue View
    private var activeConversationDialogueView: some View {
        VStack(spacing: 0) {
            activeConversationTopBar
            
            // Conversation Dialogue Scroll
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(conversationHistory) { bubble in
                            conversationTurnCard(bubble)
                        }
                        
                        if liveService.isRecording, let active = activeSpeaker {
                            let liveSpeech = liveService.fullTranscriptText
                            let isSpeakerA = active == .personA
                            HStack {
                                if !isSpeakerA { Spacer(minLength: 24) }
                                VStack(alignment: isSpeakerA ? .leading : .trailing, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 8, height: 8)
                                        Text("\(isSpeakerA ? speaker1Name : speaker2Name) is speaking...")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(isSpeakerA ? Color.speakitPrimary : Color.speakitSecondary)
                                    }
                                    Text(liveSpeech.isEmpty ? "Listening for speech..." : liveSpeech)
                                        .font(.system(size: 15))
                                        .foregroundColor(liveSpeech.isEmpty ? Color.speakitTextTertiary : Color.speakitTextPrimary)
                                        .italic()
                                }
                                .padding(14)
                                .background(
                                    isSpeakerA
                                        ? Color.speakitBadgeBackground.opacity(0.7)
                                        : Color.speakitSecondary.opacity(0.12)
                                )
                                .cornerRadius(SpeakITSpacing.cardRadius)
                                .overlay(
                                    RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                                        .stroke(isSpeakerA ? Color.speakitPrimary.opacity(0.3) : Color.speakitSecondary.opacity(0.3), lineWidth: 1)
                                )
                                if isSpeakerA { Spacer(minLength: 24) }
                            }
                            .id("conv-active-turn")
                        }
                    }
                    .padding(.horizontal, SpeakITSpacing.screenMargin)
                    .padding(.vertical, 12)
                }
                .onChange(of: conversationHistory.count) { _, _ in
                    if let last = conversationHistory.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .onChange(of: liveService.fullTranscriptText) { _, _ in
                    withAnimation { proxy.scrollTo("conv-active-turn", anchor: .bottom) }
                }
            }
            
            // Dual Push-to-Talk Mic Dock
            dualConversationDock
        }
    }
    
    private func conversationTurnCard(_ bubble: ConversationBubble) -> some View {
        let isSpeakerA = bubble.speakerSide == .personA
        let bubbleColor: Color = isSpeakerA ? Color.speakitPrimary : Color.speakitSecondary
        let bubbleBg: Color = isSpeakerA
            ? Color.speakitBadgeBackground
            : Color.speakitCard
        let targetLangName = availableLanguages.first(where: { $0.code == bubble.targetLanguage })?.name ?? bubble.targetLanguage

        // Bubble corner radii: pointed corner on the speaker's side (iMessage style)
        // A = left → bottom-left corner is sharp; B = right → bottom-right corner is sharp
        let tl: CGFloat = isSpeakerA ? 4  : 18
        let tr: CGFloat = isSpeakerA ? 18 : 4
        let bl: CGFloat = 18
        let br: CGFloat = 18

        return HStack(alignment: .bottom, spacing: 8) {
            if isSpeakerA {
                // Avatar — left side
                avatarCircle(initial: String(bubble.speakerName.prefix(1)), color: bubbleColor)
            } else {
                Spacer(minLength: 44) // push B bubbles to the right
            }

            VStack(alignment: isSpeakerA ? .leading : .trailing, spacing: 4) {
                // Speaker name + timestamp row
                HStack(spacing: 6) {
                    if !isSpeakerA { Spacer() }
                    Text(bubble.speakerName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(bubbleColor)
                    Text("·")
                        .foregroundColor(Color.speakitTextTertiary)
                        .font(.system(size: 10))
                    Text(bubble.timestamp, style: .time)
                        .font(.system(size: 10))
                        .foregroundColor(Color.speakitTextTertiary)
                    if isSpeakerA { Spacer() }
                }

                // Bubble body
                VStack(alignment: isSpeakerA ? .leading : .trailing, spacing: 6) {
                    // Original text (dimmer — what was actually said)
                    Text(bubble.originalText)
                        .font(.system(size: 14))
                        .foregroundColor(isSpeakerA ? Color.speakitTextPrimary.opacity(0.75) : Color.speakitTextPrimary.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)

                    // Translation divider + translated text
                    if bubble.isTranslating {
                        HStack(spacing: 5) {
                            ProgressView()
                                .scaleEffect(0.65)
                                .tint(bubbleColor)
                            Text("Translating to \(targetLangName)…")
                                .font(.system(size: 12))
                                .foregroundColor(Color.speakitTextTertiary)
                                .italic()
                        }
                    } else if !bubble.translatedText.isEmpty && bubble.translatedText != bubble.originalText {
                        // Divider line
                        Rectangle()
                            .fill(bubbleColor.opacity(0.25))
                            .frame(height: 1)

                        HStack(alignment: .top, spacing: 6) {
                            if !isSpeakerA { Spacer() }
                            VStack(alignment: isSpeakerA ? .leading : .trailing, spacing: 2) {
                                // Language pill
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 9, weight: .bold))
                                    Text(targetLangName)
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .foregroundColor(bubbleColor)

                                // Translated text — prominent
                                Text(bubble.translatedText)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color.speakitTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                                    .multilineTextAlignment(isSpeakerA ? .leading : .trailing)
                            }
                            if isSpeakerA { Spacer() }

                            // Play translated text button
                            Button(action: {
                                HapticManager.shared.light()
                                LocalSpeechSpeaker.shared.speak(
                                    text: bubble.translatedText,
                                    languageCode: bubble.targetLanguage
                                )
                            }) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(bubbleColor)
                                    .frame(width: 30, height: 30)
                                    .background(bubbleColor.opacity(0.15))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(bubbleBg)
                .clipShape(
                    RoundedCornerShape(tl: tl, tr: tr, bl: bl, br: br)
                )
                .overlay(
                    RoundedCornerShape(tl: tl, tr: tr, bl: bl, br: br)
                        .stroke(bubbleColor.opacity(0.2), lineWidth: 1)
                )
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.76, alignment: isSpeakerA ? .leading : .trailing)

            if !isSpeakerA {
                // Avatar — right side
                avatarCircle(initial: String(bubble.speakerName.prefix(1)), color: bubbleColor)
            } else {
                Spacer(minLength: 44)
            }
        }
        .id(bubble.id)
        .transition(.asymmetric(
            insertion: .move(edge: isSpeakerA ? .leading : .trailing).combined(with: .opacity),
            removal: .opacity
        ))
    }

    /// Small avatar circle showing the speaker's initial letter.
    private func avatarCircle(initial: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: 32, height: 32)
            Text(initial.uppercased())
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
        }
    }

    // MARK: - Face-to-Face Minimal Animated Mic Button

    private struct FaceToFaceMicButton: View {
        let side: SpeakerSide
        let accentColor: Color
        let isActive: Bool
        let action: () -> Void

        @State private var isPulsing: Bool = false

        var body: some View {
            Button(action: {
                action()
            }) {
                ZStack {
                    // Minimal Voice Recorder Ambient Aura (iOS premium breathing ring)
                    if isActive {
                        Circle()
                            .stroke(Color.red.opacity(isPulsing ? 0.2 : 0.55), lineWidth: 2.5)
                            .frame(width: 76, height: 76)
                            .scaleEffect(isPulsing ? 1.16 : 0.98)

                        Circle()
                            .fill(Color.red.opacity(isPulsing ? 0.1 : 0.2))
                            .frame(width: 70, height: 70)
                            .scaleEffect(isPulsing ? 1.08 : 0.96)
                    }

                    // Main Mic Circle
                    Circle()
                        .fill(
                            isActive
                                ? LinearGradient(
                                    colors: [Color.red, Color(hex: "DC2626")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [accentColor, accentColor.opacity(0.88)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 62, height: 62)
                        .shadow(
                            color: (isActive ? Color.red : accentColor).opacity(0.35),
                            radius: isActive ? 10 : 6,
                            y: 3
                        )

                    // Voice Recorder Icon / Minimal Waveform
                    if isActive {
                        // Minimal 3-bar voice recorder waveform
                        HStack(spacing: 3.5) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white)
                                .frame(width: 3.5, height: isPulsing ? 20 : 8)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white)
                                .frame(width: 3.5, height: isPulsing ? 10 : 24)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white)
                                .frame(width: 3.5, height: isPulsing ? 22 : 12)
                        }
                        .frame(height: 26)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 82, height: 82)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isActive ? "Stop Recording" : "Record \(side == .personA ? "Speaker 1" : "Speaker 2")")
            .onChange(of: isActive) { _, active in
                if active {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isPulsing = false
                    }
                }
            }
            .onAppear {
                if isActive {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
            }
        }
    }

    private var dualConversationDock: some View {
        VStack(spacing: 12) {
            // Row 1: Dual Mics
            HStack(spacing: 8) {
                FaceToFaceMicButton(
                    side: .personA,
                    accentColor: Color.speakitPrimary,
                    isActive: liveService.isRecording && activeSpeaker == .personA
                ) {
                    handleSpeakerTurn(.personA, lang: personALang)
                }
                .frame(maxWidth: .infinity)

                // Spacer matching center swap button width (32pt) to maintain identical vertical center axis
                Color.clear
                    .frame(width: 32, height: 1)

                FaceToFaceMicButton(
                    side: .personB,
                    accentColor: Color.speakitSecondary,
                    isActive: liveService.isRecording && activeSpeaker == .personB
                ) {
                    handleSpeakerTurn(.personB, lang: personBLang)
                }
                .frame(maxWidth: .infinity)
            }

            // Row 2: Speaker Names & Languages with Swap Button at the Middle Height of Speaker & Language
            HStack(alignment: .center, spacing: 8) {
                // Speaker 1: Name + Language
                VStack(spacing: 8) {
                    Button(action: {
                        tempSpeakerName = speaker1Name
                        editingSpeaker = .personA
                        showRenameAlert = true
                    }) {
                        Text(speaker1Name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.speakitPrimary)
                            .lineLimit(1)
                            .frame(height: 20)
                    }
                    .buttonStyle(.plain)

                    Menu {
                        ForEach(availableLanguages, id: \.code) { item in
                            Button(action: {
                                HapticManager.shared.selection()
                                personALang = item.code
                            }) {
                                HStack {
                                    Text(item.name)
                                    if personALang == item.code {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(availableLanguages.first(where: { $0.code == personALang })?.name ?? "Hindi")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color.speakitTextPrimary)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Color.speakitTextSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.speakitBadgeBackground)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.speakitBorder.opacity(0.6), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(liveService.isRecording)
                }
                .frame(maxWidth: .infinity)

                // Center Interactive Language Swap Button (centered at the middle height of Speaker Name + Language)
                Button(action: {
                    HapticManager.shared.medium()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                        swapRotation += 180
                        let tempLang = personALang
                        personALang = personBLang
                        personBLang = tempLang
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.speakitCardSurface)
                            .frame(width: 32, height: 32)
                            .overlay(Circle().stroke(Color.speakitBorder, lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)

                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.speakitPrimary)
                            .rotationEffect(.degrees(swapRotation))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Swap Speaker Languages")

                // Speaker 2: Name + Language
                VStack(spacing: 8) {
                    Button(action: {
                        tempSpeakerName = speaker2Name
                        editingSpeaker = .personB
                        showRenameAlert = true
                    }) {
                        Text(speaker2Name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.speakitSecondary)
                            .lineLimit(1)
                            .frame(height: 20)
                    }
                    .buttonStyle(.plain)

                    Menu {
                        ForEach(availableLanguages, id: \.code) { item in
                            Button(action: {
                                HapticManager.shared.selection()
                                personBLang = item.code
                            }) {
                                HStack {
                                    Text(item.name)
                                    if personBLang == item.code {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(availableLanguages.first(where: { $0.code == personBLang })?.name ?? "English")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color.speakitTextPrimary)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Color.speakitTextSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.speakitSecondary.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.speakitSecondary.opacity(0.25), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(liveService.isRecording)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, SpeakITSpacing.screenMargin)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }
    
    private func handleSpeakerTurn(_ speaker: SpeakerSide, lang: String) {
        if liveService.isRecording {
            let lastText = liveService.fullTranscriptText.trimmingCharacters(in: .whitespacesAndNewlines)
            let previousSpeaker = activeSpeaker
            liveService.stopSession()
            if let active = previousSpeaker, !lastText.isEmpty {
                // Deduct remaining character credit for spoken utterance immediately
                appState.recordCharacterUsage(lastText.count)
                
                if let user = appState.currentUser, user.remainingCharacters <= 0 {
                    HapticManager.shared.warning()
                    bannerMessage = "Character credits depleted. Please upgrade your plan."
                }
                
                let sourceLang = active == .personA ? personALang : personBLang
                let targetLang = active == .personA ? personBLang : personALang
                let bubble = ConversationBubble(
                    speakerSide: active,
                    speakerName: active == .personA ? speaker1Name : speaker2Name,
                    speakerLanguage: sourceLang,
                    targetLanguage: targetLang,
                    originalText: lastText,
                    translatedText: "",
                    isTranslating: sourceLang != targetLang
                )
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                    conversationHistory.append(bubble)
                }
                
                // Automatically translate to the other speaker's language!
                translateBubble(bubbleId: bubble.id, text: lastText, from: sourceLang, to: targetLang)
            }
            activeSpeaker = nil
            
            // If user clicked the other speaker's mic, smoothly transition turn
            if previousSpeaker != speaker {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    startSpeakerTurn(speaker, lang: lang)
                }
            }
        } else {
            startSpeakerTurn(speaker, lang: lang)
        }
    }
    
    private func startSpeakerTurn(_ speaker: SpeakerSide, lang: String) {
        if !currentUserPlan.allowsLiveTranslation {
            HapticManager.shared.warning()
            appState.showPaywallSheet = true
            bannerMessage = "Face-to-Face Conversation requires Pro Plus."
            return
        }
        if let user = appState.currentUser, user.remainingCharacters <= 0 {
            HapticManager.shared.warning()
            appState.showPaywallSheet = true
            bannerMessage = "Character quota exhausted. Please upgrade your plan."
            return
        }
        HapticManager.shared.medium()
        activeSpeaker = speaker
        liveService.languageCode = lang
        // Transcribe cleanly in speaker's native tongue
        liveService.mode = "transcribe"
        liveService.clearTranscript()
        Task {
            await liveService.startSession()
        }
    }
    
    private func translateBubble(bubbleId: UUID, text: String, from sourceLang: String, to targetLang: String) {
        if sourceLang == targetLang {
            if let idx = conversationHistory.firstIndex(where: { $0.id == bubbleId }) {
                conversationHistory[idx].translatedText = text
                conversationHistory[idx].isTranslating = false
            }
            return
        }
        
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
                
                let req = TranslationRequest(
                    text: text,
                    sourceLanguage: sourceLang,
                    targetLanguage: targetLang
                )
                let reqBody = try JSONEncoder().encode(req)
                let resp: TranslationResponse = try await HTTPClient.shared.request(.translate, method: "POST", body: reqBody)
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if let idx = conversationHistory.firstIndex(where: { $0.id == bubbleId }) {
                            conversationHistory[idx].translatedText = resp.translatedText
                            conversationHistory[idx].isTranslating = false
                            
                            // Deduct remaining character credit for translated text
                            appState.recordCharacterUsage(resp.translatedText.count)
                            
                            // Automatically speak translated text in the listener's language!
                            LocalSpeechSpeaker.shared.speak(text: resp.translatedText, languageCode: targetLang)
                        }
                    }
                }
            } catch {
                print("Face-to-Face translation error: \(error)")
                await MainActor.run {
                    if let idx = conversationHistory.firstIndex(where: { $0.id == bubbleId }) {
                        conversationHistory[idx].translatedText = text
                        conversationHistory[idx].isTranslating = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func copyAllTranscript() {
        let text = exportContent
        guard !text.isEmpty else { return }
        UIPasteboard.general.string = text
        HapticManager.shared.medium()
        withAnimation {
            copiedToClipboard = true
            bannerMessage = "Session transcript copied to clipboard."
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                copiedToClipboard = false
            }
        }
    }
    
    // MARK: - Session Name Generation
    /// Generates a randomized, creative session title when the session name is blank.
    /// Combines an evocative adjective with a conversation-themed noun (e.g. "Echo Pulse", "Summit Talks", "Cosmic Orbit").
    private func generateDefaultSessionName() -> String {
        let adjectives = [
            "Cosmic", "Echo", "Summit", "Velvet", "Zenith", "Atlas", "Horizon",
            "Silver", "Aura", "Solstice", "Morning", "Beacon", "Pinnacle",
            "Nova", "Radiant", "Vibrant", "Quantum", "Cascade", "Crystal", "Golden",
            "Pacific", "Lunar", "Solar", "Amber", "Cedar", "Breeze", "Starlight"
        ]
        let nouns = [
            "Talks", "Pulse", "Dialogue", "Exchange", "Connect", "Sync",
            "Chat", "Orbit", "Session", "Forum", "Bridge", "Stream", "Circle",
            "Huddle", "Nexus", "Converse"
        ]
        let adj = adjectives.randomElement() ?? "Live"
        let noun = nouns.randomElement() ?? "Session"
        return "\(adj) \(noun)"
    }

    private var resolvedSessionTitle: String {
        let trimmed = sessionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? generateDefaultSessionName() : trimmed
    }
    
    private func persistCurrentSessionHistory() {
        if studioMode == .conversation {
            guard !conversationHistory.isEmpty else { return }
            
            var lines: [String] = []
            for bubble in conversationHistory {
                var entry = "[\(bubble.speakerName)] (\(bubble.speakerLanguage)): \(bubble.originalText)"
                if !bubble.translatedText.isEmpty && bubble.translatedText != bubble.originalText {
                    entry += "\n  ↳ [\(bubble.targetLanguage)]: \(bubble.translatedText)"
                }
                lines.append(entry)
            }
            let fullText = lines.joined(separator: "\n\n")
            guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            
            // Duplicate guard: skip if already persisted or currently saving
            if fullText == lastPersistedTranscript || isPersistingSession {
                return
            }
            isPersistingSession = true
            lastPersistedTranscript = fullText
            
            let totalChars = conversationHistory.reduce(0) { $0 + $1.originalText.count + $1.translatedText.count }
            let title = resolvedSessionTitle
            let languages = "\(personALang), \(personBLang)"
            
            Task {
                struct SaveSessionReq: Codable {
                    let id: Int64?
                    let sessionType: String
                    let title: String
                    let language: String
                    let mode: String
                    let durationSeconds: Int
                    let transcript: String
                    let characterCount: Int
                }
                let req = SaveSessionReq(
                    id: currentSessionId,
                    sessionType: "CONVERSATION",
                    title: title,
                    language: languages,
                    mode: "conversation",
                    durationSeconds: liveService.elapsedSeconds,
                    transcript: fullText,
                    characterCount: totalChars
                )
                if let bodyData = try? JSONEncoder().encode(req) {
                    struct SessionResp: Codable { let id: Int64?; let message: String? }
                    let resp: SessionResp? = try? await HTTPClient.shared.request(.saveLiveSession, method: "POST", body: bodyData)
                    await MainActor.run {
                        self.isPersistingSession = false
                        if let returnedId = resp?.id {
                            self.currentSessionId = returnedId
                        }
                        appState.isHistoryDirty = true
                    }
                    await fetchPreviousLiveSessions()
                } else {
                    await MainActor.run {
                        self.isPersistingSession = false
                    }
                }
            }
        } else {
            // Solo Mode
            let fullText = liveService.fullTranscriptText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !fullText.isEmpty else { return }
            
            if fullText == lastPersistedTranscript || isPersistingSession {
                return
            }
            isPersistingSession = true
            lastPersistedTranscript = fullText
            
            let title = "Live Dictation"
            let lang = liveService.languageCode
            let mode = liveService.mode
            let duration = liveService.elapsedSeconds
            let charCount = fullText.count
            
            Task {
                struct SaveSessionReq: Codable {
                    let id: Int64?
                    let sessionType: String
                    let title: String
                    let language: String
                    let mode: String
                    let durationSeconds: Int
                    let transcript: String
                    let characterCount: Int
                }
                let req = SaveSessionReq(
                    id: currentSessionId,
                    sessionType: "SOLO",
                    title: title,
                    language: lang,
                    mode: mode,
                    durationSeconds: duration,
                    transcript: fullText,
                    characterCount: charCount
                )
                if let bodyData = try? JSONEncoder().encode(req) {
                    struct SessionResp: Codable { let id: Int64?; let message: String? }
                    let resp: SessionResp? = try? await HTTPClient.shared.request(.saveLiveSession, method: "POST", body: bodyData)
                    await MainActor.run {
                        self.isPersistingSession = false
                        if let returnedId = resp?.id {
                            self.currentSessionId = returnedId
                        }
                        appState.isHistoryDirty = true
                    }
                    await fetchPreviousLiveSessions()
                } else {
                    await MainActor.run {
                        self.isPersistingSession = false
                    }
                }
            }
        }
    }
    
    // MARK: - Previous Sessions Actions
    private func fetchPreviousLiveSessions() async {
        await MainActor.run {
            self.isLoadingPreviousSessions = true
        }
        do {
            let response: HistoryPageResponse = try await HTTPClient.shared.request(
                .history(page: 0, size: 10, type: "LIVE")
            )
            await MainActor.run {
                self.isLoadingPreviousSessions = false
                self.previousLiveSessions = response.content ?? []
            }
        } catch {
            await MainActor.run {
                self.isLoadingPreviousSessions = false
            }
        }
    }
    
    private func continuePreviousSession(_ item: HistoryItem) {
        let turns = item.parsedLiveChatTurns
        guard !turns.isEmpty else { return }
        
        // Track existing session ID to update in-place rather than creating duplicate entries
        currentSessionId = item.id
        sessionTitle = item.liveChatTitle
        speaker1Name = turns.first?.speakerName ?? "Speaker 1"
        speaker2Name = turns.first(where: { !$0.isSpeakerA })?.speakerName ?? "Speaker 2"
        personALang = turns.first?.speakerLanguage ?? "hi-IN"
        personBLang = turns.first(where: { !$0.isSpeakerA })?.speakerLanguage ?? "en-IN"
        
        conversationHistory = turns.map { turn in
            ConversationBubble(
                speakerSide: turn.isSpeakerA ? .personA : .personB,
                speakerName: turn.speakerName,
                speakerLanguage: turn.speakerLanguage,
                targetLanguage: turn.targetLanguage ?? (turn.isSpeakerA ? personBLang : personALang),
                originalText: turn.originalText,
                translatedText: turn.translatedText ?? ""
            )
        }
        
        // Prevent duplicate saves of the existing transcript
        lastPersistedTranscript = item.fullText
        
        withAnimation {
            isConversationSessionStarted = true
        }
    }
    
    private func formatSeconds(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

#Preview {
    LiveTranscriptionView()
        .environment(AppState.shared)
}

// MARK: - RoundedCornerShape
// Custom Shape used by chat bubbles to apply individual corner radii.
// Speaker A (left): top-left corner is sharp (4pt) to create the "tail" pointing left.
// Speaker B (right): top-right corner is sharp (4pt) to create the "tail" pointing right.
struct RoundedCornerShape: Shape {
    var tl: CGFloat // top-left radius
    var tr: CGFloat // top-right radius
    var bl: CGFloat // bottom-left radius
    var br: CGFloat // bottom-right radius

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.size.width
        let h = rect.size.height

        // Clamp radii to half the dimension to avoid overlap
        let tl = min(tl, min(w, h) / 2)
        let tr = min(tr, min(w, h) / 2)
        let bl = min(bl, min(w, h) / 2)
        let br = min(br, min(w, h) / 2)

        path.move(to: CGPoint(x: tl, y: 0))
        path.addLine(to: CGPoint(x: w - tr, y: 0))
        path.addArc(center: CGPoint(x: w - tr, y: tr),
                    radius: tr, startAngle: Angle(degrees: -90),
                    endAngle: Angle(degrees: 0), clockwise: false)
        path.addLine(to: CGPoint(x: w, y: h - br))
        path.addArc(center: CGPoint(x: w - br, y: h - br),
                    radius: br, startAngle: Angle(degrees: 0),
                    endAngle: Angle(degrees: 90), clockwise: false)
        path.addLine(to: CGPoint(x: bl, y: h))
        path.addArc(center: CGPoint(x: bl, y: h - bl),
                    radius: bl, startAngle: Angle(degrees: 90),
                    endAngle: Angle(degrees: 180), clockwise: false)
        path.addLine(to: CGPoint(x: 0, y: tl))
        path.addArc(center: CGPoint(x: tl, y: tl),
                    radius: tl, startAngle: Angle(degrees: 180),
                    endAngle: Angle(degrees: 270), clockwise: false)
        path.closeSubpath()
        return path
    }
}
