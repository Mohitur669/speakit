//
//  ChangePasswordSheet.swift
//  SpeakIT
//
//  Sheet for changing user password with complexity checklist and OTP validation.
//

import SwiftUI
import Combine

struct ChangePasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSuccess: () -> Void
    
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var otp: String = ""
    
    @State private var step: Int = 1 // 1: Password entry & OTP request, 2: OTP verification
    @State private var showCurrentPassword: Bool = false
    @State private var showNewPassword: Bool = false
    @State private var showConfirmPassword: Bool = false
    
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
                        step1PasswordsView
                    } else {
                        step2OtpView
                    }
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
                .padding(.top, 16)
                .padding(.bottom, 36)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(step == 1 ? "Change Password" : "Verify Password Change")
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
    
    // MARK: - Step 1: Passwords
    @ViewBuilder
    private var step1PasswordsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enter your current password and choose a strong new password.")
                .font(.system(size: 13))
                .foregroundColor(Color.speakitTextSecondary)
            
            // Current Password
            VStack(alignment: .leading, spacing: 6) {
                Text("Current Password *")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.speakitTextSecondary)
                
                HStack {
                    if showCurrentPassword {
                        TextField("Enter current password", text: $currentPassword)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    } else {
                        SecureField("Enter current password", text: $currentPassword)
                    }
                    
                    Button(action: { showCurrentPassword.toggle() }) {
                        Image(systemName: showCurrentPassword ? "eye.slash" : "eye")
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
            
            // New Password
            VStack(alignment: .leading, spacing: 6) {
                Text("New Password *")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.speakitTextSecondary)
                
                HStack {
                    if showNewPassword {
                        TextField("Enter new password", text: $newPassword)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    } else {
                        SecureField("Enter new password", text: $newPassword)
                    }
                    
                    Button(action: { showNewPassword.toggle() }) {
                        Image(systemName: showNewPassword ? "eye.slash" : "eye")
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
            
            // Confirm Password
            VStack(alignment: .leading, spacing: 6) {
                Text("Confirm New Password *")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.speakitTextSecondary)
                
                HStack {
                    if showConfirmPassword {
                        TextField("Confirm new password", text: $confirmPassword)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    } else {
                        SecureField("Confirm new password", text: $confirmPassword)
                    }
                    
                    Button(action: { showConfirmPassword.toggle() }) {
                        Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
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
            
            // Checklist
            VStack(alignment: .leading, spacing: 8) {
                Text("Password Requirements:")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.speakitTextPrimary)
                
                policyRow(title: "At least 8 characters", isMet: newPassword.count >= 8)
                policyRow(title: "Contains uppercase letter (A-Z)", isMet: newPassword.range(of: "[A-Z]", options: .regularExpression) != nil)
                policyRow(title: "Contains lowercase letter (a-z)", isMet: newPassword.range(of: "[a-z]", options: .regularExpression) != nil)
                policyRow(title: "Contains a number (0-9)", isMet: newPassword.range(of: "[0-9]", options: .regularExpression) != nil)
                policyRow(title: "Contains a special character (!@#$%^&*)", isMet: newPassword.range(of: "[!@#$%^&*(),.?\":{}|<>]", options: .regularExpression) != nil)
                policyRow(title: "Passwords match", isMet: !newPassword.isEmpty && newPassword == confirmPassword)
            }
            .padding(14)
            .background(Color(hex: "F8F8FA"))
            .cornerRadius(12)
            
            SpeakITButton(
                title: "Send Verification Code",
                style: .primary,
                isLoading: isLoading,
                isEnabled: isPasswordFormValid
            ) {
                requestPasswordOtp()
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Step 2: OTP
    @ViewBuilder
    private var step2OtpView: some View {
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
                    Text("Confirm Password Change")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color.speakitTextPrimary)
                    Text("Enter the 6-digit OTP code sent to your email.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.speakitTextSecondary)
                }
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
                    requestPasswordOtp()
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
                title: "Confirm & Update Password",
                style: .primary,
                isLoading: isLoading,
                isEnabled: otp.trimmingCharacters(in: .whitespaces).count >= 6
            ) {
                submitPasswordChange()
            }
            .padding(.top, 8)
        }
    }
    
    private var isPasswordFormValid: Bool {
        !currentPassword.isEmpty &&
        newPassword.count >= 8 &&
        newPassword.range(of: "[A-Z]", options: .regularExpression) != nil &&
        newPassword.range(of: "[a-z]", options: .regularExpression) != nil &&
        newPassword.range(of: "[0-9]", options: .regularExpression) != nil &&
        newPassword.range(of: "[!@#$%^&*(),.?\":{}|<>]", options: .regularExpression) != nil &&
        newPassword == confirmPassword
    }
    
    private func policyRow(title: String, isMet: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13))
                .foregroundColor(isMet ? Color.speakitPrimary : Color.speakitTextTertiary)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(isMet ? Color.speakitTextPrimary : Color.speakitTextSecondary)
        }
    }
    
    // MARK: - Actions
    private func requestPasswordOtp() {
        errorMessage = nil
        isLoading = true
        
        Task {
            do {
                struct RequestPasswordOtpPayload: Codable {
                    let currentPassword: String
                }
                let body = try JSONEncoder().encode(RequestPasswordOtpPayload(currentPassword: currentPassword))
                let _: EmptyResponse = try await HTTPClient.shared.request(.requestPasswordChangeOtp, method: "POST", body: body)
                
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
    
    private func submitPasswordChange() {
        errorMessage = nil
        isLoading = true
        let cleanOtp = otp.trimmingCharacters(in: .whitespacesAndNewlines).filter { $0.isNumber }
        
        Task {
            do {
                struct PasswordChangePayload: Codable {
                    let currentPassword: String
                    let newPassword: String
                    let otp: String
                }
                
                let body = try JSONEncoder().encode(PasswordChangePayload(
                    currentPassword: currentPassword,
                    newPassword: newPassword,
                    otp: cleanOtp
                ))
                let _: EmptyResponse = try await HTTPClient.shared.request(.changePassword, method: "POST", body: body)
                
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
