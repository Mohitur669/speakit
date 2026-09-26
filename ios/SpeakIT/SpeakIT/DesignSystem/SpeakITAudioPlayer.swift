//
//  SpeakITAudioPlayer.swift
//  SpeakIT
//
//  Native inline audio player matching 02_TTS_Studio.svg and AVFoundation architecture.
//

import SwiftUI

struct SpeakITAudioPlayer: View {
    @Bindable var playerManager: AudioPlayerManager
    var onShare: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                // Play / Pause Circle
                Button(action: {
                    HapticManager.shared.medium()
                    playerManager.togglePlayPause()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.speakitPrimary)
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: playerManager.isPlaying ? 0 : 1.5)
                    }
                }
                .accessibilityLabel(playerManager.isPlaying ? "Pause audio" : "Play audio")
                
                // Scrubber Slider
                VStack(spacing: 4) {
                    Slider(
                        value: Binding(
                            get: { playerManager.currentTime },
                            set: { newValue in
                                playerManager.seek(to: newValue)
                            }
                        ),
                        in: 0...max(1.0, playerManager.duration)
                    )
                    .tint(Color.speakitWaveformBar)
                    
                    HStack {
                        Text(formatTime(playerManager.currentTime))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.speakitTextTertiary)
                        Spacer()
                        Text(formatTime(playerManager.duration))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.speakitTextTertiary)
                    }
                }
                
                // Share Button
                if let onShare = onShare {
                    Button(action: {
                        HapticManager.shared.light()
                        onShare()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color.speakitPrimary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Share audio")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0) : UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)
        }))
        .cornerRadius(18)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
