//
//  UpdateEmailSheet.swift
//  SpeakIT
//
//  Dedicated sheet for updating user email with password pre-verification and OTP validation.
//

import SwiftUI
import Combine

struct UpdateEmailSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    var onSuccess: () -> Void
    
    @State private var newEmail: String = ""
    @State private var currentPassword: String = ""
    @State private var otp: String = ""
    @State private var step: Int = 1 // 1: Password entry & OTP request, 2: OTP & New Email
    @State private var showPassword: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var cooldownSeconds: Int = 0
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SpeakITBanner(message: $errorMessage, style: .error)
                    
                    if step == 1 {
                        step1PasswordView
                    } else {
                        step2OtpAndNewEmailView
                    }
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
                .padding(.top, 16)
                .padding(.bottom, 36)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(step == 1 ? "Update Email" : "Verify Email Change")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onReceive(timer) { _ in
                if cooldownSeconds > 0 {
                    cooldownSeconds -= 1
                }
            }
        }
        .presentationDetents([.large])
    }
    
    // MARK: - Step 1: Security Password Verification
    @ViewBuilder
    private var step1PasswordView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.speakitPrimary.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "envelope.badge.shield.half.filled")
                        .foregroundColor(Color.speakitPrimary)
                        .font(.system(size: 18))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Security Verification")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color.speakitTextPrimary)
                    Text("Enter your password to authorize an email change.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.speakitTextSecondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Current Email")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.speakitTextSecondary)
                Text(appState.currentUser?.email ?? "")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.speakitTextPrimary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "F8F8FA"))
                    .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Current Password *")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.speakitTextSecondary)
                
                HStack {
                    if showPassword {
                        TextField("Enter current password", text: $currentPassword)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    } else {
                        SecureField("Enter current password", text: $currentPassword)
                    }
                    
                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundColor(Color.speakitTextTertiary)
                    }
                }
                .padding(12)
                .background(Color(hex: "F8F8FA"))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "E6E6EB"), lineWidth: 1)
                )
            }
            
            SpeakITButton(
                title: "Send Verification Code",
                style: .primary,
                isLoading: isLoading,
                isEnabled: !currentPassword.isEmpty
            ) {
                requestEmailOtp()
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Step 2: OTP & New Email Entry
    @ViewBuilder
    private var step2OtpAndNewEmailView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.speakitPrimary.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(Color.speakitPrimary)
                        .font(.system(size: 18))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enter Verification Code")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color.speakitTextPrimary)
                    Text("Sent to \(appState.currentUser?.email ?? "your current email")")
                        .font(.system(size: 13))
                        .foregroundColor(Color.speakitTextSecondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("New Email Address *")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.speakitTextSecondary)
                
                SpeakITTextField(
                    placeholder: "Enter new email address",
                    text: $newEmail,
                    icon: "envelope.fill",
                    keyboardType: .emailAddress,
                    autoCapitalization: .never
                )
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Verification Code (OTP) *")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.speakitTextSecondary)
                
                SpeakITTextField(
                    placeholder: "Enter 6-digit code",
                    text: $otp,
                    icon: "number",
                    keyboardType: .numberPad
                )
            }
            
            HStack {
                Button(action: {
                    requestEmailOtp()
                }) {
                    if cooldownSeconds > 0 {
                        Text("Resend code in \(cooldownSeconds)s")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.speakitTextTertiary)
                    } else {
                        Text("Resend Code")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.speakitPrimary)
                    }
                }
                .disabled(cooldownSeconds > 0 || isLoading)
                
                Spacer()
            }
            
            SpeakITButton(
                title: "Confirm & Update Email",
                style: .primary,
                isLoading: isLoading,
                isEnabled: !newEmail.trimmingCharacters(in: .whitespaces).isEmpty && otp.trimmingCharacters(in: .whitespaces).count >= 6
            ) {
                submitEmailUpdate()
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Actions
    private func requestEmailOtp() {
        errorMessage = nil
        isLoading = true
        
        Task {
            do {
                struct RequestEmailOtpPayload: Codable {
                    let currentPassword: String
                }
                let body = try JSONEncoder().encode(RequestEmailOtpPayload(currentPassword: currentPassword))
                let _: EmptyResponse = try await HTTPClient.shared.request(.requestEmailChangeOtp, method: "POST", body: body)
                
                await MainActor.run {
                    self.isLoading = false
                    self.cooldownSeconds = 60
                    self.step = 2
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func submitEmailUpdate() {
        errorMessage = nil
        isLoading = true
        let cleanNewEmail = newEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanOtp = otp.trimmingCharacters(in: .whitespacesAndNewlines).filter { $0.isNumber }
        
        Task {
            do {
                struct UpdateEmailPayload: Codable {
                    let newEmail: String
                    let currentPassword: String
                    let otp: String
                }
                let body = try JSONEncoder().encode(UpdateEmailPayload(
                    newEmail: cleanNewEmail,
                    currentPassword: currentPassword,
                    otp: cleanOtp
                ))
                let updatedUser: User = try await HTTPClient.shared.request(.updateEmail, method: "PUT", body: body)
                
                await MainActor.run {
                    self.isLoading = false
                    self.appState.currentUser = updatedUser
                    self.dismiss()
                    self.onSuccess()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
