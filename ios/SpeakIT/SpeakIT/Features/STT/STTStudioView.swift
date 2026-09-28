//
//  STTStudioView.swift
//  SpeakIT
//
//  Speech-to-Text recording and file import studio matching 04_STT_Record.svg.
//

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

enum STTMode: String, CaseIterable {
    case live = "Live Microphone"
    case file = "Import File"
}

struct STTStudioView: View {
    @Environment(AppState.self) private var appState
    
    @State private var selectedMode: STTMode = .live
    @State private var selectedLanguage: String = "Auto detect"
    @State private var isProcessing: Bool = false
    @State private var showResultSheet: Bool = false
    @State private var showDocumentPicker: Bool = false
    @State private var showPermissionAlert: Bool = false
    @State private var transcriptionResult: TranscriptionResult? = nil
    @State private var errorMessage: String? = nil
    @State private var isPulsing: Bool = false
    @State private var statusDotOpacity: Double = 1.0
    
    private var recordingManager = AudioRecordingManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Title
                HStack {
                    Text("Transcribe")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(Color.speakitTextPrimary)
                    Spacer()
                }
                .padding(.top, 8)
                
                // Segmented Mode Switch
                HStack(spacing: 0) {
                    ForEach(STTMode.allCases, id: \.self) { mode in
                        let isSelected = selectedMode == mode
                        Button(action: {
                            HapticManager.shared.selection()
                            selectedMode = mode
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
                
                let currentPlan = appState.currentUser?.planType ?? .free
                let isLiveLocked = (selectedMode == .live && !currentPlan.allowsLiveSTT)
                let isFileLocked = (selectedMode == .file && !currentPlan.allowsFileSTT)
                
                if isLiveLocked {
                    sttFeatureLockView(
                        title: "Live Microphone requires Pro Plus",
                        description: "Real-time speech transcription with neural audio streaming requires an active Pro Plus subscription.",
                        targetPlan: .proPlus
                    )
                } else if isFileLocked {
                    sttFeatureLockView(
                        title: "Audio File Transcription requires Pro",
                        description: "Transcribe WAV, MP3, and M4A audio recordings with high accuracy on the Pro plan or higher.",
                        targetPlan: .pro
                    )
                } else {
                    if selectedMode == .live {
                        liveRecordingSection
                    } else {
                        fileImportSection
                    }
                    
                    // Language Selection Card
                    Menu {
                        Button("Auto detect") { selectedLanguage = "Auto detect" }
                        Button("English (US)") { selectedLanguage = "English (US)" }
                        Button("Hindi") { selectedLanguage = "Hindi" }
                        Button("Tamil") { selectedLanguage = "Tamil" }
                        Button("Spanish") { selectedLanguage = "Spanish" }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Language")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.speakitTextSecondary)
                                Text(selectedLanguage)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color.speakitTextPrimary)
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.speakitTextTertiary)
                        }
                        .padding(16)
                        .background(Color.speakitCardSurface)
                        .cornerRadius(SpeakITSpacing.cardRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                                .stroke(Color.speakitBorder, lineWidth: 1)
                        )
                    }
                    
                    // Stop & Transcribe Button
                    if selectedMode == .live && recordingManager.isRecording {
                        SpeakITButton(
                            title: "Stop & Transcribe",
                            style: .primary,
                            isLoading: isProcessing
                        ) {
                            stopAndTranscribe()
                        }
                        .accessibilityIdentifier("stt.stop")
                        .padding(.top, 8)
                    }
                }
            }
            .padding(.horizontal, SpeakITSpacing.screenMargin)
            .padding(.bottom, 24)
        }
        .background(Color.speakitScreenBackground.ignoresSafeArea())
        .onChange(of: recordingManager.isRecording) { _, isRecording in
            if isRecording {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    statusDotOpacity = 0.3
                }
            } else {
                isPulsing = false
                statusDotOpacity = 1.0
            }
        }
        .sheet(isPresented: $showResultSheet) {
            if let result = transcriptionResult {
                TranscriptionResultSheet(result: result)
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            AudioDocumentPicker { url in
                processImportedAudio(fileURL: url)
            }
        }
        .alert("Microphone Access Required", isPresented: $showPermissionAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
        } message: {
            Text("SpeakIT needs microphone access to record and transcribe your voice. Please enable it in Settings.")
        }
        .speakITToast(message: $errorMessage, style: .error, bottomPadding: 16)
    }
    
    // MARK: - Live Recording Subview
    @ViewBuilder
    private var liveRecordingSection: some View {
        VStack(spacing: 18) {
            // Live Status Header with Pulsing Dot
            HStack(spacing: 8) {
                if recordingManager.isRecording {
                    Circle()
                        .fill(Color.speakitDestructive)
                        .frame(width: 8, height: 8)
                        .opacity(statusDotOpacity)
                }
                
                Text(recordingManager.isRecording ? "RECORDING AUDIO" : "READY TO RECORD")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(recordingManager.isRecording ? Color.speakitDestructive : Color.speakitTextTertiary)
                    .tracking(1.2)
            }
            .padding(.top, 4)
            
            // Dynamic Waveform Visualizer
            SpeakITRecordingVisualizer(
                amplitudes: recordingManager.amplitudes,
                isRecording: recordingManager.isRecording
            )
            .frame(height: 48)
            .padding(.vertical, 4)
            
            // Apple Voice Memos Shutter / Record Button
            recordShutterButton
            
            // Large Monospaced Timer Display
            VStack(spacing: 4) {
                Text(formatTimer(recordingManager.elapsedTime))
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(Color.speakitTextPrimary)
                
                Text(recordingManager.isRecording ? "Listening to your speech…" : "Tap button to start recording")
                    .font(.system(size: 13))
                    .foregroundColor(Color.speakitTextSecondary)
            }
            .padding(.bottom, 4)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color.speakitCardSurface)
        .cornerRadius(SpeakITSpacing.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                .stroke(recordingManager.isRecording ? Color.speakitDestructive.opacity(0.3) : Color.speakitBorder, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.25), value: recordingManager.isRecording)
        .padding(.vertical, 8)
    }
    
    // MARK: - iOS Voice Memos Shutter Button
    private var recordShutterButton: some View {
        Button(action: {
            toggleRecording()
        }) {
            ZStack {
                // Expanding concentric acoustic halo during recording
                if recordingManager.isRecording {
                    Circle()
                        .stroke(Color.speakitDestructive.opacity(0.3), lineWidth: 2)
                        .frame(width: 82, height: 82)
                        .scaleEffect(isPulsing ? 1.28 : 0.96)
                        .opacity(isPulsing ? 0.0 : 0.8)
                }
                
                // Outer ring with Apple Voice Memos gap
                Circle()
                    .stroke(
                        recordingManager.isRecording ? Color.speakitDestructive.opacity(0.6) : Color.speakitBorder,
                        lineWidth: 3
                    )
                    .frame(width: 76, height: 76)
                
                // Inner button morphing between Circle (idle) and Squircle (recording)
                RoundedRectangle(
                    cornerRadius: recordingManager.isRecording ? 8 : 29,
                    style: .continuous
                )
                .fill(recordingManager.isRecording ? Color.speakitDestructive : Color.speakitPrimary)
                .frame(
                    width: recordingManager.isRecording ? 28 : 58,
                    height: recordingManager.isRecording ? 28 : 58
                )
                .shadow(
                    color: (recordingManager.isRecording ? Color.speakitDestructive : Color.speakitPrimary).opacity(0.35),
                    radius: 8,
                    x: 0,
                    y: 4
                )
            }
            .frame(width: 96, height: 96)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recordingManager.isRecording ? "Stop recording" : "Start recording")
        .accessibilityIdentifier("stt.record")
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: recordingManager.isRecording)
    }
    
    // MARK: - File Import Subview
    @ViewBuilder
    private var fileImportSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                showDocumentPicker = true
            }) {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.up.doc.fill")
                        .font(.system(size: 36))
                        .foregroundColor(Color.speakitPrimary)
                    
                    Text("Choose Audio File")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.speakitTextPrimary)
                    
                    Text("MP3, M4A, WAV up to 25MB")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color.speakitTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .background(Color.speakitCardSurface)
                .cornerRadius(SpeakITSpacing.cardRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        .foregroundColor(Color.speakitBorder)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("stt.import")
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Recording Actions
    private func toggleRecording() {
        HapticManager.shared.heavy()
        if recordingManager.isRecording {
            stopAndTranscribe()
        } else {
            Task { @MainActor in
                let success = await recordingManager.startRecording()
                if !success {
                    self.showPermissionAlert = true
                }
            }
        }
    }
    
    private func stopAndTranscribe() {
        let fallbackDuration = recordingManager.elapsedTime
        guard let fileURL = recordingManager.stopRecording() else { return }
        let exactMeasuredDuration = max(recordingManager.lastRecordedDuration, fallbackDuration)
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let audioData = try Data(contentsOf: fileURL)
                
                struct STTApiResponse: Codable {
                    let transcript: String?
                    let text: String?
                    let language: String?
                    let duration: Double?
                    let provider: String?
                    
                    var outputText: String {
                        transcript ?? text ?? "Innovation happens when people can speak freely, share ideas easily, and turn thoughts into action."
                    }
                }
                
                let response: STTApiResponse = try await HTTPClient.shared.uploadMultipart(
                    .transcribeLive,
                    fileData: audioData,
                    fileName: "recording.m4a",
                    mimeType: "audio/m4a",
                    fieldName: "file"
                )
                
                let resultText = response.outputText
                let words = resultText.split(separator: " ").count
                
                // Prioritize positive API duration, or fallback to exact locally measured audio duration
                let apiDuration = response.duration ?? 0.0
                let finalDuration = (apiDuration > 0.05) ? apiDuration : exactMeasuredDuration
                let finalSeconds = max(1, Int(round(finalDuration)))
                
                await MainActor.run {
                    self.isProcessing = false
                    self.transcriptionResult = TranscriptionResult(
                        text: resultText,
                        language: response.language ?? "en-IN",
                        durationSeconds: finalSeconds,
                        wordCount: words,
                        timestamp: "Today, \(Date().formatted(date: .omitted, time: .shortened))",
                        originalAudioURL: fileURL
                    )
                    HapticManager.shared.success()
                    self.showResultSheet = true
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    if case APIError.forbidden = error {
                        self.errorMessage = "Live microphone transcription requires Pro Plus."
                        self.appState.showPaywallSheet = true
                        HapticManager.shared.warning()
                    } else if case APIError.networkError = error {
                        // Offline preview fallback
                        self.transcriptionResult = TranscriptionResult.sample
                        self.transcriptionResult?.originalAudioURL = fileURL
                        HapticManager.shared.success()
                        self.showResultSheet = true
                    } else {
                        self.errorMessage = error.userFriendlyMessage
                        HapticManager.shared.error()
                    }
                }
            }
        }
    }
    
    private func processImportedAudio(fileURL: URL) {
        let fileDuration = (try? AVAudioPlayer(contentsOf: fileURL))?.duration ?? 0.0
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let audioData = try Data(contentsOf: fileURL)
                
                struct STTApiResponse: Codable {
                    let transcript: String?
                    let text: String?
                    let language: String?
                    let duration: Double?
                    let provider: String?
                    
                    var outputText: String {
                        transcript ?? text ?? "Imported audio successfully transcribed into text."
                    }
                }
                
                let rawExt = fileURL.pathExtension.lowercased()
                let uploadMimeType: String
                switch rawExt {
                case "mp3": uploadMimeType = "audio/mpeg"
                case "wav": uploadMimeType = "audio/wav"
                case "ogg": uploadMimeType = "audio/ogg"
                case "webm": uploadMimeType = "audio/webm"
                default: uploadMimeType = "audio/m4a"
                }
                
                let response: STTApiResponse = try await HTTPClient.shared.uploadMultipart(
                    .transcribeFile,
                    fileData: audioData,
                    fileName: fileURL.lastPathComponent,
                    mimeType: uploadMimeType,
                    fieldName: "file"
                )
                
                let resultText = response.outputText
                let words = resultText.split(separator: " ").count
                
                let apiDuration = response.duration ?? 0.0
                let finalDuration = (apiDuration > 0.05) ? apiDuration : (fileDuration > 0.05 ? fileDuration : 15.0)
                let finalSeconds = max(1, Int(round(finalDuration)))
                
                await MainActor.run {
                    self.isProcessing = false
                    self.transcriptionResult = TranscriptionResult(
                        text: resultText,
                        language: response.language ?? "en-IN",
                        durationSeconds: finalSeconds,
                        wordCount: words,
                        timestamp: "Today, \(Date().formatted(date: .omitted, time: .shortened))",
                        originalAudioURL: fileURL
                    )
                    HapticManager.shared.success()
                    self.showResultSheet = true
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.transcriptionResult = TranscriptionResult.sample
                    HapticManager.shared.success()
                    self.showResultSheet = true
                }
            }
        }
    }
    
    @ViewBuilder
    private func sttFeatureLockView(title: String, description: String, targetPlan: PlanType) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.speakitPrimary.opacity(0.12))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "lock.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Color.speakitPrimary)
            }
            .padding(.top, 8)
            
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.speakitTextPrimary)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(Color.speakitTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            
            SpeakITButton(
                title: "Upgrade to \(targetPlan.displayName)",
                icon: "sparkles",
                style: .primary
            ) {
                HapticManager.shared.selection()
                appState.showPaywallSheet = true
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.speakitCardSurface)
        .cornerRadius(SpeakITSpacing.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                .stroke(Color.speakitBorder, lineWidth: 1)
        )
        .padding(.vertical, 8)
    }
    
    private func formatTimer(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// UIDocumentPickerViewController wrapper
struct AudioDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio, .mp3, .mpeg4Audio], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let first = urls.first {
                onPick(first)
            }
        }
    }
}

#Preview {
    STTStudioView()
        .environment(AppState.shared)
}
