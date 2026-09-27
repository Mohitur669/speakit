//
//  SpeakITBanner.swift
//  SpeakIT
//
//  Floating bottom toast notification matching modern iOS HIG and ergonomic standards.
//

import SwiftUI

enum SpeakITBannerStyle {
    case success
    case error
    case info
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var tintColor: Color {
        switch self {
        case .success: return Color.speakitSuccess
        case .error: return Color.speakitDestructive
        case .info: return Color.speakitPrimary
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .success: return Color.speakitSuccessLight
        case .error: return Color.speakitDestructiveLight
        case .info: return Color.speakitBadgeBackground
        }
    }
    
    var defaultDuration: Double {
        switch self {
        case .success: return 4.0
        case .error: return 5.0
        case .info: return 3.5
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
            HStack(spacing: 12) {
                Image(systemName: style.icon)
                    .foregroundColor(style.tintColor)
                    .font(.system(size: 16, weight: .semibold))
                
                Text(msg)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.speakitTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3)
                
                Button(action: {
                    dismissTask?.cancel()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        message = nil
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.speakitTextSecondary)
                        .padding(4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.speakitCardSurface)
                    .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(style.tintColor.opacity(0.4), lineWidth: 1)
            )
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            ))
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
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        if self.message == currentText {
                            self.message = nil
                        }
                    }
                }
            }
        }
    }
}

// MARK: - View Toast Modifiers (Floating Bottom)
extension View {
    /// Presents a single toast anchored floating at the bottom with customizable bottom padding.
    func speakITToast(
        message: Binding<String?>,
        style: SpeakITBannerStyle,
        bottomPadding: CGFloat = 16
    ) -> some View {
        self.overlay(alignment: .bottom) {
            if let msg = message.wrappedValue, !msg.isEmpty {
                SpeakITBanner(message: message, style: style)
                    .padding(.horizontal, SpeakITSpacing.screenMargin)
                    .padding(.bottom, bottomPadding)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: message.wrappedValue)
                    .zIndex(999)
            }
        }
    }
    
    /// Presents coordinated success and error toasts anchored floating at the bottom.
    func speakITToast(
        successMessage: Binding<String?>,
        errorMessage: Binding<String?>,
        bottomPadding: CGFloat = 16
    ) -> some View {
        self.overlay(alignment: .bottom) {
            if let err = errorMessage.wrappedValue, !err.isEmpty {
                SpeakITBanner(message: errorMessage, style: .error)
                    .padding(.horizontal, SpeakITSpacing.screenMargin)
                    .padding(.bottom, bottomPadding)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: errorMessage.wrappedValue)
                    .zIndex(999)
            } else if let success = successMessage.wrappedValue, !success.isEmpty {
                SpeakITBanner(message: successMessage, style: .success)
                    .padding(.horizontal, SpeakITSpacing.screenMargin)
                    .padding(.bottom, bottomPadding)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: successMessage.wrappedValue)
                    .zIndex(999)
            }
        }
    }
}
