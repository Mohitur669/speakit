//
//  EditProfileSheet.swift
//  SpeakIT
//
//  Sheet for updating user profile attributes with password pre-verification and OTP validation.
//

import SwiftUI
import Combine

struct EditProfileSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    var onSuccess: () -> Void
    
    @State private var fullName: String = ""
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var phoneNumber: String = ""
    @State private var currentPassword: String = ""
    @State private var otp: String = ""
    
    @State private var step: Int = 1 // 1: Edit & Password, 2: OTP Entry
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
                        step1EditAndVerifyPasswordView
                    } else {
                        step2OtpVerificationView
                    }
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .navigationTitle(step == 1 ? "Edit Profile" : "Verify Changes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let u = appState.currentUser {
                    self.fullName = u.fullName
                    self.username = u.username
                    self.email = u.email
                    self.phoneNumber = u.phoneNumber ?? ""
                }
            }
            .onReceive(timer) { _ in
                if cooldownSeconds > 0 {
                    cooldownSeconds -= 1
                }
            }
        }
    }
    
    // MARK: - Step 1: Form & Password Verification
    @ViewBuilder
    private var step1EditAndVerifyPasswordView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Full Name")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.speakitTextSecondary)
                SpeakITTextField(placeholder: "Full Name", text: $fullName, icon: "person.crop.circle")
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Username")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.speakitTextSecondary)
                SpeakITTextField(placeholder: "Username", text: $username, icon: "at", autoCapitalization: .never)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Email Address")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.speakitTextSecondary)
                SpeakITTextField(placeholder: "Email Address", text: $email, icon: "envelope.fill", keyboardType: .emailAddress, autoCapitalization: .never)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Phone Number (Optional)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.speakitTextSecondary)
                SpeakITTextField(placeholder: "Phone Number", text: $phoneNumber, icon: "phone", keyboardType: .phonePad)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Confirm With Current Password")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.speakitTextPrimary)
                    Text("*")
                        .foregroundColor(Color.speakitDestructive)
                }
                
                Text("Your password is required to verify your identity before an OTP is sent.")
                    .font(.system(size: 11))
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
            .padding(.top, 4)
            
            SpeakITButton(
                title: "Request Verification Code",
                style: .primary,
                isLoading: isLoading,
                isEnabled: isFormValid
            ) {
                requestUpdateOtpWithPassword()
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Step 2: OTP Verification
    @ViewBuilder
    private var step2OtpVerificationView: some View {
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
                    Text("Verification Required")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color.speakitTextPrimary)
                    Text("A 6-digit OTP code was sent to your registered email.")
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
                    requestUpdateOtpWithPassword()
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
                title: "Confirm & Save Changes",
                style: .primary,
                isLoading: isLoading,
                isEnabled: otp.trimmingCharacters(in: .whitespaces).count >= 6
            ) {
                submitProfileUpdate()
            }
            .padding(.top, 8)
        }
    }
    
    private var isFormValid: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !currentPassword.isEmpty
    }
    
    // MARK: - Actions
    private func requestUpdateOtpWithPassword() {
        errorMessage = nil
        isLoading = true
        
        Task {
            do {
                struct RequestUpdatePayload: Codable {
                    let currentPassword: String
                }
                let body = try JSONEncoder().encode(RequestUpdatePayload(currentPassword: currentPassword))
                let _: EmptyResponse = try await HTTPClient.shared.request(.requestProfileUpdate, method: "POST", body: body)
                
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
    
    private func submitProfileUpdate() {
        errorMessage = nil
        isLoading = true
        
        let cleanOtp = otp.trimmingCharacters(in: .whitespacesAndNewlines).filter { $0.isNumber }
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanFullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            do {
                struct ProfileUpdatePayload: Codable {
                    let fullName: String
                    let username: String
                    let email: String
                    let phoneNumber: String?
                    let currentPassword: String
                    let otp: String
                }
                
                let body = try JSONEncoder().encode(ProfileUpdatePayload(
                    fullName: cleanFullName,
                    username: cleanUsername,
                    email: cleanEmail,
                    phoneNumber: cleanPhone.isEmpty ? nil : cleanPhone,
                    currentPassword: currentPassword,
                    otp: cleanOtp
                ))
                
                let updatedUser: User = try await HTTPClient.shared.request(.updateProfile, method: "PUT", body: body)
                
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
