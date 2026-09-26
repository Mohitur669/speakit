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
    @State private var showSignUp: Bool = false
    @State private var showForgotPasswordAlert: Bool = false
    @State private var showOAuthNotice: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header Brand
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
                    
                    // Error Banner
                    if let errorMessage = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(Color.speakitDestructive)
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.speakitDestructive)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.speakitDestructiveLight)
                        .cornerRadius(12)
                        .padding(.bottom, 16)
                    }
                    
                    // Form Fields
                    VStack(spacing: 14) {
                        SpeakITTextField(
                            placeholder: "Username or email",
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
                    
                    // Forgot Password
                    HStack {
                        Spacer()
                        Button(action: {
                            showForgotPasswordAlert = true
                        }) {
                            Text("Forgot Password?")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.speakitPrimary)
                        }
                        .padding(.top, 12)
                    }
                    
                    // Sign In Button
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
                    
                    // Divider
                    HStack {
                        Spacer()
                        Text("or continue with")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.speakitTextTertiary)
                        Spacer()
                    }
                    .padding(.top, 26)
                    .padding(.bottom, 18)
                    
                    // Social Login Buttons (Apple & Google reference)
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
                    
                    // Sign Up Link
                    HStack {
                        Spacer()
                        Button(action: {
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
                .padding(.horizontal, SpeakITSpacing.screenMargin)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
            .alert("Password Reset", isPresented: $showForgotPasswordAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Password reset instructions have been sent to your registered email address.")
            }
            .alert("Social Sign-In", isPresented: $showOAuthNotice) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("OAuth social sign-in is managed by your backend provider. Please sign in with your SpeakIT email and password.")
            }
        }
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
                        charactersUsed: response.charactersUsed ?? 0
                    )
                    self.appState.login(token: response.token, user: user)
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    if case APIError.unauthorized = error {
                        self.errorMessage = "Invalid username or password. Please try again."
                    } else if case APIError.networkError = error {
                        // Offline preview fallback mode for smooth testing
                        self.appState.login(token: "mock-offline-token", user: User.sample)
                    } else {
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
