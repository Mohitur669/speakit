//
//  HistoryDetailView.swift
//  SpeakIT
//
//  Single history item detail view displaying the complete text transcript,
//  audio playback, metadata, and deletion option.
//

import SwiftUI

struct HistoryDetailView: View {
    let item: HistoryItem
    var onDelete: ((HistoryItem) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @State private var isDeleting: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var copiedToClipboard: Bool = false
    @State private var bannerMessage: String? = nil
    
    private var isCurrentlyPlaying: Bool {
        AudioPlayerManager.shared.isPlaying
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Feedback / Error Banner
                    SpeakITBanner(message: $bannerMessage, style: .info)
                    
                    // Metadata Hero Card
                    metadataCard
                    
                    // Audio Playback Controller
                    audioPlaybackCard
                    
                    // Full Text Transcript Card
                    fullTextCard
                    
                    // Delete Action Button
                    deleteButton
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color(hex: "F8F9FB").ignoresSafeArea())
            .navigationTitle("Generation Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.speakitPrimary)
                }
            }
            .alert("Delete Generation", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteItem()
                }
            } message: {
                Text("Are you sure you want to permanently delete this generation from your history? This action cannot be undone.")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - 1. Metadata Card
    private var metadataCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.speakitBadgeBackground)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: item.engineType == "STT" ? "mic.fill" : "waveform")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.speakitPrimary)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.voiceName ?? (item.engineType == "STT" ? "Speech-to-Text" : "Speech Synthesis"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color.speakitTextPrimary)
                    
                    Text(item.timeAgoFormatted)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.speakitTextSecondary)
                }
                
                Spacer()
                
                SpeakITQuotaBadge(text: item.engineType)
            }
            
            Divider()
                .padding(.vertical, 2)
            
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "character.cursor.ibeam")
                        .font(.system(size: 11))
                    Text("\(item.characterCount) characters")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(Color.speakitTextSecondary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 10))
                    Text("ID: #\(item.id)")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(Color.speakitTextTertiary)
            }
        }
        .padding(16)
        .background(Color.speakitBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "E6E6EB"), lineWidth: 1)
        )
    }
    
    // MARK: - 2. Audio Playback Card
    private var audioPlaybackCard: some View {
        HStack(spacing: 14) {
            Button(action: {
                togglePlayback()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.speakitPrimary)
                        .frame(width: 42, height: 42)
                    
                    Image(systemName: isCurrentlyPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: isCurrentlyPlaying ? 0 : 1)
                }
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(isCurrentlyPlaying ? "Playing Audio" : "Listen to Generation")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.speakitTextPrimary)
                
                Text(item.subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color.speakitTextSecondary)
            }
            
            Spacer()
            
            ShareLink(item: item.displayText, subject: Text("SpeakIT Audio Transcript")) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.speakitPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.speakitBadgeBackground)
                    .clipShape(Circle())
            }
        }
        .padding(14)
        .background(Color.speakitBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "E6E6EB"), lineWidth: 1)
        )
    }
    
    // MARK: - 3. Full Text Transcript Card
    private var fullTextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.engineType == "STT" ? "TRANSCRIPT" : "FULL TEXT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.speakitTextTertiary)
                
                Spacer()
                
                Button(action: {
                    copyTextToClipboard()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11, weight: .semibold))
                        Text(copiedToClipboard ? "Copied" : "Copy Text")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(copiedToClipboard ? Color.speakitSuccess : Color.speakitPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.speakitBadgeBackground)
                    .clipShape(Capsule())
                }
            }
            
            Text(item.displayText)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color.speakitTextPrimary)
                .lineSpacing(5)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(hex: "F2F2F7"))
                .cornerRadius(12)
        }
        .padding(16)
        .background(Color.speakitBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "E6E6EB"), lineWidth: 1)
        )
    }
    
    // MARK: - 4. Delete Generation Button
    private var deleteButton: some View {
        Button(action: {
            showDeleteConfirmation = true
        }) {
            HStack(spacing: 8) {
                if isDeleting {
                    ProgressView()
                        .tint(Color.speakitDestructive)
                } else {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text("Delete from History")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(Color.speakitDestructive)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.speakitDestructiveLight.opacity(0.4))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.speakitDestructive.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isDeleting)
    }
    
    // MARK: - Actions
    private func togglePlayback() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if AudioPlayerManager.shared.isPlaying {
            AudioPlayerManager.shared.pause()
        } else {
            if let localURL = item.localAudioURL {
                AudioPlayerManager.shared.loadAndPlay(url: localURL, title: item.textSnippet, subtitle: item.subtitle)
            } else {
                let tempDir = FileManager.default.temporaryDirectory
                let fallbackURL = tempDir.appendingPathComponent("history_\(item.id).mp3")
                try? Data(repeating: 0, count: 1024).write(to: fallbackURL)
                AudioPlayerManager.shared.loadAndPlay(url: fallbackURL, title: item.textSnippet, subtitle: item.subtitle)
            }
        }
    }
    
    private func copyTextToClipboard() {
        UIPasteboard.general.string = item.displayText
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation {
            copiedToClipboard = true
            bannerMessage = "Text copied to clipboard."
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                copiedToClipboard = false
            }
        }
    }
    
    private func deleteItem() {
        isDeleting = true
        Task {
            let ids: [Int64] = [item.id]
            let bodyData = try? JSONEncoder().encode(ids)
            let _: EmptyResponse? = try? await HTTPClient.shared.request(.deleteHistory, method: "DELETE", body: bodyData)
            
            await MainActor.run {
                isDeleting = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onDelete?(item)
                dismiss()
            }
        }
    }
}

#Preview {
    HistoryDetailView(item: HistoryItem.samples[0])
}
