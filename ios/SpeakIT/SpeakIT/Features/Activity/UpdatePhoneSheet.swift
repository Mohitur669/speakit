//
//  UpdatePhoneSheet.swift
//  SpeakIT
//
//  Dedicated sheet for updating or removing user's optional phone number.
//  Strictly allows up to 10 numeric digits only.
//

import SwiftUI

struct UpdatePhoneSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    var onSuccess: () -> Void
    
    @State private var phoneNumber: String
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    init(initialPhone: String = "", onSuccess: @escaping () -> Void) {
        let cleaned = Self.cleanDigits(initialPhone)
        self._phoneNumber = State(initialValue: cleaned)
        self.onSuccess = onSuccess
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Phone Number (Optional)")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color.speakitTextPrimary)
                        Text("Add or update your 10-digit mobile number for identification and easy login. Leave blank to remove.")
                            .font(.system(size: 13))
                            .foregroundColor(Color.speakitTextSecondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Phone Number")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.speakitTextSecondary)
                        
                        SpeakITTextField(
                            placeholder: "9876543210",
                            text: $phoneNumber,
                            icon: "phone",
                            keyboardType: .numberPad
                        )
                        
                        HStack {
                            Text(phoneHelperText)
                                .font(.system(size: 11))
                                .foregroundColor(isPhoneLengthValid ? Color.speakitTextTertiary : Color.speakitWarning)
                            Spacer()
                            if !phoneNumber.isEmpty {
                                Text("\(phoneNumber.count)/10")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(phoneNumber.count == 10 ? Color.speakitPrimary : Color.speakitTextTertiary)
                            }
                        }
                        .padding(.top, 2)
                    }
                    
                    VStack(spacing: 12) {
                        SpeakITButton(
                            title: "Save Phone Number",
                            style: .primary,
                            isLoading: isLoading,
                            isEnabled: hasChanges && isPhoneLengthValid
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
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .background(Color.speakitScreenBackground)
            .navigationTitle("Phone Number")
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
        .onChange(of: phoneNumber) { _, newValue in
            let filtered = newValue.filter { $0.isNumber }
            let truncated = String(filtered.prefix(10))
            if phoneNumber != truncated {
                phoneNumber = truncated
            }
        }
    }
    
    // MARK: - Helpers
    private static func cleanDigits(_ input: String) -> String {
        let digits = input.filter { $0.isNumber }
        if digits.count > 10 {
            return String(digits.suffix(10))
        }
        return String(digits.prefix(10))
    }
    
    private var isPhoneLengthValid: Bool {
        phoneNumber.isEmpty || phoneNumber.count == 10
    }
    
    private var phoneHelperText: String {
        if phoneNumber.isEmpty {
            return "Enter 10-digit mobile number"
        } else if phoneNumber.count < 10 {
            return "Requires 10 digits (\(10 - phoneNumber.count) more needed)"
        } else {
            return "Valid 10-digit number"
        }
    }
    
    private var hasChanges: Bool {
        let current = Self.cleanDigits(appState.currentUser?.phoneNumber ?? "")
        let clean = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean != current
    }
    
    private func savePhoneNumber() {
        errorMessage = nil
        let cleanPhone = phoneNumber.filter { $0.isNumber }
        
        if !cleanPhone.isEmpty && cleanPhone.count != 10 {
            errorMessage = "Please enter a valid 10-digit phone number"
            return
        }
        
        isLoading = true
        
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
                    self.errorMessage = error.userFriendlyMessage
                }
            }
        }
    }
    
    private func removePhoneNumber() {
        phoneNumber = ""
        savePhoneNumber()
    }
}
