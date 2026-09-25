//
//  AppState.swift
//  SpeakIT
//
//  Global Observable application state managing authentication, user profile, and session eviction.
//

import SwiftUI

@Observable
final class AppState {
    static let shared = AppState()
    
    var isAuthenticated: Bool = false
    var currentUser: User? = nil
    var selectedTab: Int = 0
    var showSessionEvictedAlert: Bool = false
    var showPaywallSheet: Bool = false
    var errorMessage: String? = nil
    var isLoadingUser: Bool = false
    
    private init() {
        // Support UI test / automation argument
        if ProcessInfo.processInfo.arguments.contains("-mockAuth") ||
           ProcessInfo.processInfo.arguments.contains("-screen") {
            self.isAuthenticated = true
            self.currentUser = User.sample
        } else if let token = KeychainHelper.shared.getToken(), !token.isEmpty {
            self.isAuthenticated = true
            Task {
                await self.loadCurrentUser()
            }
        } else {
            // Default active guest profile with 1,450 / 1,500 initial quota matching Figma 02_TTS_Studio.svg
            self.currentUser = User(
                id: 1,
                username: "guest",
                email: "guest@speakit.local",
                fullName: "Guest User",
                role: "ROLE_USER",
                planType: .free,
                status: "ACTIVE",
                characterLimit: 1500,
                charactersUsed: 50 // 1,450 remaining
            )
        }
        
        // Listen for 401 session eviction from HTTPClient
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionInvalidation),
            name: .speakitSessionInvalidated,
            object: nil
        )
    }
    
    @objc private func handleSessionInvalidation() {
        Task { @MainActor in
            self.logout()
            self.showSessionEvictedAlert = true
        }
    }
    
    // MARK: - Auth Actions
    func login(token: String, user: User) {
        KeychainHelper.shared.saveToken(token)
        self.currentUser = user
        self.isAuthenticated = true
        self.showSessionEvictedAlert = false
        Task {
            await self.loadCurrentUser()
        }
    }
    
    func logout() {
        KeychainHelper.shared.deleteToken()
        self.currentUser = nil
        self.isAuthenticated = false
        self.selectedTab = 0
        AudioPlayerManager.shared.stop()
        _ = AudioRecordingManager.shared.stopRecording()
    }
    
    // MARK: - User Profile
    @MainActor
    func loadCurrentUser() async {
        guard isAuthenticated else { return }
        isLoadingUser = true
        defer { isLoadingUser = false }
        
        do {
            let user: User = try await HTTPClient.shared.request(.userProfile)
            // Ensure we never regress to an older character count due to server async write latency
            if let current = self.currentUser, current.id == user.id {
                let resolvedCharactersUsed = max(current.charactersUsed, user.charactersUsed)
                self.currentUser = User(
                    id: user.id,
                    username: user.username,
                    email: user.email,
                    fullName: user.fullName,
                    role: user.role,
                    planType: user.planType,
                    status: user.status,
                    characterLimit: user.characterLimit,
                    charactersUsed: resolvedCharactersUsed
                )
            } else {
                self.currentUser = user
            }
        } catch {
            print("Failed to load user profile: \(error)")
            // If offline, use cached or mock user so app remains functional for testing
            if self.currentUser == nil {
                self.currentUser = User.sample
            }
        }
    }
    
    // MARK: - Character Usage / Quota Tracking
    @MainActor
    func recordCharacterUsage(_ count: Int) {
        let current = currentUser ?? User(
            id: 1,
            username: "guest",
            email: "guest@speakit.local",
            fullName: "Guest User",
            role: "ROLE_USER",
            planType: .free,
            status: "ACTIVE",
            characterLimit: 1500,
            charactersUsed: 50
        )
        let newUsed = current.charactersUsed + count
        withAnimation(.easeInOut(duration: 0.25)) {
            self.currentUser = User(
                id: current.id,
                username: current.username,
                email: current.email,
                fullName: current.fullName,
                role: current.role,
                planType: current.planType,
                status: current.status,
                characterLimit: current.characterLimit,
                charactersUsed: newUsed
            )
        }
        
        if isAuthenticated {
            Task {
                // Short debounce to ensure backend history transaction is committed before refreshing
                try? await Task.sleep(nanoseconds: 600_000_000) // 600ms
                await self.loadCurrentUser()
            }
        }
    }
}
