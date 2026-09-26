//
//  SpeakITHistoryRow.swift
//  SpeakIT
//
//  History item row matching 06_Activity.svg.
//

import SwiftUI

struct SpeakITHistoryRow: View {
    let item: HistoryItem
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil
    var onTap: (() -> Void)? = nil
    var onPlay: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            if isSelectionMode {
                // Multiselect Checkbox
                Button(action: {
                    HapticManager.shared.selection()
                    onSelect?()
                }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(isSelected ? Color.speakitPrimary : Color.speakitTextTertiary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSelected ? "Selected" : "Not selected")
            } else {
                // Play Button
                Button(action: {
                    HapticManager.shared.light()
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
            }
            
            // Text snippet & subtitle - tapping opens detail or toggles selection
            VStack(alignment: .leading, spacing: 3) {
                Text(item.textSnippet)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.speakitTextPrimary)
                    .lineLimit(1)
                
                Text(item.subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color.speakitTextSecondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelectionMode {
                    HapticManager.shared.selection()
                    onSelect?()
                } else {
                    onTap?()
                }
            }
            
            Spacer()
            
            // Timestamp and optional chevron
            HStack(spacing: 6) {
                Text(item.timeAgoFormatted)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.speakitTextTertiary)
                
                if !isSelectionMode {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.speakitTextTertiary.opacity(0.7))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelectionMode {
                    HapticManager.shared.selection()
                    onSelect?()
                } else {
                    onTap?()
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 70)
        .background(isSelected ? Color.speakitPrimary.opacity(0.05) : Color.speakitBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.speakitPrimary : Color(hex: "E3E3E8"), lineWidth: isSelected ? 1.5 : 1)
        )
    }
}
