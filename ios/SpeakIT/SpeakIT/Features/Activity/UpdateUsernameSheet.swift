//
//  UpdateUsernameSheet.swift
//  SpeakIT
//
//  Dedicated sheet for updating user's unique username handle.
//

import SwiftUI

struct UpdateUsernameSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    var onSuccess: () -> Void
    
    @State private var username: String
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    init(initialUsername: String = "", onSuccess: @escaping () -> Void) {
        self._username = State(initialValue: initialUsername)
        self.onSuccess = onSuccess
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Username")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color.speakitTextPrimary)
                        Text("Your username is your unique identifier across the platform.")
                            .font(.system(size: 13))
                            .foregroundColor(Color.speakitTextSecondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Username *")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.speakitTextSecondary)
                        
                        SpeakITTextField(
                            placeholder: "Enter username",
                            text: $username,
                            icon: "at",
                            autoCapitalization: .never
                        )
                    }
                    
                    SpeakITButton(
                        title: "Save Username",
                        style: .primary,
                        isLoading: isLoading,
                        isEnabled: !username.trimmingCharacters(in: .whitespaces).isEmpty
                    ) {
                        saveUsername()
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .background(Color.speakitScreenBackground)
            .navigationTitle("Update Username")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .speakITToast(message: $errorMessage, style: .error, bottomPadding: 20)
        }
        .presentationBackground(Color.speakitScreenBackground)
    }
    
    private func saveUsername() {
        errorMessage = nil
        isLoading = true
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        Task {
            do {
                struct UpdateUsernamePayload: Codable {
                    let username: String
                }
                let body = try JSONEncoder().encode(UpdateUsernamePayload(username: cleanUsername))
                let updatedUser: User = try await HTTPClient.shared.request(.updateUsername, method: "PUT", body: body)
                
                await MainActor.run {
                    self.isLoading = false
                    HapticManager.shared.success()
                    self.appState.currentUser = updatedUser
                    self.dismiss()
                    self.onSuccess()
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
}
