//
//  SpeakITHistoryRow.swift
//  SpeakIT
//
//  History item row matching 06_Activity.svg.
//

import SwiftUI

struct SpeakITHistoryRow: View {
    let item: HistoryItem
    var onPlay: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            // Play Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onPlay()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.speakitBadgeBackground)
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.speakitPrimary)
                        .offset(x: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play \(item.textSnippet)")
            
            // Text snippet & subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text(item.textSnippet)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.speakitTextPrimary)
                    .lineLimit(1)
                
                Text(item.subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color.speakitTextSecondary)
            }
            
            Spacer()
            
            // Timestamp
            Text(item.timeAgoFormatted)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.speakitTextTertiary)
        }
        .padding(.horizontal, 16)
        .frame(height: 70)
        .background(Color.speakitBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "E3E3E8"), lineWidth: 1)
        )
    }
}
