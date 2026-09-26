//
//  UpdatePhoneSheet.swift
//  SpeakIT
//
//  Dedicated sheet for updating or removing user's optional phone number.
//

import SwiftUI

struct UpdatePhoneSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    var onSuccess: () -> Void
    
    @State private var phoneNumber: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Phone Number (Optional)")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color.speakitTextPrimary)
                        Text("Add or update your phone number for identification and easy login. You can leave it blank to remove it.")
                            .font(.system(size: 13))
                            .foregroundColor(Color.speakitTextSecondary)
                    }
                    
                    SpeakITBanner(message: $errorMessage, style: .error)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Phone Number")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.speakitTextSecondary)
                        
                        SpeakITTextField(
                            placeholder: "+91 9876543210",
                            text: $phoneNumber,
                            icon: "phone",
                            keyboardType: .phonePad
                        )
                    }
                    
                    VStack(spacing: 12) {
                        SpeakITButton(
                            title: "Save Phone Number",
                            style: .primary,
                            isLoading: isLoading,
                            isEnabled: hasChanges
                        ) {
                            savePhoneNumber()
                        }
                        
                        if let currentPhone = appState.currentUser?.phoneNumber, !currentPhone.isEmpty {
                            Button(action: {
                                removePhoneNumber()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 13))
                                    Text("Remove Phone Number")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundColor(Color.speakitDestructive)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoading)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
                .padding(.top, 16)
            }
            .navigationTitle("Phone Number")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let user = appState.currentUser {
                    self.phoneNumber = user.phoneNumber ?? ""
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private var hasChanges: Bool {
        let current = appState.currentUser?.phoneNumber ?? ""
        return phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines) != current
    }
    
    private func savePhoneNumber() {
        errorMessage = nil
        isLoading = true
        let cleanPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            do {
                struct UpdatePhonePayload: Codable {
                    let phoneNumber: String?
                }
                let body = try JSONEncoder().encode(UpdatePhonePayload(phoneNumber: cleanPhone.isEmpty ? nil : cleanPhone))
                let updatedUser: User = try await HTTPClient.shared.request(.updatePhoneNumber, method: "PUT", body: body)
                
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
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func removePhoneNumber() {
        phoneNumber = ""
        savePhoneNumber()
    }
}
