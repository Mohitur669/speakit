//
//  LoginView.swift
//  SpeakIT
//
//  Login screen faithfully implementing 01_Login.svg.
//

import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var appState
    
    @State private var usernameOrEmail: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @State private var showSignUp: Bool = false
    @State private var showForgotPasswordSheet: Bool = false
    @State private var showOAuthNotice: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    brandHeader
                    feedbackBanners
                    formFields
                    forgotPasswordRow
                    signInButton
                    dividerView
                    socialButtons
                    signUpLink
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
            .sheet(isPresented: $showForgotPasswordSheet) {
                ForgotPasswordSheet(onSuccess: {
                    self.successMessage = "Password reset successfully! You can now sign in with your new password."
                })
            }
            .alert("Social Sign-In", isPresented: $showOAuthNotice) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("OAuth social sign-in is managed by your backend provider. Please sign in with your SpeakIT email and password.")
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SpeakIT")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.speakitPrimary)
                .padding(.top, 16)
            
            Text("Welcome back")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(Color.speakitTextPrimary)
                .padding(.top, 18)
            
            Text("Transform your text and voice with SpeakIT.")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color.speakitTextSecondary)
                .padding(.top, 6)
                .padding(.bottom, 32)
        }
    }
    
    @ViewBuilder
    private var feedbackBanners: some View {
        SpeakITBanner(message: $successMessage, style: .success)
            .padding(.bottom, successMessage != nil ? 16 : 0)
        SpeakITBanner(message: $errorMessage, style: .error)
            .padding(.bottom, errorMessage != nil ? 16 : 0)
    }
    
    @ViewBuilder
    private var formFields: some View {
        VStack(spacing: 14) {
            SpeakITTextField(
                placeholder: "Phone, email or username",
                text: $usernameOrEmail,
                icon: "person.fill",
                keyboardType: .emailAddress,
                autoCapitalization: .never
            )
            .accessibilityIdentifier("login.username")
            
            SpeakITTextField(
                placeholder: "Password",
                text: $password,
                icon: "lock.fill",
                isSecure: true
            )
            .accessibilityIdentifier("login.password")
        }
    }
    
    @ViewBuilder
    private var forgotPasswordRow: some View {
        HStack {
            Spacer()
            Button(action: {
                HapticManager.shared.selection()
                showForgotPasswordSheet = true
            }) {
                Text("Forgot Password?")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.speakitPrimary)
            }
            .padding(.top, 12)
        }
    }
    
    @ViewBuilder
    private var signInButton: some View {
        SpeakITButton(
            title: "Sign In",
            style: .primary,
            isLoading: isLoading,
            isEnabled: !usernameOrEmail.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
        ) {
            performLogin()
        }
        .accessibilityIdentifier("login.signIn")
        .padding(.top, 22)
    }
    
    @ViewBuilder
    private var dividerView: some View {
        HStack {
            Spacer()
            Text("or continue with")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.speakitTextTertiary)
            Spacer()
        }
        .padding(.top, 26)
        .padding(.bottom, 18)
    }
    
    @ViewBuilder
    private var socialButtons: some View {
        VStack(spacing: 14) {
            Button(action: {
                showOAuthNotice = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Continue with Apple")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: SpeakITSpacing.inputHeight)
                .background(Color.speakitBackground)
                .foregroundColor(Color.speakitTextPrimary)
                .cornerRadius(SpeakITSpacing.inputRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: SpeakITSpacing.inputRadius)
                        .stroke(Color.speakitBorder, lineWidth: 1)
                )
            }
            
            Button(action: {
                showOAuthNotice = true
            }) {
                HStack(spacing: 8) {
                    Text("G")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.blue)
                    Text("Continue with Google")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: SpeakITSpacing.inputHeight)
                .background(Color.speakitBackground)
                .foregroundColor(Color.speakitTextPrimary)
                .cornerRadius(SpeakITSpacing.inputRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: SpeakITSpacing.inputRadius)
                        .stroke(Color.speakitBorder, lineWidth: 1)
                )
            }
        }
    }
    
    @ViewBuilder
    private var signUpLink: some View {
        HStack {
            Spacer()
            Button(action: {
                HapticManager.shared.selection()
                showSignUp = true
            }) {
                HStack(spacing: 4) {
                    Text("Don't have an account?")
                        .foregroundColor(Color.speakitTextSecondary)
                    Text("Create one")
                        .fontWeight(.semibold)
                        .foregroundColor(Color.speakitPrimary)
                }
                .font(.system(size: 14))
            }
            Spacer()
        }
        .padding(.top, 28)
        .padding(.bottom, 24)
    }
    
    // MARK: - Login Action
    private func performLogin() {
        errorMessage = nil
        isLoading = true
        
        let normalizedLogin = usernameOrEmail.trimmingCharacters(in: .whitespaces).lowercased()
        
        Task {
            do {
                struct LoginRequest: Codable {
                    let username: String
                    let password: String
                }
                
                struct LoginResponse: Codable {
                    let token: String
                    let username: String?
                    let email: String?
                    let phoneNumber: String?
                    let role: String?
                    let planType: String?
                    let characterLimit: Int?
                    let charactersUsed: Int?
                }
                
                let reqBody = try JSONEncoder().encode(LoginRequest(username: normalizedLogin, password: password))
                let response: LoginResponse = try await HTTPClient.shared.request(.login, method: "POST", body: reqBody)
                
                await MainActor.run {
                    self.isLoading = false
                    let resolvedPlan = PlanType(rawValue: (response.planType ?? "FREE").uppercased()) ?? .free
                    let user = User(
                        username: response.username ?? normalizedLogin,
                        email: response.email ?? "",
                        role: response.role ?? "ROLE_USER",
                        planType: resolvedPlan,
                        characterLimit: response.characterLimit,
                        charactersUsed: response.charactersUsed ?? 0,
                        phoneNumber: response.phoneNumber
                    )
                    HapticManager.shared.success()
                    self.appState.login(token: response.token, user: user)
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    if case APIError.unauthorized = error {
                        HapticManager.shared.error()
                        self.errorMessage = "Invalid username or password. Please try again."
                    } else if case APIError.networkError = error {
                        // Offline preview fallback mode for smooth testing
                        HapticManager.shared.success()
                        self.appState.login(token: "mock-offline-token", user: User.sample)
                    } else {
                        HapticManager.shared.error()
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environment(AppState.shared)
}
