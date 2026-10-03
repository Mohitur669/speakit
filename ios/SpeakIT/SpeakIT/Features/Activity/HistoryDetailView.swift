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
    @State private var playerManager = AudioPlayerManager.shared
    @State private var isLoadingAudio: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isDeleting: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var copiedToClipboard: Bool = false
    @State private var bannerMessage: String? = nil
    
    private var isLoadedForThisItem: Bool {
        guard let currentURL = playerManager.currentAudioURL else { return false }
        if currentURL.lastPathComponent == "history_\(item.id).mp3" {
            return true
        }
        if let localURL = item.localAudioURL, currentURL == localURL {
            return true
        }
        return false
    }
    
    private var isPlayingThisItem: Bool {
        playerManager.isPlaying && isLoadedForThisItem
    }
    
    private var activeAudioShareURL: URL? {
        if let local = item.localAudioURL, FileManager.default.fileExists(atPath: local.path) {
            return local
        }
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AudioHistory", isDirectory: true)
        let cachedFileURL = cacheDir.appendingPathComponent("history_\(item.id).mp3")
        if FileManager.default.fileExists(atPath: cachedFileURL.path),
           let attrs = try? FileManager.default.attributesOfItem(atPath: cachedFileURL.path),
           let fileSize = attrs[.size] as? Int64, fileSize > 0 {
            return cachedFileURL
        }
        return nil
    }
    
    private var hasAudioAvailable: Bool {
        // Show player only when audio actually exists — either cached on disk or a CDN/backend URL from the server.
        // Do NOT fall back to engineType == "TTS" — legacy items may have no stored audio at all.
        if let local = item.localAudioURL, FileManager.default.fileExists(atPath: local.path) { return true }
        if let urlStr = item.audioUrl, !urlStr.isEmpty { return true }
        return false
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Metadata Hero Card
                    metadataCard
                    
                    // Audio Playback Controller (Only visible when speech / audio is available)
                    if hasAudioAvailable {
                        audioPlaybackCard
                    }
                    
                    // Full Text Transcript Card
                    fullTextCard
                    
                    // Transliteration Card (Only if present)
                    if let transliteration = item.transliteration, !transliteration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        transliterationCard(transliteration)
                    }
                    
                    // Delete Action Button
                    deleteButton
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color.speakitScreenBackground.ignoresSafeArea())
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
            .speakITToast(message: $errorMessage, style: .error, bottomPadding: 20)
            .speakITToast(message: $bannerMessage, style: .info, bottomPadding: 20)
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
            }
        }
        .padding(16)
        .background(Color.speakitCardSurface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.speakitBorder, lineWidth: 1)
        )
    }
    
    // MARK: - 2. Minimal Audio Playback Controller
    private var audioPlaybackCard: some View {
        HStack(spacing: 12) {
            // 1. Play / Pause Button
            Button(action: {
                togglePlayback()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.speakitPrimary)
                        .frame(width: 40, height: 40)
                    
                    if isLoadingAudio {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: isPlayingThisItem ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: isPlayingThisItem ? 0 : 1.5)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isLoadingAudio)
            .accessibilityLabel(isPlayingThisItem ? "Pause audio" : "Play audio")
            
            // 2. Progress Bar & Duration
            VStack(spacing: 3) {
                Slider(
                    value: Binding(
                        get: { isLoadedForThisItem ? playerManager.currentTime : 0 },
                        set: { newValue in
                            if isLoadedForThisItem {
                                playerManager.seek(to: newValue)
                            }
                        }
                    ),
                    in: 0...max(1.0, isLoadedForThisItem ? playerManager.duration : 1.0)
                )
                .tint(Color.speakitPrimary)
                .disabled(!isLoadedForThisItem || playerManager.duration <= 0)
                
                HStack {
                    Text(formatTime(isLoadedForThisItem ? playerManager.currentTime : 0))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.speakitTextTertiary)
                    
                    Spacer()
                    
                    Text(formatTime(isLoadedForThisItem ? playerManager.duration : 0))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.speakitTextTertiary)
                }
            }
            
            // 3. Share Button
            if let shareURL = activeAudioShareURL {
                ShareLink(item: shareURL) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.speakitPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color.speakitBadgeBackground)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Share audio file")
            } else {
                ShareLink(item: item.displayText, subject: Text("SpeakIT Audio Transcript")) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.speakitPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color.speakitBadgeBackground)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Share transcript")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.speakitCardSurface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.speakitBorder, lineWidth: 1)
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
                .background(Color.speakitCard)
                .cornerRadius(12)
        }
        .padding(16)
        .background(Color.speakitCardSurface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.speakitBorder, lineWidth: 1)
        )
    }
    
    // MARK: - 3b. Transliteration Card
    private func transliterationCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "character.book.closed.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color.speakitPrimary)
                    Text("TRANSLITERATION")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.speakitTextTertiary)
                }
                
                Spacer()
                
                Button(action: {
                    UIPasteboard.general.string = text
                    HapticManager.shared.medium()
                    bannerMessage = "Transliteration copied to clipboard."
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Copy")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(Color.speakitPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.speakitBadgeBackground)
                    .clipShape(Capsule())
                }
            }
            
            Text(text)
                .font(.system(size: 14, weight: .regular, design: .serif))
                .italic()
                .foregroundColor(Color.speakitTextPrimary)
                .lineSpacing(4)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.speakitCard)
                .cornerRadius(12)
        }
        .padding(16)
        .background(Color.speakitCardSurface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.speakitBorder, lineWidth: 1)
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
        HapticManager.shared.light()
        
        // 1. If currently playing this item, pause it
        if isPlayingThisItem {
            playerManager.pause()
            return
        }
        
        // 2. If this item's audio is already loaded in player, resume playback
        if isLoadedForThisItem {
            playerManager.play()
            return
        }
        
        // 3. Prevent duplicate requests
        if isLoadingAudio { return }
        
        // 4. Local Memory URL check (e.g. freshly generated session audio)
        if let localURL = item.localAudioURL, FileManager.default.fileExists(atPath: localURL.path) {
            playerManager.loadAndPlay(url: localURL, title: item.textSnippet, subtitle: item.subtitle)
            return
        }
        
        // 5. Two-Tier Audio Cache: Check persistent local disk cache (<Caches>/AudioHistory/history_{id}.mp3)
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AudioHistory", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let cachedFileURL = cacheDir.appendingPathComponent("history_\(item.id).mp3")
        
        if FileManager.default.fileExists(atPath: cachedFileURL.path),
           let attrs = try? FileManager.default.attributesOfItem(atPath: cachedFileURL.path),
           let fileSize = attrs[.size] as? Int64, fileSize > 0 {
            // Fast Path: Already cached on disk -> Instant 0ms playback!
            playerManager.loadAndPlay(url: cachedFileURL, title: item.textSnippet, subtitle: item.subtitle)
            return
        }
        
        // 6. On-Demand Lazy Download
        isLoadingAudio = true
        Task {
            do {
                var data: Data? = nil
                
                // Tier A: Direct zero-egress Cloudflare R2 CDN download if public URL is present
                if let urlStr = item.audioUrl, urlStr.hasPrefix("http"), let remoteURL = URL(string: urlStr) {
                    data = try? await HTTPClient.shared.downloadBinaryFromURL(remoteURL)
                }
                
                // Tier B: Fallback to authenticated backend streaming endpoint (/api/history/{id}/audio)
                if data == nil || data?.isEmpty == true {
                    data = try await HTTPClient.shared.downloadBinaryGet(.historyAudio(id: item.id))
                }
                
                guard let finalData = data, !finalData.isEmpty else {
                    throw APIError.missingData
                }
                
                // Persist to local disk cache for instant offline and future replay
                try finalData.write(to: cachedFileURL, options: .atomic)
                
                await MainActor.run {
                    self.isLoadingAudio = false
                    self.playerManager.loadAndPlay(
                        url: cachedFileURL,
                        title: item.textSnippet,
                        subtitle: item.subtitle
                    )
                }
            } catch {
                await MainActor.run {
                    self.isLoadingAudio = false
                    print("Failed to load on-demand audio for history item \(item.id): \(error)")
                    self.errorMessage = "Unable to play audio: \(error.localizedDescription)"
                    HapticManager.shared.error()
                }
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func copyTextToClipboard() {
        UIPasteboard.general.string = item.displayText
        HapticManager.shared.medium()
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
                HapticManager.shared.success()
                onDelete?(item)
                dismiss()
            }
        }
    }
}

#Preview {
    HistoryDetailView(item: HistoryItem.samples[0])
}
