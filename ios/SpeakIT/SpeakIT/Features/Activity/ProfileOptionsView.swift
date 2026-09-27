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
    @State private var sheetDetent: PresentationDetent = .medium
    @State private var successMessage: String? = nil
    @State private var errorMessage: String? = nil
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Avatar Header Section
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        SpeakITAvatarView(
                            user: appState.currentUser,
                            size: 88,
                            isEditable: true,
                            onAvatarUpdated: { _ in
                                successMessage = "Profile photo updated successfully!"
                                errorMessage = nil
                            },
                            onAvatarDeleted: {
                                successMessage = "Profile photo removed."
                                errorMessage = nil
                            },
                            onError: { err in
                                errorMessage = err
                                successMessage = nil
                            }
                        )
                        
                        Text("Tap photo to change")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.speakitTextSecondary)
                    }
                    Spacer()
                }
                .padding(.top, 16)
                .padding(.bottom, 8)
                
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
                .background(Color.speakitCardSurface)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.speakitBorder, lineWidth: 1)
                )
            }
            .padding(.horizontal, SpeakITSpacing.screenMargin)
            .padding(.bottom, 36)
        }
        .background(Color.speakitScreenBackground.ignoresSafeArea())
        .navigationTitle("Personal Information")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(
            get: { activeSheet != nil },
            set: { isPresented in
                if !isPresented {
                    activeSheet = nil
                    sheetDetent = .medium
                }
            }
        )) {
            if let sheet = activeSheet {
                sheetDestination(for: sheet)
                    .presentationDetents([.medium], selection: $sheetDetent)
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color.speakitScreenBackground)
            }
        }
        .speakITToast(successMessage: $successMessage, errorMessage: $errorMessage, bottomPadding: 16)
    }
    
    @ViewBuilder
    private func sheetDestination(for sheet: ActiveProfileSheet) -> some View {
        switch sheet {
        case .fullName:
            UpdateFullNameSheet(
                initialName: appState.currentUser?.fullName ?? "",
                onSuccess: {
                    successMessage = "Full name updated successfully!"
                    errorMessage = nil
                }
            )
        case .username:
            UpdateUsernameSheet(
                initialUsername: appState.currentUser?.username ?? "",
                onSuccess: {
                    successMessage = "Username updated successfully!"
                    errorMessage = nil
                }
            )
        case .email:
            UpdateEmailSheet(onSuccess: {
                successMessage = "Email updated successfully!"
                errorMessage = nil
            })
        case .phone:
            UpdatePhoneSheet(
                initialPhone: appState.currentUser?.phoneNumber ?? "",
                onSuccess: {
                    successMessage = "Phone number updated successfully!"
                    errorMessage = nil
                }
            )
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
            guard activeSheet == nil else { return }
            HapticManager.shared.selection()
            sheetDetent = .medium
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var menuDivider: some View {
        Rectangle()
            .fill(Color.speakitDivider)
            .frame(height: 0.5)
            .padding(.leading, 50)
    }
}
