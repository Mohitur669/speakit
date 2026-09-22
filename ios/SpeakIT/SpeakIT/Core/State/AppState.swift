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
            self.currentUser = user
        } catch {
            print("Failed to load user profile: \(error)")
            // If offline, use cached or mock user so app remains functional for testing
            if self.currentUser == nil {
                self.currentUser = User.sample
            }
        }
    }
}
