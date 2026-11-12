//
//  TTSStudioView.swift
//  SpeakIT
//
//  Primary generation studio matching 02_TTS_Studio.svg with Text and Document Audiobook modes.
//

import SwiftUI
import UniformTypeIdentifiers

enum TTSStudioMode: String, CaseIterable {
    case text = "Text to Speech"
    case document = "Document to Speech"
}

struct TTSStudioView: View {
    @Environment(AppState.self) private var appState
    
    @State private var selectedMode: TTSStudioMode = .text
    @State private var inputText: String = "Good ideas can change the world when spoken with clarity."
    @State private var selectedVoice: Voice = Voice.samples[0] // Defaults to "Aditi"
    @State private var showVoiceCatalog: Bool = false
    @State private var isSynthesizing: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var synthesizedAudioURL: URL? = nil
    @State private var errorMessage: String? = nil
    
    /// Selected emotion style for ElevenLabs v4 direction tags.
    @State private var selectedVoiceStyle: String? = nil
    @AppStorage("autoPlayPreview") private var autoPlayPreview: Bool = true
    
    // Document to Speech state
    @State private var showDocumentPicker: Bool = false
    @State private var isAnalyzingDocument: Bool = false
    @State private var documentAnalysis: DocumentAnalysisResponse? = nil
    @State private var activeJob: LongFormJobStatus? = nil
    @State private var isSynthesizingJob: Bool = false
    @State private var pollingTask: Task<Void, Never>? = nil
    @AppStorage("activeTtsJobId") private var persistedJobId: String = ""
    
