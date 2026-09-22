//
//  SpeakITVoiceRow.swift
//  SpeakIT
//
//  Voice row item matching 03_Voice_Catalog.svg.
//

import SwiftUI

struct SpeakITVoiceRow: View {
    let voice: Voice
    let isSelected: Bool
    let isLocked: Bool
    var onSelect: () -> Void
    var onPreview: () -> Void
    
    @State private var isFavorite: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Preview Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onPreview()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.speakitBadgeBackground)
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.speakitPrimary)
                        .offset(x: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Preview \(voice.name)")
            
            // Name and details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(voice.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.speakitTextPrimary)
                    
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color.speakitTextTertiary)
                    }
                }
                
                Text(voice.subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color.speakitTextSecondary)
            }
            
            Spacer()
            
            // Favorite Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                isFavorite.toggle()
            }) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isFavorite ? Color.speakitPrimary : Color.speakitTextTertiary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "Remove favorite" : "Add to favorites")
        }
        .padding(.horizontal, 16)
        .frame(height: 60)
        .background(isSelected ? Color.speakitBadgeBackground.opacity(0.5) : Color.speakitBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.speakitPrimary : Color(hex: "E1E1E6"), lineWidth: isSelected ? 1.5 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            UISelectionFeedbackGenerator().selectionChanged()
            onSelect()
        }
    }
}
