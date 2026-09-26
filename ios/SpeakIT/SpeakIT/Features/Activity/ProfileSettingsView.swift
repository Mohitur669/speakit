//
//  ProfileSettingsView.swift
//  SpeakIT
//
//  Comprehensive Profile & Settings screen featuring a clean, modular menu architecture.
//  Account Settings organizes Profile Settings (Full Name, Username, Email) and Change Password.
//

import SwiftUI
import Combine

struct ProfileSettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    enum ActiveSheet: Identifiable {
        case password
        case paywall
        case passwordPolicy
        case terms
        case privacy
        case about
        case contact
        case blog
        
        var id: String {
            switch self {
            case .password: return "password"
            case .paywall: return "paywall"
            case .passwordPolicy: return "passwordPolicy"
            case .terms: return "terms"
            case .privacy: return "privacy"
            case .about: return "about"
            case .contact: return "contact"
            case .blog: return "blog"
            }
        }
    }
    
    // Sub-screens & Sheets
    @State private var activeSheet: ActiveSheet? = nil
    @State private var showSignOutAlert: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    
    // Status & Feedback
    @State private var successMessage: String? = nil
    @State private var errorMessage: String? = nil
    @State private var isDeletingAccount: Bool = false
    
    // Preferences (Stored locally)
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("autoPlayPreview") private var autoPlayPreview: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Title
                Text("Profile")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(Color.speakitTextPrimary)
                    .padding(.top, 8)
                
                feedbackBanners
                
                // 1. User Identity Header Card
                userHeaderCard
                
                // 2. Subscription & Quota Card
                quotaCard
                
                // 3. Modular Menu Sections
                accountSettingsSection
                preferencesSection
                securityAndLegalSection
                dangerZoneSection
            }
            .padding(.horizontal, SpeakITSpacing.screenMargin)
            .padding(.bottom, 36)
        }
        .refreshable {
            await appState.loadCurrentUser()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .password:
                ChangePasswordSheet(onSuccess: {
                    successMessage = "Password changed successfully!"
                    errorMessage = nil
                })
            case .paywall:
                SubscriptionPaywallView()
            case .passwordPolicy:
                PasswordPolicySheet()
            case .terms:
                TermsOfServiceSheet()
            case .privacy:
                PrivacyPolicySheet()
            case .about:
                AboutSpeakITSheet()
            case .contact:
                ContactSupportSheet()
            case .blog:
                BlogUpdatesSheet()
            }
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
            Text("This action cannot be undone. All your synthesis history and usage quotas will be permanently deleted.")
        }
    }
    
    // MARK: - Feedback Banners
    @ViewBuilder
    private var feedbackBanners: some View {
        SpeakITBanner(message: $successMessage, style: .success)
        SpeakITBanner(message: $errorMessage, style: .error)
    }
    
    // MARK: - 1. User Header Card
    @ViewBuilder
    private var userHeaderCard: some View {
        let user = appState.currentUser ?? User.sample
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.speakitPrimary)
                    .frame(width: 54, height: 54)
                
                Text(user.initials)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 54, height: 54)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(user.fullName.isEmpty ? user.username.capitalized : user.fullName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color.speakitTextPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.8)
                    
                    if user.emailVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.speakitPrimary)
                    }
                }
                
                Text("@\(user.username)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.speakitTextSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Text(user.email)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color.speakitTextTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.speakitBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "E6E6EB"), lineWidth: 1)
        )
    }
    
    // MARK: - 2. Quota & Usage Card
    @ViewBuilder
    private var quotaCard: some View {
        let user = appState.currentUser ?? User.sample
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text("Plan & Quota")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.speakitTextPrimary)
                
                Spacer()
                
                SpeakITQuotaBadge(text: "\(user.planType.displayName) Plan")
            }
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(hex: "E6E6EB"))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.speakitPrimary)
                        .frame(width: geo.size.width * CGFloat(user.usagePercentage), height: 8)
                }
            }
            .frame(height: 8)
            
            HStack {
                Text("\(user.charactersUsed.formatted()) / \(user.characterLimit.formatted()) chars")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.speakitTextPrimary)
                
                Spacer()
                
                Text("\(user.remainingCharacters.formatted()) remaining")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color.speakitTextSecondary)
            }
        }
        .padding(16)
        .background(Color.speakitBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "E6E6EB"), lineWidth: 1)
        )
    }
    
    // MARK: - 3. Account Settings Section (Profile Settings, Password & Plan)
    @ViewBuilder
    private var accountSettingsSection: some View {
        let user = appState.currentUser ?? User.sample
        VStack(alignment: .leading, spacing: 10) {
            Text("ACCOUNT SETTINGS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.speakitTextTertiary)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                NavigationLink(destination: ProfileOptionsView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 15))
                            .foregroundColor(Color.speakitPrimary)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Profile Settings")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.speakitTextPrimary)
                            Text("Full name, username & email")
                                .font(.system(size: 11))
                                .foregroundColor(Color.speakitTextSecondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.speakitTextTertiary)
                    }
                    .padding(14)
                }
                .buttonStyle(.plain)
                
                menuDivider
                
                menuItem(
                    title: "Change Password",
                    subtitle: "Protected with 2-Factor OTP verification",
                    icon: "lock.shield.fill",
                    action: { activeSheet = .password }
                )
                
                menuDivider
                
                menuItem(
                    title: "Change Plan",
                    subtitle: "Upgrade or modify your subscription tier",
                    icon: "sparkles",
                    action: { activeSheet = .paywall }
                )
            }
            .background(Color.speakitBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "E6E6EB"), lineWidth: 1)
            )
        }
    }
    
    // MARK: - 4. Preferences Section
    @ViewBuilder
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PREFERENCES")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.speakitTextTertiary)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                Toggle(isOn: $hapticsEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .foregroundColor(Color.speakitPrimary)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Haptic Feedback")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.speakitTextPrimary)
                            Text("Vibrate on button taps and synthesis actions")
                                .font(.system(size: 11))
                                .foregroundColor(Color.speakitTextSecondary)
                        }
                    }
                }
                .padding(14)
                
                menuDivider
                
                Toggle(isOn: $autoPlayPreview) {
                    HStack(spacing: 12) {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(Color.speakitPrimary)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-Play Generations")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.speakitTextPrimary)
                            Text("Play synthesized audio automatically on completion")
                                .font(.system(size: 11))
                                .foregroundColor(Color.speakitTextSecondary)
                        }
                    }
                }
                .padding(14)
            }
            .background(Color.speakitBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "E6E6EB"), lineWidth: 1)
            )
        }
    }
    
    // MARK: - 5. Legal & Company Section
    @ViewBuilder
    private var securityAndLegalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LEGAL & COMPANY")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.speakitTextTertiary)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                menuItem(
                    title: "Password Security Policy",
                    subtitle: "View complexity rules and safety standards",
                    icon: "shield.lefthalf.filled",
                    action: { activeSheet = .passwordPolicy }
                )
                
                menuDivider
                
                menuItem(
                    title: "Terms of Service",
                    subtitle: "Usage rights, licensing & account terms",
                    icon: "doc.text.fill",
                    action: { activeSheet = .terms }
                )
                
                menuDivider
                
                menuItem(
                    title: "Privacy Policy",
                    subtitle: "Data encryption, audio retention & cookies",
                    icon: "lock.shield.fill",
                    action: { activeSheet = .privacy }
                )
                
                menuDivider
                
                menuItem(
                    title: "About SpeakIT",
                    subtitle: "Platform vision, technology & mission",
                    icon: "info.circle.fill",
                    action: { activeSheet = .about }
                )
                
                menuDivider
                
                menuItem(
                    title: "Contact Support",
                    subtitle: "Customer service, inquiries & bug reports",
                    icon: "envelope.fill",
                    action: { activeSheet = .contact }
                )
                
                menuDivider
                
                menuItem(
                    title: "Blog & Updates",
                    subtitle: "Release notes, voice tutorials & guides",
                    icon: "newspaper.fill",
                    action: { activeSheet = .blog }
                )
            }
            .background(Color.speakitBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "E6E6EB"), lineWidth: 1)
            )
        }
    }
    
    // MARK: - 6. Danger Zone Section
    @ViewBuilder
    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACCOUNT SESSIONS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.speakitTextTertiary)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                Button(action: {
                    showSignOutAlert = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 15))
                            .foregroundColor(Color.speakitDestructive)
                            .frame(width: 24)
                        
                        Text("Sign Out")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.speakitDestructive)
                        
                        Spacer()
                    }
                    .padding(14)
                }
                
                menuDivider
                
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    HStack(spacing: 12) {
                        if isDeletingAccount {
                            ProgressView()
                                .frame(width: 24)
                        } else {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 15))
                                .foregroundColor(Color.speakitDestructive)
                                .frame(width: 24)
                        }
                        
                        Text("Delete Account Permanently")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.speakitDestructive)
                        
                        Spacer()
                    }
                    .padding(14)
                }
                .disabled(isDeletingAccount)
            }
            .background(Color.speakitBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "E6E6EB"), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Helper Views & Actions
    @ViewBuilder
    private func menuItem(
        title: String,
        subtitle: String,
        icon: String,
        badgeText: String? = nil,
        trailingIcon: String = "chevron.right",
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            if hapticsEnabled {
                UISelectionFeedbackGenerator().selectionChanged()
            }
            action()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(Color.speakitPrimary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.speakitTextPrimary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(Color.speakitTextSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if let badgeText = badgeText {
                    SpeakITQuotaBadge(text: badgeText)
                }
                
                Image(systemName: trailingIcon)
                    .font(.system(size: trailingIcon == "chevron.right" ? 12 : 11, weight: .semibold))
                    .foregroundColor(Color.speakitTextTertiary)
            }
            .padding(14)
        }
        .buttonStyle(.plain)
    }
    
    private func openWebLink(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        openURL(url)
    }
    
    private var menuDivider: some View {
        Divider()
            .padding(.leading, 50)
    }
    
    private func executeAccountDeletion() {
        isDeletingAccount = true
        errorMessage = nil
        
        Task {
            do {
                let _: EmptyResponse = try await HTTPClient.shared.request(.deleteAccount, method: "DELETE")
                await MainActor.run {
                    self.isDeletingAccount = false
                    self.appState.logout()
                }
            } catch {
                await MainActor.run {
                    self.isDeletingAccount = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    ProfileSettingsView()
        .environment(AppState.shared)
}