    private var playerManager = AudioPlayerManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header Row
                HStack(alignment: .center) {
                    Text(selectedMode == .text ? "Translate" : "Audiobook")
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
                
                // Segmented Mode Switch matching STTStudioView
                HStack(spacing: 0) {
                    ForEach(TTSStudioMode.allCases, id: \.self) { mode in
                        let isSelected = selectedMode == mode
                        Button(action: {
                            HapticManager.shared.selection()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedMode = mode
                            }
                        }) {
                            Text(mode.rawValue)
                                .font(.system(size: 12, weight: isSelected ? .bold : .semibold))
                                .foregroundColor(isSelected ? Color.speakitPrimary : Color.speakitTextSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(isSelected ? Color.speakitCardSurface : Color.clear)
                                .cornerRadius(18)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(isSelected ? Color.speakitBorder : Color.clear, lineWidth: 1)
                                )
                                .shadow(color: isSelected ? Color.black.opacity(0.06) : Color.clear, radius: 4, x: 0, y: 2)
                        }
                    }
                }
                .padding(2)
                .background(Color.speakitCard)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.speakitBorder, lineWidth: 1)
                )
                
                // Voice Selector Card (Shared across both modes)
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
                
                // ElevenLabs v4 Emotion Style Chips — only visible when ElevenLabs voice is selected
                if selectedVoice.engine.lowercased() == "elevenlabs" {
                    emotionChipRow
                }
                
                if selectedMode == .text {
                    textToSpeechContent
                } else {
                    documentToSpeechContent
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
        .fileImporter(
            isPresented: $showDocumentPicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleDocumentSelection(result)
        }
        .task {
            await appState.loadCurrentUser()
            await appState.loadPlanPricing()
            resumePersistedJobIfAny()
        }
        .speakITToast(message: $errorMessage, style: .error, bottomPadding: 16)
    }
    
    // MARK: - Text to Speech Content
    private var textToSpeechContent: some View {
        VStack(alignment: .leading, spacing: 18) {
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
            
            if isVoiceLocked {
                voiceLockCard
            }
            
            if isCharLimitExceeded {
                charLimitExceededCard(maxChars: maxChars, currentPlan: currentPlan)
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
            
            // Inline Audio Player Card
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
    }
    
    // MARK: - Document to Speech Content
    private var documentToSpeechContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Document Selection & Analysis Area
            if isAnalyzingDocument {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.speakitPrimary))
                        .scaleEffect(1.2)
                    Text("Analyzing PDF & extracting text…")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.speakitTextPrimary)
                    Text("Validating pages, word count, and structure")
                        .font(.system(size: 12))
                        .foregroundColor(Color.speakitTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .background(Color.speakitCardSurface)
                .cornerRadius(SpeakITSpacing.cardRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                        .stroke(Color.speakitBorder, lineWidth: 1)
                )
            } else if let doc = documentAnalysis {
                // Analyzed Document Summary Card
                VStack(spacing: 16) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.12))
                                .frame(width: 44, height: 44)
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.red)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(doc.fileName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color.speakitTextPrimary)
                                .lineLimit(1)
                            
                            let mb = Double(doc.fileSizeBytes) / 1024.0 / 1024.0
                            Text(String(format: "%.1f MB • Ready for synthesis", mb))
                                .font(.system(size: 12))
                                .foregroundColor(Color.speakitTextSecondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            clearDocument()
                        }) {
                            Text("Change")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.speakitPrimary)
                        }
                    }
                    
                    // Stats Triplet
                    HStack(spacing: 8) {
                        statPill(title: "Pages", value: "\(doc.pageCount)")
                        statPill(title: "Words", value: "\(doc.wordCount.formatted())")
                        statPill(title: "Est. Audio", value: doc.estimatedDurationFormatted)
                    }
                }
                .padding(16)
                .background(Color.speakitCardSurface)
                .cornerRadius(SpeakITSpacing.cardRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                        .stroke(Color.speakitBorder, lineWidth: 1)
                )
            } else {
                // PDF Upload Dropzone Card
                Button(action: {
                    HapticManager.shared.light()
                    showDocumentPicker = true
                }) {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.speakitPrimary.opacity(0.1))
                                .frame(width: 56, height: 56)
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundColor(Color.speakitPrimary)
                        }
                        
                        VStack(spacing: 4) {
                            Text("Select PDF Document")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color.speakitTextPrimary)
                            Text("Synthesize full audiobooks from long PDFs without timeouts")
                                .font(.system(size: 12))
                                .foregroundColor(Color.speakitTextSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                        
                        HStack(spacing: 6) {
                            Text("PDF Only")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.speakitBadgeBackground)
                                .foregroundColor(Color.speakitPrimary)
                                .cornerRadius(6)
                            
                            Text("10,000+ Words")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.speakitBadgeBackground)
                                .foregroundColor(Color.speakitPrimary)
                                .cornerRadius(6)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(Color.speakitCardSurface)
                    .cornerRadius(SpeakITSpacing.cardRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                            .stroke(Color.speakitPrimary.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Background Synthesis Progress Card
            if let job = activeJob, job.isProcessing {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.speakitPrimary)
                                .frame(width: 8, height: 8)
                            Text("Synthesizing Audiobook…")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color.speakitPrimary)
                        }
                        
                        Spacer()
                        
                        Text("\(job.progressPercent)%")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.speakitPrimary)
                    }
                    
                    ProgressView(value: Double(job.progressPercent), total: 100.0)
                        .tint(Color.speakitPrimary)
                    
                    HStack {
                        Text("Chunk \(job.completedChunks) of \(job.totalChunks)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.speakitTextSecondary)
                        Spacer()
                        Text("Runs in background safely")
                            .font(.system(size: 11))
                            .foregroundColor(Color.speakitTextTertiary)
                    }
                }
                .padding(16)
                .background(Color.speakitPrimary.opacity(0.06))
                .cornerRadius(SpeakITSpacing.cardRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                        .stroke(Color.speakitPrimary.opacity(0.2), lineWidth: 1)
                )
            }
            
            // Completed Audiobook Player & Export Action
            if let job = activeJob, job.isComplete, let audioUrlString = job.audioUrl, let url = URL(string: audioUrlString) {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color.speakitSuccess)
                        Text("Audiobook Ready")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color.speakitTextPrimary)
                        Spacer()
                    }
                    
                    SpeakITAudioPlayer(
                        playerManager: playerManager,
                        onShare: {
                            showShareSheet = true
                        }
                    )
                    
                    Button(action: {
                        clearDocument()
                    }) {
                        Text("Synthesize Another Document")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.speakitTextSecondary)
                    }
                    .padding(.top, 4)
                }
                .padding(16)
                .background(Color.speakitCardSurface)
                .cornerRadius(SpeakITSpacing.cardRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                        .stroke(Color.speakitBorder, lineWidth: 1)
                )
            }
            
            // Primary Synthesis CTA
            if documentAnalysis != nil, activeJob == nil || activeJob?.isFailed == true {
                SpeakITButton(
                    title: "Synthesize Audiobook",
                    style: .primary,
                    isLoading: isSynthesizingJob,
                    isEnabled: !isSynthesizingJob
                ) {
                    startAudiobookSynthesis()
                }
                .padding(.top, 4)
            }
        }
    }
    
    private func statPill(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.speakitTextTertiary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color.speakitTextPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.speakitCard)
        .cornerRadius(8)
    }
    
    // MARK: - Lock & Warning Cards
    private var voiceLockCard: some View {
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
    
    private func charLimitExceededCard(maxChars: Int, currentPlan: PlanType) -> some View {
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
    
    // MARK: - Document Actions & Networking
    private func handleDocumentSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let selectedURL = urls.first else { return }
            guard selectedURL.startAccessingSecurityScopedResource() else {
                errorMessage = "Unable to access the selected PDF document."
                return
            }
            defer { selectedURL.stopAccessingSecurityScopedResource() }
            
            do {
                let fileData = try Data(contentsOf: selectedURL)
                let fileName = selectedURL.lastPathComponent
                
                guard fileData.count > 0 else {
                    errorMessage = "Selected PDF file is empty."
                    return
                }
                
                uploadAndAnalyze(fileData: fileData, fileName: fileName)
            } catch {
                errorMessage = "Failed to read PDF: \(error.localizedDescription)"
            }
        case .failure(let error):
            errorMessage = "File selection cancelled: \(error.localizedDescription)"
        }
    }
    
    private func uploadAndAnalyze(fileData: Data, fileName: String) {
        isAnalyzingDocument = true
        errorMessage = nil
        documentAnalysis = nil
        activeJob = nil
        
        Task {
            do {
                let response: DocumentAnalysisResponse = try await HTTPClient.shared.uploadMultipart(
                    .analyzePdfDocument,
                    fileData: fileData,
                    fileName: fileName,
                    mimeType: "application/pdf"
                )
                
                await MainActor.run {
                    self.documentAnalysis = response
                    self.isAnalyzingDocument = false
                    HapticManager.shared.success()
                }
            } catch {
                await MainActor.run {
                    self.isAnalyzingDocument = false
                    self.errorMessage = error.userFriendlyMessage
                    HapticManager.shared.error()
                }
            }
        }
    }
    
    private func startAudiobookSynthesis() {
        guard let doc = documentAnalysis else { return }
        isSynthesizingJob = true
        errorMessage = nil
        
        let isElevenLabs = selectedVoice.engine.lowercased() == "elevenlabs"
        let isSarvam = selectedVoice.engine.lowercased() == "sarvam"
        
        let req = SubmitTtsJobRequest(
            documentToken: doc.documentToken,
            text: nil,
            voiceId: selectedVoice.id,
            outputFormat: "mp3",
            title: doc.fileName.replacingOccurrences(of: ".pdf", with: "", options: .caseInsensitive),
            sourceFileName: doc.fileName,
            isElevenLabs: isElevenLabs,
            isSarvam: isSarvam,
            languageCode: selectedVoice.languageCode,
            voiceStyle: isElevenLabs ? selectedVoiceStyle : nil
        )
        
        Task {
            do {
                let body = try JSONEncoder().encode(req)
                let job: LongFormJobStatus = try await HTTPClient.shared.request(.submitTtsJob, method: "POST", body: body)
                
                await MainActor.run {
                    self.activeJob = job
                    self.persistedJobId = job.jobId
                    self.isSynthesizingJob = true
                    HapticManager.shared.light()
                    startPolling(jobId: job.jobId)
                }
            } catch {
                await MainActor.run {
                    self.isSynthesizingJob = false
                    self.errorMessage = error.userFriendlyMessage
                    HapticManager.shared.error()
                }
            }
        }
    }
    
    private func startPolling(jobId: String) {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if Task.isCancelled { break }
                
                do {
                    let updatedJob: LongFormJobStatus = try await HTTPClient.shared.request(.getTtsJobStatus(jobId: jobId))
                    await MainActor.run {
                        self.activeJob = updatedJob
                        if updatedJob.isComplete {
                            self.isSynthesizingJob = false
                            
                            // Update character usage immediately in the top bar and sync with backend
                            let chars = updatedJob.totalCharacters ?? self.documentAnalysis?.characterCount ?? 0
                            if chars > 0 {
                                self.appState.recordCharacterUsage(chars)
                            }
                            
                            if let audioUrl = updatedJob.audioUrl, let url = URL(string: audioUrl) {
                                self.prepareAndPlayAudio(
                                    url: url,
                                    title: updatedJob.title ?? updatedJob.sourceFileName ?? "Audiobook",
                                    autoPlay: self.autoPlayPreview
                                )
                            }
                            HapticManager.shared.success()
                        } else if updatedJob.isFailed {
                            self.isSynthesizingJob = false
                            self.errorMessage = updatedJob.errorMessage ?? "Audiobook synthesis failed."
                            HapticManager.shared.error()
                        }
                    }
                    if updatedJob.isComplete || updatedJob.isFailed {
                        break
                    }
                } catch {
                    // Transient network hiccup, retry next interval
                }
            }
        }
    }
    
    private func resumePersistedJobIfAny() {
        guard !persistedJobId.isEmpty else { return }
        Task {
            do {
                let job: LongFormJobStatus = try await HTTPClient.shared.request(.getTtsJobStatus(jobId: persistedJobId))
                await MainActor.run {
                    self.activeJob = job
                    if job.isProcessing {
                        self.isSynthesizingJob = true
                        startPolling(jobId: job.jobId)
                    } else if job.isComplete, let audioUrl = job.audioUrl, let url = URL(string: audioUrl) {
                        self.prepareAndPlayAudio(
                            url: url,
                            title: job.title ?? job.sourceFileName ?? "Audiobook",
                            autoPlay: false
                        )
                    }
                }
            } catch {
                persistedJobId = ""
            }
        }
    }
    
    private func prepareAndPlayAudio(url: URL, title: String, autoPlay: Bool) {
        self.playerManager.load(
            url: url,
            title: title,
            subtitle: "\(self.selectedVoice.name) (\(self.selectedVoice.engineDisplayName))",
            autoPlay: autoPlay
        )
        
        // Cache to local temporary file for instant scrubber seeking and native file export
        if url.scheme == "http" || url.scheme == "https" {
            Task.detached(priority: .userInitiated) {
                do {
                    var request = URLRequest(url: url)
                    request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)", forHTTPHeaderField: "User-Agent")
                    let (data, response) = try await URLSession.shared.data(for: request)
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                        let localURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent("audiobook_\(abs(url.absoluteString.hashValue)).mp3")
                        try data.write(to: localURL, options: .atomic)
                        await MainActor.run {
                            self.synthesizedAudioURL = localURL
                        }
                    }
                } catch {
                    // Silent fallback, remote URL is already streaming
                }
            }
        }
    }
    
    private func clearDocument() {
        pollingTask?.cancel()
        pollingTask = nil
        documentAnalysis = nil
        activeJob = nil
        isSynthesizingJob = false
        persistedJobId = ""
    }
    
    // MARK: - Emotion Style Chip Row
    private var emotionChipRow: some View {
        let emotions: [(label: String, icon: String, value: String?)] = [
            ("Neutral", "waveform", nil),
            ("Excited", "bolt.fill", "excited"),
            ("Calm", "leaf.fill", "calm"),
            ("Sad", "cloud.rain.fill", "sad"),
            ("Angry", "flame.fill", "angry"),
            ("Cheerful", "sun.max.fill", "cheerful")
        ]
        
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(emotions, id: \.label) { emotion in
                    let isSelected = selectedVoiceStyle == emotion.value
                    Button(action: {
                        HapticManager.shared.selection()
                        selectedVoiceStyle = emotion.value
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: emotion.icon)
                                .font(.system(size: 11, weight: .bold))
                            Text(emotion.label)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(isSelected ? .white : Color.speakitTextSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(isSelected ? Color.speakitPrimary : Color.speakitCardSurface)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(isSelected ? Color.clear : Color.speakitBorder, lineWidth: 1)
                        )
                        .animation(.easeInOut(duration: 0.15), value: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
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
                    /// ElevenLabs v4 emotion direction tag (excited, sad, calm, angry, cheerful).
                    /// nil = Neutral (no tag injected). Only applied for ElevenLabs voices.
                    let voiceStyle: String?
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
                    languageCode: selectedVoice.languageCode,
                    // Pass voiceStyle only for ElevenLabs voices (backend ignores it for Polly/Sarvam)
                    voiceStyle: isElevenLabs ? selectedVoiceStyle : nil
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

#Preview {
    TTSStudioView()
        .environment(AppState.shared)
}
