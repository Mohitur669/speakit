//
//  PasswordPolicySheet.swift
//  SpeakIT
//
//  Information sheet describing SpeakIT password standards and 2FA policy.
//

import SwiftUI

struct PasswordPolicySheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SpeakIT Password Standards")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color.speakitTextPrimary)
                        
                        Text("To protect your voice synthesis generations, cloned voices, and account privacy, SpeakIT enforces industry-standard password complexity.")
                            .font(.system(size: 13))
                            .foregroundColor(Color.speakitTextSecondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 14) {
                        requirementCard(
                            title: "Minimum Length",
                            description: "Passwords must be at least 8 characters long (up to 128 characters).",
                            icon: "textformat.123"
                        )
                        requirementCard(
                            title: "Character Diversity",
                            description: "Must contain uppercase letters (A-Z), lowercase letters (a-z), and digits (0-9).",
                            icon: "character.book.closed.fill"
                        )
                        requirementCard(
                            title: "Special Characters",
                            description: "Must include at least one symbol such as !@#$%^&*()_+-=[]{};:,.",
                            icon: "asterisk.circle.fill"
                        )
                        requirementCard(
                            title: "Two-Factor Verification",
                            description: "All profile and password modifications require email OTP authorization to prevent account takeover.",
                            icon: "shield.checkered"
                        )
                    }
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
                .padding(.top, 16)
            }
            .navigationTitle("Security Guidelines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func requirementCard(title: String, description: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.speakitPrimary.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color.speakitPrimary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.speakitTextPrimary)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(Color.speakitTextSecondary)
            }
            
            Spacer()
        }
        .padding(14)
        .background(Color.speakitBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "E6E6EB"), lineWidth: 1)
        )
    }
}
