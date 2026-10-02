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
    case solo = "Solo Dictation"
    case conversation = "Face-to-Face"
    
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

final class LocalSpeechSpeaker {
    static let shared = LocalSpeechSpeaker()
    private let synthesizer = AVSpeechSynthesizer()
    
    func speak(text: String, languageCode: String = "en-US") {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        let bcp47 = languageCode == "auto" ? "en-US" : languageCode
        utterance.voice = AVSpeechSynthesisVoice(language: bcp47) ?? AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }
}

struct LiveTranscriptionView: View {
    @Environment(AppState.self) private var appState
    @State private var liveService = SarvamLiveSTTService()
    
    @State private var studioMode: LiveStudioMode = .solo
    @State private var showClearConfirmation: Bool = false
    @State private var copiedToClipboard: Bool = false
    @State private var bannerMessage: String? = nil
    
    // Conversation Mode States & Editable Speaker Names
    @State private var speaker1Name: String = "Speaker 1"
    @State private var speaker2Name: String = "Speaker 2"
    @State private var editingSpeaker: SpeakerSide? = nil
    @State private var tempSpeakerName: String = ""
    @State private var showRenameAlert: Bool = false
    
    @State private var personALang: String = "hi-IN"
    @State private var personBLang: String = "en-IN"
    @State private var activeSpeaker: SpeakerSide? = nil
    @State private var conversationHistory: [ConversationBubble] = []
    
    private let availableLanguages: [(code: String, name: String)] = [
        ("auto", "Auto (Detect)"),
        ("hi-IN", "Hindi 🇮🇳"),
        ("en-IN", "English 🇬🇧"),
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
        .speakITToast(message: $liveService.errorMessage, style: .error, bottomPadding: 90)
        .speakITToast(message: $bannerMessage, style: .info, bottomPadding: 90)
        .onDisappear {
            if liveService.isRecording {
                liveService.stopSession()
            }
        }
    }
    
