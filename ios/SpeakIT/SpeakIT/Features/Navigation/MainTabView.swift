//
//  MainTabView.swift
//  SpeakIT
//
//  3-Tab authenticated navigation container.
//

import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var profileTabImage: UIImage? = nil
    @State private var cachedUnselectedAvatar: UIImage? = nil
    @State private var cachedSelectedAvatar: UIImage? = nil
    
    var body: some View {
        @Bindable var state = appState
        
        TabView(selection: $state.selectedTab) {
            // Tab 1: Studio (Voice Generation)
            NavigationStack {
                TTSStudioView()
            }
            .tabItem {
                Label("Translate", systemImage: "waveform")
            }
            .tag(0)
            
            // Tab 2: Transcribe (Speech-to-Text)
            NavigationStack {
                STTStudioView()
            }
            .tabItem {
                Label("Transcribe", systemImage: "mic.fill")
            }
            .tag(1)
            
            // Tab 3: Live (Real-Time Live Transcription & Translation)
            NavigationStack {
                LiveTranscriptionView()
            }
            .tabItem {
                Label("Live", systemImage: "waveform.badge.mic")
            }
            .tag(2)
            
            // Tab 4: Activity (History & Usage)
            NavigationStack {
                ActivityView()
            }
            .tabItem {
                Label("Activity", systemImage: "clock.arrow.circlepath")
            }
            .tag(3)
            
            // Tab 5: Profile (Settings & Account)
            NavigationStack {
                ProfileSettingsView()
            }
            .tabItem {
                if let customImg = profileTabImage {
                    Image(uiImage: customImg)
                } else {
                    Image(systemName: "person.crop.circle.fill")
                }
                Text("Profile")
            }
            .tag(4)
        }
        .tint(Color.speakitPrimary)
        .onChange(of: state.selectedTab) { oldTab, newTab in
            HapticManager.shared.selection()
            let wasProfile = (oldTab == 4)
            let isProfile = (newTab == 4)
            if wasProfile != isProfile {
                self.profileTabImage = isProfile ? (cachedSelectedAvatar ?? profileTabImage) : (cachedUnselectedAvatar ?? profileTabImage)
            }
        }
        .task(id: "\(state.currentUser?.avatarUrl ?? "")-\(state.currentUser?.initials ?? "")") {
            await prepareProfileIcons()
        }
        .sheet(isPresented: $state.showPaywallSheet) {
            SubscriptionPaywallView()
        }
    }
    
    private func prepareProfileIcons() async {
        let user = appState.currentUser
        let initials = user?.initials ?? "U"
        let avatarUrl = user?.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var sourceImage: UIImage? = nil
        if let avatarUrl = avatarUrl, !avatarUrl.isEmpty {
            sourceImage = AvatarCacheManager.shared.memoryImage(for: avatarUrl)
            if sourceImage == nil {
                sourceImage = await AvatarCacheManager.shared.loadImage(from: avatarUrl)
            }
        }
        
        let cacheKey = (avatarUrl != nil && !avatarUrl!.isEmpty) ? avatarUrl! : initials
        let unselected = TabBarAvatarRenderer.render(image: sourceImage, initials: initials, isSelected: false, customKey: cacheKey)
        let selected = TabBarAvatarRenderer.render(image: sourceImage, initials: initials, isSelected: true, customKey: cacheKey)
        
        self.cachedUnselectedAvatar = unselected
        self.cachedSelectedAvatar = selected
        self.profileTabImage = (appState.selectedTab == 4) ? selected : unselected
    }
}

#Preview {
    MainTabView()
        .environment(AppState.shared)
}
