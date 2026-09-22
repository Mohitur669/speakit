//
//  SpeakITButton.swift
//  SpeakIT
//
//  Reusable primary and secondary buttons matching the design system.
//

import SwiftUI

enum SpeakITButtonStyle {
    case primary
    case secondary
    case outline
    case destructive
}

struct SpeakITButton: View {
    let title: String
    var icon: String? = nil
    var style: SpeakITButtonStyle = .primary
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            guard isEnabled && !isLoading else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                        .scaleEffect(0.9)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: SpeakITSpacing.buttonHeight)
            .background(backgroundView)
            .foregroundColor(textColor)
            .cornerRadius(SpeakITSpacing.buttonRadius)
            .overlay(
                RoundedRectangle(cornerRadius: SpeakITSpacing.buttonRadius)
                    .stroke(borderColor, lineWidth: style == .outline ? 1 : 0)
            )
            .opacity(isEnabled ? 1.0 : 0.5)
        }
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(title)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            Color.speakitPrimaryGradient
        case .secondary:
            Color.speakitBadgeBackground
        case .outline:
            Color.speakitBackground
        case .destructive:
            Color.speakitDestructiveLight
        }
    }
    
    private var textColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return Color.speakitPrimary
        case .outline:
            return Color.speakitTextPrimary
        case .destructive:
            return Color.speakitDestructive
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .outline:
            return Color.speakitBorder
        default:
            return .clear
        }
    }
}
