//
//  ProfileSettingsView.swift
//  SpeakIT
//
//  Profile and settings screen matching 07_Profile_Settings.svg.
//

import SwiftUI

struct ProfileSettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    @State private var showPaywall: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var isDeletingAccount: Bool = false
    @State private var deleteErrorMessage: String? = nil
    @State private var showSignOutAlert: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                Text("Profile")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(Color.speakitTextPrimary)
                    .padding(.top, 8)
                
                // User Card
                let user = appState.currentUser ?? User.sample
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.speakitPrimary)
                            .frame(width: 56, height: 56)
                        
                        Text(user.initials)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.fullName)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color.speakitTextPrimary)
                        
                        Text(user.email)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(Color.speakitTextSecondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
                
                // Menu Items
                VStack(spacing: 12) {
                    settingRow(
                        title: "Subscription",
                        subtitle: "\(user.planType.displayName) • Renews Oct 14",
                        icon: "creditcard.fill"
                    ) {
                        showPaywall = true
                    }
                    
                    settingRow(
                        title: "Usage & Quota",
                        subtitle: "\(user.charactersUsed.formatted()) / \(user.characterLimit.formatted()) characters",
                        icon: "chart.bar.fill"
                    ) {
                        showPaywall = true
                    }
                    
                    settingRow(
                        title: "Settings",
                        subtitle: "Playback, haptics, preferences",
                        icon: "slider.horizontal.3"
                    ) {}
                    
                    settingRow(
                        title: "Help & Support",
                        subtitle: "Privacy • Terms • Contact",
                        icon: "questionmark.circle.fill"
                    ) {}
                }
                
                // Danger Zone Section
                Text("Danger Zone")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.speakitDestructive)
                    .padding(.top, 16)
                
                // Delete Account Button
                SpeakITButton(
                    title: "Delete Account",
                    style: .destructive,
                    isLoading: isDeletingAccount
                ) {
                    showDeleteConfirmation = true
                }
                .accessibilityIdentifier("profile.deleteAccount")
                
                if let deleteErrorMessage = deleteErrorMessage {
                    Text(deleteErrorMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.speakitDestructive)
                }
                
                // Sign Out Button
                SpeakITButton(
                    title: "Sign Out",
                    style: .outline
                ) {
                    showSignOutAlert = true
                }
                .accessibilityIdentifier("profile.signOut")
                .padding(.bottom, 32)
            }
            .padding(.horizontal, SpeakITSpacing.screenMargin)
        }
        .sheet(isPresented: $showPaywall) {
            SubscriptionPaywallView()
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                appState.logout()
            }
        } message: {
            Text("Are you sure you want to sign out of SpeakIT?")
        }
        .alert("Permanently Delete Account?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Forever", role: .destructive) {
                executeAccountDeletion()
            }
        } message: {
            Text("This action cannot be undone. All your audio generation history and quota will be permanently deleted.")
        }
    }
    
    // MARK: - Reusable Setting Row
    private func settingRow(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            UISelectionFeedbackGenerator().selectionChanged()
            action()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "F0F0F5"))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundColor(Color.speakitTextSecondary)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.speakitTextPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color.speakitTextSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.speakitTextTertiary)
            }
            .padding(.horizontal, 16)
            .frame(height: 67)
            .background(Color.speakitBackground)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(hex: "E1E1E6"), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Account Deletion Handler
    private func executeAccountDeletion() {
        isDeletingAccount = true
        deleteErrorMessage = nil
        
        Task {
            do {
                struct EmptyResponse: Codable {}
                let _: EmptyResponse = try await HTTPClient.shared.request(.deleteAccount, method: "DELETE")
                
                await MainActor.run {
                    self.isDeletingAccount = false
                    self.appState.logout()
                }
            } catch {
                await MainActor.run {
                    self.isDeletingAccount = false
                    // Real backend does not yet implement DELETE /api/v1/users/me (confirmed Phase A gap)
                    // Per requirements: Surface controlled unavailable state, do NOT fake deletion!
                    self.deleteErrorMessage = "Account deletion endpoint is currently unavailable on the backend. Please contact support@speakit.com."
                }
            }
        }
    }
}

#Preview {
    ProfileSettingsView()
        .environment(AppState.shared)
}
