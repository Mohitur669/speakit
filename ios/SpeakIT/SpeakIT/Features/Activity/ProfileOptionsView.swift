//
//  ProfileOptionsView.swift
//  SpeakIT
//
//  Sub-menu view under Account Settings dedicated to Profile attribute management:
//  Full Name, Username, and Email Address.
//

import SwiftUI

struct ProfileOptionsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    enum ActiveProfileSheet: Identifiable {
        case fullName
        case username
        case email
        case phone
        
        var id: String {
            switch self {
            case .fullName: return "fullName"
            case .username: return "username"
            case .email: return "email"
            case .phone: return "phone"
            }
        }
    }
    
    @State private var activeSheet: ActiveProfileSheet? = nil
    @State private var successMessage: String? = nil
    @State private var errorMessage: String? = nil
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Section description
                VStack(alignment: .leading, spacing: 4) {
                    Text("Personal Details")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.speakitTextPrimary)
                    
                    Text("Manage your display name, unique handle, and primary email address.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.speakitTextSecondary)
                }
                .padding(.top, 8)
                
                // Feedback Banners
                SpeakITBanner(message: $successMessage, style: .success)
                SpeakITBanner(message: $errorMessage, style: .error)
                
                // Profile Options Card
                VStack(spacing: 0) {
                    menuItem(
                        title: "Full Name",
                        subtitle: resolvedFullName,
                        icon: "person.crop.circle",
                        action: { activeSheet = .fullName }
                    )
                    
                    menuDivider
                    
                    menuItem(
                        title: "Username",
                        subtitle: "@\(appState.currentUser?.username ?? "username")",
                        icon: "at",
                        action: { activeSheet = .username }
                    )
                    
                    menuDivider
                    
                    menuItem(
                        title: "Email Address",
                        subtitle: appState.currentUser?.email.isEmpty == false ? appState.currentUser!.email : "Set email address",
                        icon: "envelope.fill",
                        action: { activeSheet = .email }
                    )
                    
                    menuDivider
                    
                    menuItem(
                        title: "Phone Number",
                        subtitle: (appState.currentUser?.phoneNumber?.isEmpty == false) ? appState.currentUser!.phoneNumber! : "Not set (Optional)",
                        icon: "phone.fill",
                        action: { activeSheet = .phone }
                    )
                }
                .background(Color.speakitBackground)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "E6E6EB"), lineWidth: 1)
                )
            }
            .padding(.horizontal, SpeakITSpacing.screenMargin)
            .padding(.bottom, 36)
        }
        .navigationTitle("Profile Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .fullName:
                UpdateFullNameSheet(onSuccess: {
                    successMessage = "Full name updated successfully!"
                    errorMessage = nil
                })
            case .username:
                UpdateUsernameSheet(onSuccess: {
                    successMessage = "Username updated successfully!"
                    errorMessage = nil
                })
            case .email:
                UpdateEmailSheet(onSuccess: {
                    successMessage = "Email updated successfully!"
                    errorMessage = nil
                })
            case .phone:
                UpdatePhoneSheet(onSuccess: {
                    successMessage = "Phone number updated successfully!"
                    errorMessage = nil
                })
            }
        }
    }
    
    private var resolvedFullName: String {
        if let name = appState.currentUser?.fullName, !name.trimmingCharacters(in: .whitespaces).isEmpty {
            return name
        }
        return "Set your display name"
    }
    
    @ViewBuilder
    private func menuItem(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.selection()
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
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.speakitTextTertiary)
            }
            .padding(14)
        }
        .buttonStyle(.plain)
    }
    
    private var menuDivider: some View {
        Divider()
            .padding(.leading, 50)
    }
}
