//
//  ContentView.swift
//  SpeakIT
//
//  Root navigation coordinator toggling between Login and MainTabView.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    
    // Check for target screen argument from simctl launch or UI tests
    private var overrideScreen: String? {
        if let idx = ProcessInfo.processInfo.arguments.firstIndex(of: "-screen"),
           idx + 1 < ProcessInfo.processInfo.arguments.count {
            return ProcessInfo.processInfo.arguments[idx + 1]
        }
        return ProcessInfo.processInfo.environment["TARGET_SCREEN"]
    }
    
    var body: some View {
        @Bindable var state = appState
        
        Group {
            if let screen = overrideScreen {
                switch screen {
                case "login":
                    LoginView()
                case "tts":
                    MainTabView()
                        .onAppear { state.selectedTab = 0 }
                case "voice_catalog":
                    VoiceCatalogSheet(selectedVoice: .constant(Voice.samples[0]))
                case "stt":
                    MainTabView()
                        .onAppear { state.selectedTab = 1 }
                case "transcription_result":
                    TranscriptionResultSheet(result: TranscriptionResult.sample)
                case "activity":
                    MainTabView()
                        .onAppear { state.selectedTab = 2 }
                case "profile":
                    NavigationStack {
                        ProfileSettingsView()
                    }
                case "paywall":
                    SubscriptionPaywallView()
                default:
                    if state.isAuthenticated {
                        MainTabView()
                    } else {
                        LoginView()
                    }
                }
            } else if state.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .alert("Session Expired", isPresented: $state.showSessionEvictedAlert) {
            Button("Sign In Again", role: .cancel) {
                state.showSessionEvictedAlert = false
            }
        } message: {
            Text("You have been signed out because your account was logged in from another device.")
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState.shared)
}
