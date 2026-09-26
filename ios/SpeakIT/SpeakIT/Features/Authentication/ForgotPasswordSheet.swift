//
//  ForgotPasswordSheet.swift
//  SpeakIT
//
//  Sheet for requesting password reset via OTP and setting a new password.
//

import SwiftUI

struct ForgotPasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSuccess: () -> Void
    
    init(onSuccess: @escaping () -> Void) {
        self.onSuccess = onSuccess
    }
    
    @State private var email: String = ""
    @State private var otp: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var step: Int = 1 // 1: Email, 2: OTP & New Password
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SpeakITBanner(message: $errorMessage, style: .error)
                    
                    if step == 1 {
                        step1EmailView
                    } else {
                        step2OtpPasswordView
                    }
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
                .padding(.top, 16)
                .padding(.bottom, 36)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(step == 1 ? "Forgot Password" : "Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
    
    // MARK: - Step 1: Email Input
    @ViewBuilder
    private var step1EmailView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.speakitPrimary.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "key.fill")
                        .foregroundColor(Color.speakitPrimary)
                        .font(.system(size: 18))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Password Recovery")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color.speakitTextPrimary)
                    Text("We'll send a 6-digit verification code to your email.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.speakitTextSecondary)
                }
            }
            
            
            SpeakITTextField(
                placeholder: "Enter your registered email",
                text: $email,
                icon: "envelope.fill",
                keyboardType: .emailAddress,
                autoCapitalization: .never
            )
            
            SpeakITButton(
                title: "Send Verification Code",
                style: .primary,
                isLoading: isLoading,
                isEnabled: !email.trimmingCharacters(in: .whitespaces).isEmpty
            ) {
                requestResetOtp()
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Step 2: OTP & New Password
    @ViewBuilder
    private var step2OtpPasswordView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.speakitPrimary.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "lock.rotation")
                        .foregroundColor(Color.speakitPrimary)
                        .font(.system(size: 18))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enter Verification Code")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color.speakitTextPrimary)
                    Text("Sent to \(email)")
                        .font(.system(size: 13))
                        .foregroundColor(Color.speakitTextSecondary)
                }
            }
            
            
            SpeakITTextField(
                placeholder: "6-digit OTP code",
                text: $otp,
                icon: "number",
                keyboardType: .numberPad
            )
            
            SpeakITTextField(
                placeholder: "New Password (min 8 characters)",
                text: $newPassword,
                icon: "lock.fill",
                isSecure: true
            )
            
            SpeakITTextField(
                placeholder: "Confirm New Password",
                text: $confirmPassword,
                icon: "lock.shield.fill",
                isSecure: true
            )
            
            HStack {
                Button(action: {
                    requestResetOtp()
                }) {
                    Text("Resend Code")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.speakitPrimary)
                }
                Spacer()
            }
            
            SpeakITButton(
                title: "Reset Password",
                style: .primary,
                isLoading: isLoading,
                isEnabled: otp.trimmingCharacters(in: .whitespaces).count >= 6 && newPassword.count >= 8 && newPassword == confirmPassword
            ) {
                submitResetPassword()
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Actions
    private func requestResetOtp() {
        errorMessage = nil
        isLoading = true
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        Task {
            do {
                struct ForgotPasswordReq: Codable {
                    let email: String
                }
                let body = try JSONEncoder().encode(ForgotPasswordReq(email: cleanEmail))
                let _: EmptyResponse = try await HTTPClient.shared.request(.forgotPassword, method: "POST", body: body)
                
                await MainActor.run {
                    self.isLoading = false
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
    
    private func submitResetPassword() {
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        errorMessage = nil
        isLoading = true
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanOtp = otp.trimmingCharacters(in: .whitespacesAndNewlines).filter { $0.isNumber }
        
        Task {
            do {
                struct ResetPasswordReq: Codable {
                    let email: String
                    let otp: String
                    let newPassword: String
                }
                let body = try JSONEncoder().encode(ResetPasswordReq(
                    email: cleanEmail,
                    otp: cleanOtp,
                    newPassword: newPassword
                ))
                let _: EmptyResponse = try await HTTPClient.shared.request(.resetPassword, method: "POST", body: body)
                
                await MainActor.run {
                    self.isLoading = false
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
