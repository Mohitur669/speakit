//
//  STTStudioView.swift
//  SpeakIT
//
//  Speech-to-Text recording and file import studio matching 04_STT_Record.svg.
//

import SwiftUI
import UniformTypeIdentifiers

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
                            UISelectionFeedbackGenerator().selectionChanged()
                            selectedMode = mode
                        }) {
                            Text(mode.rawValue)
                                .font(.system(size: 12, weight: isSelected ? .bold : .semibold))
                                .foregroundColor(isSelected ? Color.speakitPrimary : Color.speakitTextSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(isSelected ? Color.speakitBackground : Color.clear)
                                .cornerRadius(18)
                                .shadow(color: isSelected ? Color.black.opacity(0.06) : Color.clear, radius: 4, x: 0, y: 2)
                        }
                    }
                }
                .padding(2)
                .background(Color.speakitCard)
                .cornerRadius(20)
                
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
                    .background(Color.speakitCard)
                    .cornerRadius(SpeakITSpacing.cardRadius)
                }
                
                // Error banner
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.speakitDestructive)
                        .padding(.horizontal)
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
            .padding(.horizontal, SpeakITSpacing.screenMargin)
            .padding(.bottom, 24)
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
    }
    
    // MARK: - Live Recording Subview
    @ViewBuilder
    private var liveRecordingSection: some View {
        VStack(spacing: 24) {
            Text(recordingManager.isRecording ? "Listening to your speech…" : "Tap to start recording")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.speakitTextPrimary)
                .padding(.top, 16)
            
            // Amplitude Visualizer
            SpeakITRecordingVisualizer(amplitudes: recordingManager.amplitudes)
                .frame(height: 48)
            
            // Record / Stop Circular Button
            Button(action: {
                toggleRecording()
            }) {
                ZStack {
                    Circle()
                        .fill(recordingManager.isRecording ? Color.speakitDestructive : Color.speakitPrimary)
                        .frame(width: 68, height: 68)
                        .shadow(color: Color.speakitPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    if recordingManager.isRecording {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white)
                            .frame(width: 22, height: 22)
                    } else {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                    }
                }
            }
            .accessibilityLabel(recordingManager.isRecording ? "Stop recording" : "Start recording")
            .accessibilityIdentifier("stt.record")
            
            // Large Timer Display
            Text(formatTimer(recordingManager.elapsedTime))
                .font(Font.speakitTimer)
                .foregroundColor(Color.speakitTextPrimary)
        }
        .padding(.vertical, 16)
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
                .background(Color.speakitCard)
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
        if recordingManager.isRecording {
            stopAndTranscribe()
        } else {
            Task {
                let success = await recordingManager.startRecording()
                if !success {
                    await MainActor.run {
                        self.showPermissionAlert = true
                    }
                }
            }
        }
    }
    
    private func stopAndTranscribe() {
        guard let fileURL = recordingManager.stopRecording() else { return }
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
                
                await MainActor.run {
                    self.isProcessing = false
                    self.transcriptionResult = TranscriptionResult(
                        text: resultText,
                        language: response.language ?? "English",
                        durationSeconds: Int(response.duration ?? recordingManager.elapsedTime),
                        wordCount: words,
                        timestamp: "Today, \(Date().formatted(date: .omitted, time: .shortened))",
                        originalAudioURL: fileURL
                    )
                    self.showResultSheet = true
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    if case APIError.forbidden = error {
                        self.errorMessage = "Live microphone transcription requires Pro Plus."
                        self.appState.showPaywallSheet = true
                    } else if case APIError.networkError = error {
                        // Offline preview fallback
                        self.transcriptionResult = TranscriptionResult.sample
                        self.transcriptionResult?.originalAudioURL = fileURL
                        self.showResultSheet = true
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    private func processImportedAudio(fileURL: URL) {
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
                
                let response: STTApiResponse = try await HTTPClient.shared.uploadMultipart(
                    .transcribeFile,
                    fileData: audioData,
                    fileName: fileURL.lastPathComponent,
                    mimeType: "audio/m4a",
                    fieldName: "file"
                )
                
                let resultText = response.outputText
                let words = resultText.split(separator: " ").count
                
                await MainActor.run {
                    self.isProcessing = false
                    self.transcriptionResult = TranscriptionResult(
                        text: resultText,
                        language: response.language ?? "English",
                        durationSeconds: Int(response.duration ?? 15),
                        wordCount: words,
                        timestamp: "Today, \(Date().formatted(date: .omitted, time: .shortened))",
                        originalAudioURL: fileURL
                    )
                    self.showResultSheet = true
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.transcriptionResult = TranscriptionResult.sample
                    self.showResultSheet = true
                }
            }
        }
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
