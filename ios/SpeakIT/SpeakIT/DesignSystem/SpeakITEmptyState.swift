//
//  SpeakITEmptyState.swift
//  SpeakIT
//
//  Empty state component for empty lists and initial states.
//

import SwiftUI

struct SpeakITEmptyState: View {
    let icon: String
    let title: String
    let description: String
    var buttonTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.speakitBadgeBackground)
                    .frame(width: 64, height: 64)
                
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(Color.speakitPrimary)
            }
            
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.speakitTextPrimary)
            
            Text(description)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color.speakitTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if let buttonTitle = buttonTitle, let action = action {
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.speakitPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.speakitBadgeBackground)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
}
