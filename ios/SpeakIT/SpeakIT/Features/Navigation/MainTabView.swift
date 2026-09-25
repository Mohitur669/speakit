//
//  MainTabView.swift
//  SpeakIT
//
//  3-Tab authenticated navigation container.
//

import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var state = appState
        
        TabView(selection: $state.selectedTab) {
            // Tab 1: Studio (Voice Generation)
            NavigationStack {
                TTSStudioView()
            }
            .tabItem {
                Label("Studio", systemImage: "waveform")
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
            
            // Tab 3: Activity (History & Usage)
            NavigationStack {
                ActivityView()
            }
            .tabItem {
                Label("Activity", systemImage: "clock.arrow.circlepath")
            }
            .tag(2)
        }
        .tint(Color.speakitPrimary)
        .sheet(isPresented: $state.showPaywallSheet) {
            SubscriptionPaywallView()
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppState.shared)
}
