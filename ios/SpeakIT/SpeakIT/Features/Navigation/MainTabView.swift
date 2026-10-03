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
        .onChange(of: state.selectedTab) { _, _ in
            HapticManager.shared.selection()
            Task {
                await updateProfileTabIcon()
            }
        }
        .task(id: "\(state.currentUser?.avatarUrl ?? "")-\(state.currentUser?.initials ?? "")-\(state.selectedTab)") {
            await updateProfileTabIcon()
        }
        .sheet(isPresented: $state.showPaywallSheet) {
            SubscriptionPaywallView()
        }
    }
    
    private func updateProfileTabIcon() async {
        let user = appState.currentUser
        let initials = user?.initials ?? "U"
        let isSelected = appState.selectedTab == 4
        
        if let avatarUrl = user?.avatarUrl, !avatarUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let img = AvatarCacheManager.shared.memoryImage(for: avatarUrl) {
                self.profileTabImage = TabBarAvatarRenderer.render(image: img, initials: initials, isSelected: isSelected)
                return
            }
            if let img = await AvatarCacheManager.shared.loadImage(from: avatarUrl) {
                self.profileTabImage = TabBarAvatarRenderer.render(image: img, initials: initials, isSelected: isSelected)
                return
            }
        }
        
        self.profileTabImage = TabBarAvatarRenderer.render(image: nil, initials: initials, isSelected: isSelected)
    }
}

#Preview {
    MainTabView()
        .environment(AppState.shared)
}
