//
//  EmailVerificationSheet.swift
//  SpeakIT
//
//  Native Apple-style OTP verification sheet for email verification upon registration or unverified sign-in.
//

import SwiftUI
import Combine

struct EmailVerificationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    @State var email: String
    var onSuccess: (() -> Void)? = nil
    
    @State private var otp: String = ""
    @State private var isLoading: Bool = false
    @State private var isResending: Bool = false
    @State private var resendCooldown: Int = 60
    @State private var timerSubscription: AnyCancellable? = nil
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @FocusState private var isOtpFocused: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    otpInputSection
                    verifyButton
                    resendSection
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
                .padding(.top, 24)
                .padding(.bottom, 36)
            }
            .background(Color.speakitScreenBackground.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Verify Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.shared.selection()
                        dismiss()
                    }
                    .foregroundColor(Color.speakitTextSecondary)
                }
            }
            .speakITToast(successMessage: $successMessage, errorMessage: $errorMessage, bottomPadding: 20)
            .onAppear {
                startCooldownTimer()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isOtpFocused = true
                }
            }
            .onDisappear {
                stopCooldownTimer()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Header Section
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.speakitPrimary.opacity(0.12))
                    .frame(width: 72, height: 72)
                
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 32))
                    .foregroundColor(Color.speakitPrimary)
            }
            
            Text("Verify Your Account")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.speakitTextPrimary)
            
            Text("We've sent a 6-digit confirmation code to:")
                .font(.system(size: 14))
                .foregroundColor(Color.speakitTextSecondary)
                .multilineTextAlignment(.center)
            
            Text(email)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.speakitPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.speakitPrimary.opacity(0.08))
                .cornerRadius(12)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - OTP Input Section
    @ViewBuilder
    private var otpInputSection: some View {
        VStack(spacing: 8) {
            SpeakITTextField(
                placeholder: "Enter 6-digit OTP",
                text: $otp,
                icon: "lock.shield",
                keyboardType: .numberPad,
                textContentType: .oneTimeCode
            )
            .focused($isOtpFocused)
            .onChange(of: otp) { _, newValue in
                let digits = newValue.filter { $0.isNumber }
                let truncated = String(digits.prefix(6))
                if otp != truncated {
                    otp = truncated
                }
                if otp.count == 6 {
                    HapticManager.shared.selection()
                }
            }
            
            Text("Check your inbox or spam/junk folder for the code.")
                .font(.system(size: 12))
                .foregroundColor(Color.speakitTextTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Verify Button
    @ViewBuilder
    private var verifyButton: some View {
        SpeakITButton(
            title: "Verify & Continue",
            style: .primary,
            isLoading: isLoading,
            isEnabled: otp.count == 6
        ) {
            submitVerification()
        }
    }
    
    // MARK: - Resend Section
    @ViewBuilder
    private var resendSection: some View {
        HStack {
            Spacer()
            if resendCooldown > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text("Resend code in \(resendCooldown)s")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(Color.speakitTextTertiary)
            } else {
                Button(action: {
                    resendVerificationOtp()
                }) {
                    HStack(spacing: 6) {
                        if isResending {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text("Resend Code")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(Color.speakitPrimary)
                }
                .disabled(isResending)
            }
            Spacer()
        }
        .padding(.top, 4)
    }
    
    // MARK: - Actions
    private func submitVerification() {
        errorMessage = nil
        isLoading = true
        isOtpFocused = false
        
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanOtp = otp.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            do {
                struct VerifyEmailRequest: Codable {
                    let email: String
                    let otp: String
                }
                
                struct AuthResponse: Codable {
                    let token: String?
                    let username: String?
                    let fullName: String?
                    let email: String?
                    let phoneNumber: String?
                    let role: String?
                    let planType: String?
                    let characterLimit: Int?
                    let charactersUsed: Int?
                }
                
                let reqBody = try JSONEncoder().encode(VerifyEmailRequest(email: cleanEmail, otp: cleanOtp))
                let response: AuthResponse = try await HTTPClient.shared.request(.verifyEmail, method: "POST", body: reqBody)
                
                await MainActor.run {
                    self.isLoading = false
                    HapticManager.shared.success()
                    
                    if let token = response.token {
                        let resolvedPlan = PlanType(rawValue: (response.planType ?? "FREE").uppercased()) ?? .free
                        let user = User(
                            username: response.username ?? cleanEmail,
                            email: response.email ?? cleanEmail,
                            fullName: response.fullName,
                            role: response.role ?? "ROLE_USER",
                            planType: resolvedPlan,
                            characterLimit: response.characterLimit,
                            charactersUsed: response.charactersUsed ?? 0,
                            phoneNumber: response.phoneNumber,
                            emailVerified: true
                        )
                        self.dismiss()
                        self.onSuccess?()
                        self.appState.login(token: token, user: user)
                    } else {
                        self.dismiss()
                        self.onSuccess?()
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    HapticManager.shared.error()
                    self.errorMessage = error.userFriendlyMessage
                }
            }
        }
    }
    
    private func resendVerificationOtp() {
        errorMessage = nil
        isResending = true
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        Task {
            do {
                struct ResendOtpRequest: Codable {
                    let email: String
                }
                
                let reqBody = try JSONEncoder().encode(ResendOtpRequest(email: cleanEmail))
                let _: EmptyResponse = try await HTTPClient.shared.request(.resendSignupOtp, method: "POST", body: reqBody)
                
                await MainActor.run {
                    self.isResending = false
                    self.resendCooldown = 60
                    self.startCooldownTimer()
                    HapticManager.shared.success()
                    self.successMessage = "A fresh verification code was sent to \(cleanEmail)."
                }
            } catch {
                await MainActor.run {
                    self.isResending = false
                    HapticManager.shared.error()
                    self.errorMessage = error.userFriendlyMessage
                }
            }
        }
    }
    
    private func startCooldownTimer() {
        stopCooldownTimer()
        timerSubscription = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if self.resendCooldown > 0 {
                    self.resendCooldown -= 1
                } else {
                    self.stopCooldownTimer()
                }
            }
    }
    
    private func stopCooldownTimer() {
        timerSubscription?.cancel()
        timerSubscription = nil
    }
}
