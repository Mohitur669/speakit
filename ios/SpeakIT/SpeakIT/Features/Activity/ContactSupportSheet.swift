//
//  ContactSupportSheet.swift
//  SpeakIT
//
//  Native in-app Contact & Support view integrated with backend /api/contact and Telegram notifications.
//

import SwiftUI

struct ContactSubmissionRequest: Codable {
    let firstName: String
    let lastName: String
    let email: String
    let topic: String
    let message: String
    let website: String?
}

struct ContactSubmissionResponse: Codable {
    let message: String
}

struct ContactSupportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AppState.self) private var appState
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var selectedTopicKey: String = "support"
    @State private var messageText: String = ""
    @State private var isSubmitting: Bool = false
    
    @State private var successBanner: String? = nil
    @State private var errorBanner: String? = nil
    @State private var dismissTimerTask: Task<Void, Never>? = nil
    
    private let topicOptions: [(key: String, label: String)] = [
        ("support", "Technical Support"),
        ("billing", "Billing & Subscriptions"),
        ("enterprise", "Enterprise Sales"),
        ("feedback", "Product Feedback")
    ]
    
    private var selectedTopicLabel: String {
        topicOptions.first(where: { $0.key == selectedTopicKey })?.label ?? "Technical Support"
    }
    
    private var isFormValid: Bool {
        let cleanFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMsg = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return !cleanFirst.isEmpty &&
               !cleanLast.isEmpty &&
               cleanEmail.contains("@") && cleanEmail.contains(".") &&
               cleanMsg.count >= 10
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Get in Touch")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Color.speakitTextPrimary)
                        
                        Text("Need technical assistance, billing help, or have product feedback? Reach out and our team will be notified directly.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color.speakitTextSecondary)
                    }
                    .padding(.top, 8)
                    
                    // Auto-timed Banners
                    if successBanner != nil {
                        SpeakITBanner(message: $successBanner, style: .success)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    if errorBanner != nil {
                        SpeakITBanner(message: $errorBanner, style: .error)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // Contact Channels
                    VStack(spacing: 12) {
                        contactChannelCard(
                            icon: "envelope.fill",
                            title: "Email Support",
                            detail: "support@mohitur.com",
                            actionTitle: "Send Email"
                        ) {
                            if let url = URL(string: "mailto:support@mohitur.com?subject=SpeakIT%20iOS%20Support") {
                                openURL(url)
                            }
                        }
                        
                        contactChannelCard(
                            icon: "bubble.left.and.bubble.right.fill",
                            title: "Developer Community",
                            detail: "Join our community discussions & updates",
                            actionTitle: "Discord"
                        ) {
                            if let url = URL(string: "https://discord.gg/speakit") {
                                openURL(url)
                            }
                        }
                        
                        contactChannelCard(
                            icon: "shield.checkerboard",
                            title: "Grievance Officer",
                            detail: "grievance@mohitur.com",
                            actionTitle: "Contact"
                        ) {
                            if let url = URL(string: "mailto:grievance@mohitur.com?subject=SpeakIT%20Grievance") {
                                openURL(url)
                            }
                        }
                    }
                    
                    // In-App Inquiry Form
                    VStack(alignment: .leading, spacing: 16) {
                        Text("SEND A MESSAGE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.speakitTextTertiary)
                            .tracking(0.5)
                        
                        // Name Fields Row
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("First Name")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.speakitTextPrimary)
                                
                                TextField("First name", text: $firstName)
                                    .padding(.horizontal, 14)
                                    .frame(height: 46)
                                    .background(Color(hex: "F8F9FB"))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                                    )
                                    .font(.system(size: 14))
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Last Name")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.speakitTextPrimary)
                                
                                TextField("Last name", text: $lastName)
                                    .padding(.horizontal, 14)
                                    .frame(height: 46)
                                    .background(Color(hex: "F8F9FB"))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                                    )
                                    .font(.system(size: 14))
                            }
                        }
                        
                        // Email Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email Address")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.speakitTextPrimary)
                            
                            TextField("your.email@example.com", text: $email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled(true)
                                .padding(.horizontal, 14)
                                .frame(height: 46)
                                .background(Color(hex: "F8F9FB"))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                                )
                                .font(.system(size: 14))
                        }
                        
                        // Topic Selector
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Topic")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.speakitTextPrimary)
                            
                            Menu {
                                ForEach(topicOptions, id: \.key) { option in
                                    Button(action: {
                                        selectedTopicKey = option.key
                                    }) {
                                        HStack {
                                            Text(option.label)
                                            if selectedTopicKey == option.key {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedTopicLabel)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color.speakitTextPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(Color.speakitTextTertiary)
                                }
                                .padding(.horizontal, 14)
                                .frame(height: 46)
                                .background(Color(hex: "F8F9FB"))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                                )
                            }
                        }
                        
                        // Message Text Area (Clean Premium styling without native grey frame)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Message")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.speakitTextPrimary)
                                
                                Spacer()
                                
                                let charCount = messageText.trimmingCharacters(in: .whitespacesAndNewlines).count
                                Text("\(charCount)/5000 (min 10)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(charCount >= 10 ? Color.speakitTextTertiary : Color.speakitDestructive)
                            }
                            
                            ZStack(alignment: .topLeading) {
                                if messageText.isEmpty {
                                    Text("Type your message, issue details, or questions here...")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(Color.speakitTextTertiary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                }
                                
                                TextEditor(text: $messageText)
                                    .scrollContentBackground(.hidden)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(Color.speakitTextPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                            }
                            .frame(minHeight: 125)
                            .background(Color(hex: "F8F9FB"))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                            )
                        }
                        
                        SpeakITButton(
                            title: isSubmitting ? "Sending..." : "Send Message",
                            style: .primary,
                            isLoading: isSubmitting,
                            isEnabled: isFormValid && !isSubmitting
                        ) {
                            submitInquiry()
                        }
                        .padding(.top, 4)
                    }
                    .padding(20)
                    .background(Color.speakitBackground)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(hex: "EAEAEA"), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
                .padding(.bottom, 36)
            }
            .background(Color(hex: "F8F9FB").ignoresSafeArea())
            .navigationTitle("Contact Support")
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
            .onAppear {
                prefillUserInfo()
            }
        }
    }
    
    private func prefillUserInfo() {
        if let user = appState.currentUser {
            if email.isEmpty {
                email = user.email
            }
            
            if firstName.isEmpty {
                let name = user.fullName.isEmpty ? user.username : user.fullName
                let parts = name.split(separator: " ")
                if parts.count >= 2 {
                    firstName = String(parts[0])
                    lastName = parts.dropFirst().joined(separator: " ")
                } else {
                    firstName = name
                }
            }
        }
    }
    
    private func contactChannelCard(icon: String, title: String, detail: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.speakitBadgeBackground)
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.speakitPrimary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.speakitTextPrimary)
                Text(detail)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color.speakitTextSecondary)
            }
            
            Spacer()
            
            Button(action: action) {
                Text(actionTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.speakitPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.speakitBadgeBackground)
                    .clipShape(Capsule())
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
    
    private func submitInquiry() {
        guard isFormValid else { return }
        
        isSubmitting = true
        clearBanners()
        
        let requestPayload = ContactSubmissionRequest(
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            topic: selectedTopicKey,
            message: messageText.trimmingCharacters(in: .whitespacesAndNewlines),
            website: "" // Anti-bot honeypot left intentionally empty
        )
        
        let requestId = UUID().uuidString
        
        Task {
            do {
                let bodyData = try JSONEncoder().encode(requestPayload)
                let response: ContactSubmissionResponse = try await HTTPClient.shared.request(
                    .contact,
                    method: "POST",
                    body: bodyData,
                    headers: ["X-Request-ID": requestId]
                )
                
                await MainActor.run {
                    self.isSubmitting = false
                    self.messageText = ""
                    self.showTemporarySuccess(response.message.isEmpty ? "Your message has been received! Our support team will get back to you shortly." : response.message)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    self.isSubmitting = false
                    let msg = error.localizedDescription
                    self.showTemporaryError(msg.isEmpty ? "Failed to send message. Please try again." : msg)
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }
    
    private func showTemporarySuccess(_ message: String) {
        dismissTimerTask?.cancel()
        withAnimation {
            self.successBanner = message
            self.errorBanner = nil
        }
        dismissTimerTask = Task {
            try? await Task.sleep(nanoseconds: 4_500_000_000) // 4.5 seconds auto-timeout
            await MainActor.run {
                withAnimation {
                    self.successBanner = nil
                }
            }
        }
    }
    
    private func showTemporaryError(_ message: String) {
        dismissTimerTask?.cancel()
        withAnimation {
            self.errorBanner = message
            self.successBanner = nil
        }
        dismissTimerTask = Task {
            try? await Task.sleep(nanoseconds: 4_500_000_000) // 4.5 seconds auto-timeout
            await MainActor.run {
                withAnimation {
                    self.errorBanner = nil
                }
            }
        }
    }
    
    private func clearBanners() {
        dismissTimerTask?.cancel()
        withAnimation {
            self.successBanner = nil
            self.errorBanner = nil
        }
    }
}

#Preview {
    ContactSupportSheet()
        .environment(AppState.shared)
}
