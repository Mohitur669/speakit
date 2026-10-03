//
//  LiveChatDetailView.swift
//  SpeakIT
//
//  Full-session dialogue viewer for Live Conversation history matching 10_Live_Chat_Detail.jpg.
//

import SwiftUI

struct LiveChatDetailView: View {
    let item: HistoryItem
    @Environment(\.dismiss) private var dismiss
    @State private var copiedToClipboard: Bool = false
    @State private var playingTurnId: UUID? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Activity")
                            .font(.system(size: 16, weight: .regular))
                    }
                    .foregroundColor(Color.speakitPrimary)
                }
                
                Spacer()
                
                Text(item.liveChatTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color.speakitTextPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                HStack(spacing: 12) {
                    ShareLink(item: exportContent, subject: Text(item.liveChatTitle)) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.speakitPrimary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Color.speakitScreenBackground)
            
            // Metadata Strip Pill
            HStack(spacing: 8) {
                let turns = item.liveChatTurnCount
                Text("\(turns) \(turns == 1 ? "Turn" : "Turns")")
                    .font(.system(size: 11, weight: .bold))
                Text("•")
                    .font(.system(size: 10))
                Text("\(item.characterCount.formatted()) characters")
                    .font(.system(size: 11, weight: .medium))
                Text("•")
                    .font(.system(size: 10))
                Text(item.timeAgoFormatted)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(Color.speakitTextSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.speakitCardSurface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.speakitBorder, lineWidth: 1))
            .padding(.vertical, 8)
            
            // Conversation Dialogue Scroll
            ScrollView {
                VStack(spacing: 14) {
                    let turns = item.parsedLiveChatTurns
                    if turns.isEmpty {
                        // Fallback if plain raw text without structured delimiters
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Full Transcript")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.speakitTextSecondary)
                            Text(item.displayText)
                                .font(.system(size: 15))
                                .foregroundColor(Color.speakitTextPrimary)
                                .lineSpacing(4)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.speakitCardSurface)
                        .cornerRadius(SpeakITSpacing.cardRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: SpeakITSpacing.cardRadius)
                                .stroke(Color.speakitBorder, lineWidth: 1)
                        )
                        .padding(.top, 8)
                    } else {
                        ForEach(turns) { turn in
                            turnBubble(turn)
                        }
                    }
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
                .padding(.vertical, 12)
            }
            
            // Bottom Action Bar
            HStack(spacing: 12) {
                Button(action: {
                    UIPasteboard.general.string = exportContent
                    HapticManager.shared.success()
                    withAnimation {
                        copiedToClipboard = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        copiedToClipboard = false
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 14, weight: .semibold))
                        Text(copiedToClipboard ? "Copied!" : "Copy All")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.speakitCardSurface)
                    .foregroundColor(Color.speakitTextPrimary)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.speakitBorder, lineWidth: 1))
                }
                
                ShareLink(item: exportContent, subject: Text(item.liveChatTitle)) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Export Transcript")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.speakitPrimary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, SpeakITSpacing.screenMargin)
            .padding(.vertical, 12)
            .background(Color.speakitCardSurface)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.speakitBorder),
                alignment: .top
            )
        }
        .background(Color.speakitScreenBackground.ignoresSafeArea())
    }
    
    private func turnBubble(_ turn: LiveChatTurn) -> some View {
        let isSpeakerA = turn.isSpeakerA
        let accentColor = isSpeakerA ? Color.speakitPrimary : Color.speakitSecondary
        let bubbleBg = isSpeakerA
            ? Color.speakitBadgeBackground
            : Color.speakitCard
        
        let tl: CGFloat = isSpeakerA ? 4 : 18
        let tr: CGFloat = isSpeakerA ? 18 : 4
        let bl: CGFloat = 18
        let br: CGFloat = 18
        
        return HStack(alignment: .bottom, spacing: 8) {
            if isSpeakerA {
                avatarCircle(initial: String(turn.speakerName.prefix(1)), color: accentColor, isSpeakerA: true)
            } else {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: isSpeakerA ? .leading : .trailing, spacing: 6) {
                // Speaker name + language tag row
                HStack(spacing: 6) {
                    if !isSpeakerA { Spacer() }
                    Text(turn.speakerName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(accentColor)
                    Text("(\(turn.speakerLanguage))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.speakitTextTertiary)
                }
                
                // Original spoken text
                HStack(alignment: .top, spacing: 8) {
                    Text(turn.originalText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.speakitTextPrimary)
                        .lineSpacing(3)
                        .textSelection(.enabled)
                    
                    Button(action: {
                        HapticManager.shared.light()
                        LocalSpeechSpeaker.shared.speak(text: turn.originalText, languageCode: turn.speakerLanguage)
                    }) {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 13))
                            .foregroundColor(accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
                
                // Translated text (if present)
                if let translated = turn.translatedText, !translated.isEmpty, translated != turn.originalText {
                    VStack(alignment: isSpeakerA ? .leading : .trailing, spacing: 2) {
                        Divider()
                            .background(isSpeakerA ? Color.speakitPrimary.opacity(0.15) : Color.speakitBorder)
                            .padding(.vertical, 2)
                        
                        HStack(alignment: .top, spacing: 6) {
                            Text(translated)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Color.speakitTextSecondary)
                                .lineSpacing(3)
                                .textSelection(.enabled)
                            
                            Button(action: {
                                HapticManager.shared.light()
                                let targetCode = turn.targetLanguage ?? "en-US"
                                LocalSpeechSpeaker.shared.speak(text: translated, languageCode: targetCode)
                            }) {
                                Image(systemName: "speaker.wave.1")
                                    .font(.system(size: 12))
                                    .foregroundColor(accentColor.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleBg)
            .clipShape(RoundedCornerShape(tl: tl, tr: tr, bl: bl, br: br))
            .overlay(
                RoundedCornerShape(tl: tl, tr: tr, bl: bl, br: br)
                    .stroke(isSpeakerA ? Color.speakitPrimary.opacity(0.25) : Color.speakitBorder, lineWidth: 1)
            )
            .frame(maxWidth: UIScreen.main.bounds.width * 0.78, alignment: isSpeakerA ? .leading : .trailing)
            
            if !isSpeakerA {
                avatarCircle(initial: String(turn.speakerName.prefix(1)), color: accentColor, isSpeakerA: false)
            } else {
                Spacer(minLength: 40)
            }
        }
    }
    
    private func avatarCircle(initial: String, color: Color, isSpeakerA: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isSpeakerA ? Color.speakitBadgeBackground : Color.speakitCard)
                .frame(width: 32, height: 32)
                .overlay(Circle().stroke(isSpeakerA ? color.opacity(0.3) : Color.speakitBorder, lineWidth: 1))
            Text(initial.uppercased())
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
        }
    }
    
    private var exportContent: String {
        var lines: [String] = ["=== \(item.liveChatTitle) ===", "Date: \(item.formattedDateAndTime)", ""]
        for turn in item.parsedLiveChatTurns {
            lines.append("[\(turn.speakerName)] (\(turn.speakerLanguage)): \(turn.originalText)")
            if let translated = turn.translatedText, !translated.isEmpty {
                lines.append("  ↳ [\(turn.targetLanguage ?? "")]: \(translated)")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}
