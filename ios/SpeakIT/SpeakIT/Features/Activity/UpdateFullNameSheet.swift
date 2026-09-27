//
//  UpdateFullNameSheet.swift
//  SpeakIT
//
//  Dedicated sheet for updating user's full display name.
//

import SwiftUI

struct UpdateFullNameSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    var onSuccess: () -> Void
    
    @State private var fullName: String
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    init(initialName: String = "", onSuccess: @escaping () -> Void) {
        self._fullName = State(initialValue: initialName)
        self.onSuccess = onSuccess
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Display Name")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color.speakitTextPrimary)
                        Text("This name will be shown on your profile and synthesis history.")
                            .font(.system(size: 13))
                            .foregroundColor(Color.speakitTextSecondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Full Name *")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.speakitTextSecondary)
                        
                        SpeakITTextField(
                            placeholder: "Enter full name",
                            text: $fullName,
                            icon: "person.crop.circle"
                        )
                    }
                    
                    SpeakITButton(
                        title: "Save Name",
                        style: .primary,
                        isLoading: isLoading,
                        isEnabled: !fullName.trimmingCharacters(in: .whitespaces).isEmpty
                    ) {
                        saveFullName()
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
            .navigationTitle("Update Full Name")
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
    
    private func saveFullName() {
        errorMessage = nil
        isLoading = true
        let cleanName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            do {
                struct UpdateNamePayload: Codable {
                    let fullName: String
                }
                let body = try JSONEncoder().encode(UpdateNamePayload(fullName: cleanName))
                let updatedUser: User = try await HTTPClient.shared.request(.updateFullName, method: "PUT", body: body)
                
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
