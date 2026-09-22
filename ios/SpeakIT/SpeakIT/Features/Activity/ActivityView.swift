//
//  ActivityView.swift
//  SpeakIT
//
//  Activity and history hub matching 06_Activity.svg.
//

import SwiftUI

struct ActivityView: View {
    @Environment(AppState.self) private var appState
    
    @State private var historyItems: [HistoryItem] = HistoryItem.samples
    @State private var showSettings: Bool = false
    @State private var isLoading: Bool = false
    @State private var showClearConfirmation: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header Row
                    HStack {
                        Text("Activity")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(Color.speakitTextPrimary)
                        
                        Spacer()
                        
                        Button(action: {
                            showSettings = true
                        }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color.speakitTextSecondary)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Profile & Settings")
                        .accessibilityIdentifier("profile.settings")
                    }
                    .padding(.top, 8)
                    
                    // Plan & Quota Card
                    let user = appState.currentUser ?? User.sample
                    VStack(alignment: .leading, spacing: 10) {
                        Text(user.planType.displayName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.speakitPrimary)
                        
                        Text("\(user.charactersUsed.formatted()) / \(user.characterLimit.formatted())")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color.speakitTextPrimary)
                        
                        // Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color(hex: "E6E6EB"))
                                    .frame(height: 10)
                                
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.speakitPrimary)
                                    .frame(width: geo.size.width * CGFloat(user.usagePercentage), height: 10)
                            }
                        }
                        .frame(height: 10)
                        
                        HStack {
                            Text("\(Int(user.usagePercentage * 100))% used")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.speakitTextSecondary)
                            
                            Spacer()
                            
                            Text("Renews Oct 14")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color.speakitTextSecondary)
                        }
                    }
                    .padding(18)
                    .background(Color.speakitCard)
                    .cornerRadius(18)
                    .accessibilityIdentifier("activity.quota")
                    
                    // Section Header
                    HStack {
                        Text("Recent Generations")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.speakitTextPrimary)
                        
                        Spacer()
                        
                        if !historyItems.isEmpty {
                            Button(action: {
                                showClearConfirmation = true
                            }) {
                                Text("Clear All")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.speakitPrimary)
                            }
                        }
                    }
                    .padding(.top, 8)
                    
                    // History List
                    if historyItems.isEmpty {
                        SpeakITEmptyState(
                            icon: "clock.arrow.circlepath",
                            title: "No Generations Yet",
                            description: "Your recent Text-to-Speech audio and transcriptions will appear here."
                        )
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(historyItems) { item in
                                SpeakITHistoryRow(item: item) {
                                    playHistoryItem(item)
                                }
                            }
                        }
                        .accessibilityIdentifier("activity.history")
                    }
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
                .padding(.bottom, 24)
            }
            .navigationDestination(isPresented: $showSettings) {
                ProfileSettingsView()
            }
            .alert("Clear History", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    historyItems.removeAll()
                    Task {
                        struct EmptyResponse: Codable {}
                        let _: EmptyResponse? = try? await HTTPClient.shared.request(.clearAllHistory, method: "DELETE")
                    }
                }
            } message: {
                Text("Are you sure you want to clear your generation logs?")
            }
            .task {
                await loadHistoryFromBackend()
            }
        }
    }
    
    private func playHistoryItem(_ item: HistoryItem) {
        if let localURL = item.localAudioURL {
            AudioPlayerManager.shared.loadAndPlay(url: localURL, title: item.textSnippet, subtitle: item.subtitle)
        } else {
            // Mock preview playback for testing
            let tempDir = FileManager.default.temporaryDirectory
            let fallbackURL = tempDir.appendingPathComponent("history_\(item.id).mp3")
            try? Data(repeating: 0, count: 1024).write(to: fallbackURL)
            AudioPlayerManager.shared.loadAndPlay(url: fallbackURL, title: item.textSnippet, subtitle: item.subtitle)
        }
    }
    
    private func loadHistoryFromBackend() async {
        do {
            struct HistoryPageResponse: Codable {
                let content: [HistoryItem]?
            }
            
            let response: HistoryPageResponse = try await HTTPClient.shared.request(.history(page: 0, size: 20))
            if let items = response.content, !items.isEmpty {
                await MainActor.run {
                    self.historyItems = items
                }
            }
        } catch {
            print("Failed to fetch history from backend: \(error). Using sample items.")
        }
    }
}

#Preview {
    ActivityView()
        .environment(AppState.shared)
}
