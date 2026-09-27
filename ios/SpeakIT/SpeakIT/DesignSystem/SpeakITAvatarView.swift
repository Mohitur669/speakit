//
//  SpeakITAvatarView.swift
//  SpeakIT
//
//  Industry-standard profile avatar component featuring:
//  1. 3-Tier Fallback Hierarchy: Custom Photo -> Deterministic Initials Monogram -> SF Symbol
//  2. PhotosPicker (PhotosUI) for zero-permission privacy-first photo selection
//  3. Client-side square-crop, downsampling (512x512), and JPEG compression
//  4. Two-tier caching (Memory NSCache + Disk) with smooth fade-in
//  5. Interactive edit camera badge and Action Sheet (Choose from Library, Remove, Cancel)
//  6. Accessibility label support
//

import SwiftUI
import PhotosUI

struct SpeakITAvatarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    
    let user: User?
    var size: CGFloat = 54
    var isEditable: Bool = false
    var onAvatarUpdated: ((User) -> Void)? = nil
    var onAvatarDeleted: (() -> Void)? = nil
    var onError: ((String) -> Void)? = nil
    
    @State private var loadedImage: UIImage? = nil
    @State private var isProcessing: Bool = false
    @State private var showActionSheet: Bool = false
    @State private var showPhotosPicker: Bool = false
    @State private var selectedPickerItem: PhotosPickerItem? = nil
    @State private var imageToCrop: UIImage? = nil
    @State private var showCropSheet: Bool = false
    
    // Deterministic palette gradients for monograms
    private static let avatarGradients: [[Color]] = [
        [Color(red: 0.38, green: 0.38, blue: 0.98), Color(red: 0.58, green: 0.28, blue: 0.98)], // Indigo-Purple
        [Color(red: 0.12, green: 0.53, blue: 0.90), Color(red: 0.05, green: 0.73, blue: 0.82)], // Blue-Cyan
        [Color(red: 0.06, green: 0.72, blue: 0.51), Color(red: 0.10, green: 0.65, blue: 0.75)], // Emerald-Teal
        [Color(red: 0.95, green: 0.40, blue: 0.28), Color(red: 0.98, green: 0.60, blue: 0.25)], // Coral-Orange
        [Color(red: 0.85, green: 0.25, blue: 0.65), Color(red: 0.55, green: 0.25, blue: 0.85)], // Magenta-Violet
        [Color(red: 0.20, green: 0.65, blue: 0.85), Color(red: 0.35, green: 0.45, blue: 0.95)], // Sky-Navy
        [Color(red: 0.95, green: 0.32, blue: 0.48), Color(red: 0.98, green: 0.50, blue: 0.35)]  // Rose-Peach
    ]
    
    private var resolvedUser: User {
        user ?? appState.currentUser ?? User.sample
    }
    
    private var hasCustomPhoto: Bool {
        if let url = resolvedUser.avatarUrl, !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return false
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main Circular Avatar
            Group {
                if let image = loadedImage {
                    // Tier 1: Custom Photo
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else if !resolvedUser.initials.isEmpty && resolvedUser.initials != "U" {
                    // Tier 2: Deterministic Monogram Initials
                    initialsMonogramView
                } else {
                    // Tier 3: SF Symbol Fallback
                    sfSymbolFallbackView
                }
            }
            .frame(width: size, height: size)
            // Subtle 1pt border preventing bright/dark images from blending into background
            .overlay(
                Circle()
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08),
                        lineWidth: 1
                    )
            )
            // Progress spinner while uploading or removing
            .overlay {
                if isProcessing {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.45))
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(max(0.7, size / 70.0))
                    }
                    .clipShape(Circle())
                }
            }
            
            // Edit Badge (Camera Icon)
            if isEditable {
                cameraEditBadge
            }
        }
        .contentShape(Circle())
        .onTapGesture {
            if isEditable && !isProcessing {
                HapticManager.shared.impact(.light)
                showActionSheet = true
            }
        }
        .confirmationDialog("Profile Photo", isPresented: $showActionSheet, titleVisibility: .visible) {
            Button("Choose from Library") {
                showPhotosPicker = true
            }
            
            if hasCustomPhoto {
                Button("Remove Current Photo", role: .destructive) {
                    deleteAvatar()
                }
            }
            
            Button("Cancel", role: .cancel) {}
        }
        .tint(Color.speakitTextPrimary)
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $selectedPickerItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: selectedPickerItem) { _, newItem in
            if let item = newItem {
                Task {
                    if let rawData = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: rawData) {
                        await MainActor.run {
                            self.imageToCrop = image
                            self.showCropSheet = true
                            self.selectedPickerItem = nil
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCropSheet) {
            if let img = imageToCrop {
                AvatarCropView(sourceImage: img) { croppedData in
                    uploadCroppedAvatar(data: croppedData)
                }
            }
        }
        .task(id: resolvedUser.avatarUrl) {
            await loadAvatarImage()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(isEditable ? .isButton : .isImage)
    }
    
    // MARK: - Tier 2: Initials Monogram
    @ViewBuilder
    private var initialsMonogramView: some View {
        let gradient = deterministicGradient(for: resolvedUser.id, name: resolvedUser.username)
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(resolvedUser.initials)
                .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Tier 3: SF Symbol Fallback
    @ViewBuilder
    private var sfSymbolFallbackView: some View {
        ZStack {
            Circle()
                .fill(Color.speakitCard)
            
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.65, height: size * 0.65)
                .foregroundColor(Color.speakitTextSecondary.opacity(0.6))
        }
    }
    
    // MARK: - Camera Edit Badge
    @ViewBuilder
    private var cameraEditBadge: some View {
        let badgeSize = max(22, size * 0.32)
        Button {
            if !isProcessing {
                HapticManager.shared.impact(.light)
                showActionSheet = true
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.speakitPrimary)
                    .frame(width: badgeSize, height: badgeSize)
                
                Image(systemName: "camera.fill")
                    .font(.system(size: max(10, badgeSize * 0.45), weight: .semibold))
                    .foregroundColor(.white)
            }
            .overlay(
                Circle()
                    .stroke(Color.speakitScreenBackground, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .offset(x: size * 0.04, y: size * 0.04)
    }
    
    // MARK: - Image Loading (Memory -> Disk -> Network)
    private func loadAvatarImage() async {
        guard let urlString = resolvedUser.avatarUrl,
              !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            withAnimation(.easeInOut(duration: 0.15)) {
                self.loadedImage = nil
            }
            return
        }
        
        // Fast sync memory check
        if let memoryImg = AvatarCacheManager.shared.memoryImage(for: urlString) {
            self.loadedImage = memoryImg
            return
        }
        
        // Asynchronous disk or network fetch
        if let image = await AvatarCacheManager.shared.loadImage(from: urlString) {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.loadedImage = image
            }
        }
    }
    
    // MARK: - Upload Pipeline
    private func uploadCroppedAvatar(data: Data) {
        isProcessing = true
        
        Task {
            defer {
                Task { @MainActor in
                    isProcessing = false
                }
            }
            
            do {
                // 1. Upload multipart to backend (Cloudflare R2 / S3-compatible storage)
                let avatarResponse: AvatarResponse = try await HTTPClient.shared.uploadMultipart(
                    .uploadAvatar,
                    fileData: data,
                    fileName: "avatar_\(Int(Date().timeIntervalSince1970)).jpg",
                    mimeType: "image/jpeg"
                )
                
                // 2. Update Cache & State
                if let updatedUrl = avatarResponse.avatarUrl,
                   let newImage = UIImage(data: data) {
                    AvatarCacheManager.shared.storeImage(newImage, for: updatedUrl)
                    await MainActor.run {
                        self.loadedImage = newImage
                    }
                }
                
                await MainActor.run {
                    if let current = appState.currentUser {
                        let updated = current.updatingAvatarUrl(avatarResponse.avatarUrl)
                        appState.currentUser = updated
                        onAvatarUpdated?(updated)
                    }
                    HapticManager.shared.notification(.success)
                }
            } catch {
                await MainActor.run {
                    let msg = error.localizedDescription
                    onError?(msg)
                    HapticManager.shared.notification(.error)
                }
            }
        }
    }
    
    // MARK: - Delete Pipeline
    private func deleteAvatar() {
        isProcessing = true
        
        Task {
            defer {
                Task { @MainActor in
                    isProcessing = false
                }
            }
            
            do {
                let _: AvatarResponse = try await HTTPClient.shared.request(.deleteAvatar, method: "DELETE")
                
                if let oldUrl = resolvedUser.avatarUrl {
                    AvatarCacheManager.shared.clearCache(for: oldUrl)
                }
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.loadedImage = nil
                    }
                    if let current = appState.currentUser {
                        let updated = current.updatingAvatarUrl(nil)
                        appState.currentUser = updated
                    }
                    onAvatarDeleted?()
                    HapticManager.shared.notification(.success)
                }
            } catch {
                await MainActor.run {
                    let msg = error.localizedDescription
                    onError?(msg)
                    HapticManager.shared.notification(.error)
                }
            }
        }
    }
    
    // MARK: - Helpers
    private func deterministicGradient(for id: Int64, name: String) -> [Color] {
        let hash = abs(Int(id) ^ name.hashValue)
        let index = hash % SpeakITAvatarView.avatarGradients.count
        return SpeakITAvatarView.avatarGradients[index]
    }
    
    private var accessibilityDescription: String {
        let name = resolvedUser.fullName.isEmpty ? resolvedUser.username : resolvedUser.fullName
        if isEditable {
            return "Profile photo of \(name). Double tap to change."
        }
        return "Profile photo of \(name)."
    }
}
