//
//  SpeakITBanner.swift
//  SpeakIT
//
//  Self-dismissing alert & toast banner supporting success and error notifications.
//

import SwiftUI

enum SpeakITBannerStyle {
    case success
    case error
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        }
    }
    
    var tintColor: Color {
        switch self {
        case .success: return Color.speakitSuccess
        case .error: return Color.speakitDestructive
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .success: return Color.speakitSuccessLight
        case .error: return Color.speakitDestructiveLight
        }
    }
    
    var defaultDuration: Double {
        switch self {
        case .success: return 4.0
        case .error: return 5.0
        }
    }
}

struct SpeakITBanner: View {
    @Binding var message: String?
    var style: SpeakITBannerStyle
    var autoDismissDuration: Double? = nil
    
    @State private var dismissTask: Task<Void, Never>? = nil
    
    var body: some View {
        if let msg = message, !msg.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: style.icon)
                    .foregroundColor(style.tintColor)
                    .font(.system(size: 15, weight: .semibold))
                
                Text(msg)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(style.tintColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3)
                
                Button(action: {
                    dismissTask?.cancel()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        message = nil
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(style.tintColor.opacity(0.7))
                        .padding(4)
                }
            }
            .padding(12)
            .background(style.backgroundColor)
            .cornerRadius(12)
            .transition(.opacity.combined(with: .move(edge: .top)))
            .onAppear {
                scheduleDismissal(for: msg)
            }
            .onChange(of: message) { _, newMsg in
                if let newMsg = newMsg, !newMsg.isEmpty {
                    scheduleDismissal(for: newMsg)
                }
            }
            .onDisappear {
                dismissTask?.cancel()
            }
        }
    }
    
    private func scheduleDismissal(for currentText: String) {
        dismissTask?.cancel()
        let timeoutSeconds = autoDismissDuration ?? style.defaultDuration
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if self.message == currentText {
                            self.message = nil
                        }
                    }
                }
            }
        }
    }
}
