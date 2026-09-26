//
//  SignUpView.swift
//  SpeakIT
//
//  Registration screen supporting native user creation.
//

import SwiftUI

struct SignUpView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    @State private var fullName: String = ""
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Create Account")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(Color.speakitTextPrimary)
                    .padding(.top, 16)
                
                Text("Start converting text to lifelike speech.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color.speakitTextSecondary)
                    .padding(.top, 6)
                    .padding(.bottom, 24)
                
                SpeakITBanner(message: $errorMessage, style: .error)
                    .padding(.bottom, errorMessage != nil ? 16 : 0)
                
                VStack(spacing: 14) {
                    SpeakITTextField(placeholder: "Full Name", text: $fullName, icon: "person.crop.circle")
                    SpeakITTextField(placeholder: "Username", text: $username, icon: "at", autoCapitalization: .never)
                    SpeakITTextField(placeholder: "Email Address", text: $email, icon: "envelope.fill", keyboardType: .emailAddress, autoCapitalization: .never)
                    SpeakITTextField(placeholder: "Password", text: $password, icon: "lock.fill", isSecure: true)
                    SpeakITTextField(placeholder: "Confirm Password", text: $confirmPassword, icon: "lock.shield.fill", isSecure: true)
                }
                
                SpeakITButton(
                    title: "Create Account",
                    style: .primary,
                    isLoading: isLoading,
                    isEnabled: isFormValid
                ) {
                    performSignUp()
                }
                .padding(.top, 24)
                
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .foregroundColor(Color.speakitTextSecondary)
                            Text("Sign In")
                                .fontWeight(.semibold)
                                .foregroundColor(Color.speakitPrimary)
                        }
                        .font(.system(size: 14))
                    }
                    Spacer()
                }
                .padding(.top, 24)
            }
            .padding(.horizontal, SpeakITSpacing.screenMargin)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var isFormValid: Bool {
        !fullName.isEmpty && !username.isEmpty && !email.isEmpty && password.count >= 8 && password == confirmPassword
    }
    
    private func performSignUp() {
        errorMessage = nil
        isLoading = true
        
        let normalizedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        let normalizedUsername = username.trimmingCharacters(in: .whitespaces).lowercased()
        
        Task {
            do {
                struct RegisterRequest: Codable {
                    let fullName: String?
                    let username: String
                    let email: String
                    let password: String
                }
                
                struct AuthResponse: Codable {
                    let token: String?
                    let username: String?
                    let fullName: String?
                    let email: String?
                    let role: String?
                    let planType: String?
                }
                
                let reqBody = try JSONEncoder().encode(RegisterRequest(
                    fullName: fullName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : fullName.trimmingCharacters(in: .whitespaces),
                    username: normalizedUsername,
                    email: normalizedEmail,
                    password: password
                ))
                
                let response: AuthResponse = try await HTTPClient.shared.request(.register, method: "POST", body: reqBody)
                
                await MainActor.run {
                    self.isLoading = false
                    if let token = response.token {
                        let resolvedPlan = PlanType(rawValue: (response.planType ?? "FREE").uppercased()) ?? .free
                        let user = User(
                            username: response.username ?? normalizedUsername,
                            email: response.email ?? normalizedEmail,
                            fullName: fullName.isEmpty ? nil : fullName,
                            role: response.role ?? "ROLE_USER",
                            planType: resolvedPlan
                        )
                        self.appState.login(token: token, user: user)
                    } else {
                        // User created in PENDING_VERIFICATION status
                        self.dismiss()
                    }
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
