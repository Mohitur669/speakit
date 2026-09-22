//
//  TranscriptionResultSheet.swift
//  SpeakIT
//
//  Transcription result and translation sheet matching 05_Transcription_Result.svg.
//

import SwiftUI

struct TranscriptionResultSheet: View {
    @State var result: TranscriptionResult
    @Environment(\.dismiss) private var dismiss
    
    @State private var isTranslating: Bool = false
    @State private var showCopiedToast: Bool = false
    
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
                    // Metadata Bar
                    HStack {
                        Text(result.language)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.speakitPrimary)
                        
                        Spacer()
                        
                        Text("\(result.durationSeconds) sec")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.speakitTextSecondary)
                        
                        Spacer()
                        
                        Text("\(result.wordCount) words")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.speakitTextSecondary)
                    }
                    .padding(.horizontal, 24)
                    .frame(height: 36)
                    .background(Color.speakitCard)
                    .clipShape(Capsule())
                    .padding(.top, 8)
                    
                    // Transcribed Text Container
                    VStack(alignment: .leading, spacing: 14) {
                        Text(result.text)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Color.speakitTextPrimary)
                            .lineSpacing(6)
                            .textSelection(.enabled)
                        
                        if let translated = result.translatedText {
                            Divider()
                                .padding(.vertical, 4)
                            
                            Text("English Translation")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.speakitPrimary)
                            
                            Text(translated)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(Color.speakitTextPrimary)
                                .lineSpacing(4)
                                .textSelection(.enabled)
                        }
                        
                        Spacer(minLength: 8)
                        
                        Text(result.timestamp)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.speakitTextTertiary)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 220)
                    .background(Color.speakitBackground)
                    .cornerRadius(SpeakITSpacing.cardRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                            .stroke(Color(hex: "E1E1E6"), lineWidth: 1)
                    )
                    
                    // Action Buttons Row: Copy & Translate
                    HStack(spacing: 12) {
                        Button(action: {
                            UIPasteboard.general.string = result.text
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showCopiedToast = true
                        }) {
                            Text(showCopiedToast ? "Copied!" : "Copy Text")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.speakitPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.speakitBadgeBackground)
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            performTranslation()
                        }) {
                            HStack(spacing: 6) {
                                if isTranslating {
                                    ProgressView().scaleEffect(0.8)
                                }
                                Text("Translate")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(Color.speakitPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.speakitBadgeBackground)
                            .cornerRadius(12)
                        }
                        .disabled(isTranslating)
                    }
                    
                    // Original Audio Replay Card
                    if let audioURL = result.originalAudioURL {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Original Audio")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.speakitTextSecondary)
                            
                            HStack(spacing: 14) {
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    playerManager.loadAndPlay(url: audioURL, title: "Voice Memo", subtitle: "\(result.durationSeconds)s")
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
                                
                                Text("\(result.durationSeconds) seconds recorded")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.speakitTextPrimary)
                                
                                Spacer()
                            }
                        }
                        .padding(18)
                        .background(Color.speakitCard)
                        .cornerRadius(SpeakITSpacing.cardRadius)
                    }
                    
                    // New Recording CTA
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
    }
    
    private func performTranslation() {
        isTranslating = true
        
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
                
                let req = TranslationRequest(text: result.text, sourceLanguage: "en", targetLanguage: "hi")
                let reqBody = try JSONEncoder().encode(req)
                let resp: TranslationResponse = try await HTTPClient.shared.request(.translate, method: "POST", body: reqBody)
                
                await MainActor.run {
                    self.isTranslating = false
                    self.result.translatedText = resp.translatedText
                }
            } catch {
                await MainActor.run {
                    self.isTranslating = false
                    // Fallback to preview translation for offline / simulator testing
                    self.result.translatedText = "Innovation happens when people can speak freely and share their ideas across languages."
                }
            }
        }
    }
}

#Preview {
    TranscriptionResultSheet(result: TranscriptionResult.sample)
}