    private var exportMenuButton: some View {
        Menu {
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
            // Mode Selector Pill: Transcribe vs Translate
            HStack(spacing: 4) {
                Button(action: {
                    guard liveService.mode != "transcribe" else { return }
                    HapticManager.shared.selection()
                    liveService.mode = "transcribe"
                }) {
                    Text("Transcribe")
                        .font(.system(size: 12, weight: liveService.mode == "transcribe" ? .bold : .medium))
                        .foregroundColor(liveService.mode == "transcribe" ? .white : Color.speakitTextSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(liveService.mode == "transcribe" ? Color.speakitPrimary : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
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
                    HStack(spacing: 4) {
                        Text("Translate")
                        if !currentUserPlan.allowsLiveTranslation {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                        }
                    }
                    .font(.system(size: 12, weight: liveService.mode == "translate" ? .bold : .medium))
                    .foregroundColor(liveService.mode == "translate" ? .white : Color.speakitTextSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(liveService.mode == "translate" ? Color.speakitPrimary : Color.clear)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(3)
            .background(Color.speakitCardSurface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.speakitBorder, lineWidth: 1))
            
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
                    let partial = liveService.partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !partial.isEmpty {
                        appState.recordCharacterUsage(partial.count)
                    }
                    liveService.stopSession()
                } else {
                    if !currentUserPlan.allowsLiveTranscription {
                        HapticManager.shared.warning()
                        appState.showPaywallSheet = true
                        bannerMessage = "Live Transcription requires a Pro plan or higher."
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
        .background(
            Color.speakitCardSurface
                .shadow(color: Color.black.opacity(0.05), radius: 12, y: -4)
        )
    }
    
    // MARK: - 6. Face-to-Face Two-Person Conversation View
    private var conversationView: some View {
        VStack(spacing: 0) {
            // Speaker Language Selectors Card
            HStack(spacing: 12) {
                // Speaker 1 Selector & Editable Name
                speakerSelectorCard(
                    side: .personA,
                    name: speaker1Name,
                    languageCode: personALang,
                    color: Color.speakitPrimary,
                    bgColor: Color.speakitBadgeBackground
                )
                
                // Exchange indicator icon
                ZStack {
                    Circle()
                        .fill(Color.speakitScreenBackground)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(Color.speakitBorder, lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
                    
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.speakitTextSecondary)
                }
                
                // Speaker 2 Selector & Editable Name
                speakerSelectorCard(
                    side: .personB,
                    name: speaker2Name,
                    languageCode: personBLang,
                    color: Color(hex: "0D9488"),
                    bgColor: Color(hex: "0D9488").opacity(0.12)
                )
            }
            .padding(12)
            .background(Color.speakitCardSurface)
            .cornerRadius(SpeakITSpacing.cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                    .stroke(Color.speakitBorder, lineWidth: 1)
            )
            .padding(.horizontal, SpeakITSpacing.screenMargin)
            .padding(.vertical, 8)
            
            // Conversation Dialogue Scroll
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 14) {
                        if conversationHistory.isEmpty && !liveService.isRecording && liveService.partialTranscript.isEmpty && liveService.committedSegments.isEmpty {
                            VStack(spacing: 12) {
                                Spacer(minLength: 50)
                                Image(systemName: "person.2.wave.2.fill")
                                    .font(.system(size: 42))
                                    .foregroundColor(Color.speakitPrimary.opacity(0.75))
                                Text("Face-to-Face Interpreter")
                                    .font(.system(size: 19, weight: .bold))
                                    .foregroundColor(Color.speakitTextPrimary)
                                Text("Place device between two speakers. Tap either microphone button below to speak turn-by-turn.")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color.speakitTextSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                                Spacer(minLength: 50)
                            }
                        } else {
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
                                                .foregroundColor(isSpeakerA ? Color.speakitPrimary : Color(hex: "0D9488"))
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
                                            : Color(hex: "0D9488").opacity(0.12)
                                    )
                                    .cornerRadius(SpeakITSpacing.cardRadius)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                                            .stroke(isSpeakerA ? Color.speakitPrimary.opacity(0.3) : Color(hex: "0D9488").opacity(0.3), lineWidth: 1)
                                    )
                                    if isSpeakerA { Spacer(minLength: 24) }
                                }
                                .id("conv-active-turn")
                            }
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
    
    private func speakerSelectorCard(side: SpeakerSide, name: String, languageCode: String, color: Color, bgColor: Color) -> some View {
        VStack(alignment: side == .personA ? .leading : .trailing, spacing: 6) {
            Button(action: {
                tempSpeakerName = name
                editingSpeaker = side
                showRenameAlert = true
            }) {
                HStack(spacing: 4) {
                    if side == .personB {
                        Image(systemName: "pencil")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Color.speakitTextTertiary)
                    }
                    Text(name)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(color)
                        .lineLimit(1)
                    if side == .personA {
                        Image(systemName: "pencil")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Color.speakitTextTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            
            Menu {
                ForEach(availableLanguages, id: \.code) { item in
                    Button(action: {
                        HapticManager.shared.selection()
                        if side == .personA {
                            personALang = item.code
                        } else {
                            personBLang = item.code
                        }
                    }) {
                        HStack {
                            Text(item.name)
                            if (side == .personA ? personALang : personBLang) == item.code {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(availableLanguages.first(where: { $0.code == languageCode })?.name ?? "Language")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.speakitTextPrimary)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color.speakitTextSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(bgColor)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(liveService.isRecording)
        }
        .frame(maxWidth: .infinity, alignment: side == .personA ? .leading : .trailing)
    }
    
    private func conversationTurnCard(_ bubble: ConversationBubble) -> some View {
        let isSpeakerA = bubble.speakerSide == .personA
        let targetLangName = availableLanguages.first(where: { $0.code == bubble.targetLanguage })?.name ?? bubble.targetLanguage
        return HStack {
            if !isSpeakerA { Spacer(minLength: 24) }
            VStack(alignment: isSpeakerA ? .leading : .trailing, spacing: 6) {
                HStack(spacing: 6) {
                    Text(bubble.speakerName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isSpeakerA ? Color.speakitPrimary : Color(hex: "0D9488"))
                    
                    Text("(\(bubble.speakerLanguage))")
                        .font(.system(size: 10))
                        .foregroundColor(Color.speakitTextTertiary)
                    
                    Spacer()
                    
                    if !bubble.translatedText.isEmpty {
                        Button(action: {
                            HapticManager.shared.light()
                            LocalSpeechSpeaker.shared.speak(text: bubble.translatedText, languageCode: bubble.targetLanguage)
                        }) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(isSpeakerA ? Color.speakitPrimary : Color(hex: "0D9488"))
                                .frame(width: 28, height: 28)
                                .background(isSpeakerA ? Color.speakitPrimary.opacity(0.12) : Color(hex: "0D9488").opacity(0.15))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Original spoken speech
                Text(bubble.originalText)
                    .font(.system(size: 14))
                    .foregroundColor(Color.speakitTextSecondary)
                
                // Translated speech in the other speaker's language
                if bubble.isTranslating {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text("Translating to \(targetLangName)...")
                            .font(.system(size: 12))
                            .foregroundColor(Color.speakitTextTertiary)
                            .italic()
                    }
                    .padding(.top, 2)
                } else if !bubble.translatedText.isEmpty && bubble.translatedText != bubble.originalText {
                    VStack(alignment: isSpeakerA ? .leading : .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .bold))
                            Text(targetLangName)
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(isSpeakerA ? Color.speakitPrimary : Color(hex: "0D9488"))
                        .opacity(0.85)
                        
                        Text(bubble.translatedText)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.speakitTextPrimary)
                            .textSelection(.enabled)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(14)
            .background(isSpeakerA ? Color.speakitBadgeBackground.opacity(0.5) : Color(hex: "0D9488").opacity(0.1))
            .cornerRadius(SpeakITSpacing.cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                    .stroke(isSpeakerA ? Color.speakitPrimary.opacity(0.25) : Color(hex: "0D9488").opacity(0.25), lineWidth: 1)
            )
            .id(bubble.id)
            if isSpeakerA { Spacer(minLength: 24) }
        }
    }
    
    private var dualConversationDock: some View {
        HStack(spacing: 14) {
            // Speaker 1 Mic Button
            Button(action: {
                handleSpeakerTurn(.personA, lang: personALang)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: (liveService.isRecording && activeSpeaker == .personA) ? "stop.fill" : "mic.fill")
                        .font(.system(size: 16, weight: .semibold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activeSpeaker == .personA && liveService.isRecording ? "Listening..." : speaker1Name)
                            .font(.system(size: 12, weight: .bold))
                            .lineLimit(1)
                        Text(availableLanguages.first(where: { $0.code == personALang })?.name ?? "Hindi")
                            .font(.system(size: 10))
                            .opacity(0.85)
                            .lineLimit(1)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    (liveService.isRecording && activeSpeaker == .personA)
                        ? Color.red
                        : Color.speakitPrimary
                )
                .clipShape(Capsule())
                .shadow(
                    color: (liveService.isRecording && activeSpeaker == .personA)
                        ? Color.red.opacity(0.35)
                        : Color.speakitPrimary.opacity(0.3),
                    radius: 8,
                    y: 3
                )
            }
            .buttonStyle(.plain)
            
            // Speaker 2 Mic Button
            Button(action: {
                handleSpeakerTurn(.personB, lang: personBLang)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: (liveService.isRecording && activeSpeaker == .personB) ? "stop.fill" : "mic.fill")
                        .font(.system(size: 16, weight: .semibold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activeSpeaker == .personB && liveService.isRecording ? "Listening..." : speaker2Name)
                            .font(.system(size: 12, weight: .bold))
                            .lineLimit(1)
                        Text(availableLanguages.first(where: { $0.code == personBLang })?.name ?? "English")
                            .font(.system(size: 10))
                            .opacity(0.85)
                            .lineLimit(1)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    (liveService.isRecording && activeSpeaker == .personB)
                        ? Color.red
                        : Color(hex: "0D9488")
                )
                .clipShape(Capsule())
                .shadow(
                    color: (liveService.isRecording && activeSpeaker == .personB)
                        ? Color.red.opacity(0.35)
                        : Color(hex: "0D9488").opacity(0.3),
                    radius: 8,
                    y: 3
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, SpeakITSpacing.screenMargin)
        .padding(.vertical, 14)
        .background(
            Color.speakitCardSurface
                .shadow(color: Color.black.opacity(0.06), radius: 10, y: -4)
        )
    }
    
    private func handleSpeakerTurn(_ speaker: SpeakerSide, lang: String) {
        if liveService.isRecording {
            let lastText = liveService.fullTranscriptText.trimmingCharacters(in: .whitespacesAndNewlines)
            let previousSpeaker = activeSpeaker
            liveService.stopSession()
            if let active = previousSpeaker, !lastText.isEmpty {
                // Deduct remaining character credit for spoken utterance
                appState.recordCharacterUsage(lastText.count)
                
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
                conversationHistory.append(bubble)
                
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
                    if let idx = conversationHistory.firstIndex(where: { $0.id == bubbleId }) {
                        conversationHistory[idx].translatedText = resp.translatedText
                        conversationHistory[idx].isTranslating = false
                        
                        // Deduct remaining character credit for translated text
                        appState.recordCharacterUsage(resp.translatedText.count)
                        
                        // Automatically speak translated text in the listener's language!
                        LocalSpeechSpeaker.shared.speak(text: resp.translatedText, languageCode: targetLang)
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
