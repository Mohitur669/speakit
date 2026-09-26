//
//  ActivityView.swift
//  SpeakIT
//
//  Activity and history hub matching 06_Activity.svg.
//

import SwiftUI

struct ActivityView: View {
    @Environment(AppState.self) private var appState
    
    @State private var historyItems: [HistoryItem] = []
    @State private var showSettings: Bool = false
    @State private var isLoadingInitial: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var currentPage: Int = 0
    @State private var hasMorePages: Bool = true
    @State private var showClearConfirmation: Bool = false
    
    @State private var pageSize: Int = 5
    private let pageSizeOptions: [Int] = [5, 10, 20]
    
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
                    
                    // Section Header with Max History Selector Dropdown (5, 10, 20)
                    HStack(spacing: 8) {
                        Text("Recent Generations")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.speakitTextPrimary)
                        
                        Spacer()
                        
                        // Max History Selector Dropdown
                        Menu {
                            ForEach(pageSizeOptions, id: \.self) { size in
                                Button(action: {
                                    changePageSize(to: size)
                                }) {
                                    HStack {
                                        Text("\(size) items")
                                        if pageSize == size {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("\(pageSize) max")
                                    .font(.system(size: 11, weight: .bold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .foregroundColor(Color.speakitPrimary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.speakitBadgeBackground)
                            .clipShape(Capsule())
                        }
                        .accessibilityIdentifier("activity.pageSizeSelector")
                        
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
                    
                    // History List with Paginated LazyVStack
                    if isLoadingInitial && historyItems.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView("Loading history…")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.speakitTextSecondary)
                                .padding(.vertical, 32)
                            Spacer()
                        }
                    } else if historyItems.isEmpty {
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
                            
                            // Controlled Pagination Footer
                            if isLoadingMore {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.85)
                                    Text("Loading next \(pageSize)…")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color.speakitTextSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                            } else if hasMorePages {
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    Task {
                                        await loadNextPage()
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .font(.system(size: 13, weight: .semibold))
                                        Text("Load More (\(pageSize))")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundColor(Color.speakitPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.speakitBadgeBackground)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                            } else if historyItems.count >= pageSize {
                                Text("Showing all \(historyItems.count) generations")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color.speakitTextTertiary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                        }
                        .accessibilityIdentifier("activity.history")
                    }
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
                .padding(.bottom, 24)
            }
            .refreshable {
                await refreshAll()
            }
            .navigationDestination(isPresented: $showSettings) {
                ProfileSettingsView()
            }
            .alert("Clear History", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    historyItems.removeAll()
                    currentPage = 0
                    hasMorePages = false
                    Task {
                        struct EmptyResponse: Codable {}
                        let _: EmptyResponse? = try? await HTTPClient.shared.request(.clearAllHistory, method: "DELETE")
                    }
                }
            } message: {
                Text("Are you sure you want to clear your generation logs?")
            }
            .task {
                await loadInitialHistory()
                await appState.loadCurrentUser()
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
    
    private func changePageSize(to newSize: Int) {
        guard pageSize != newSize else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        pageSize = newSize
        historyItems.removeAll()
        Task {
            await loadInitialHistory()
        }
    }
    
    private func refreshAll() async {
        await appState.loadCurrentUser()
        await loadInitialHistory()
    }
    
    private func loadInitialHistory() async {
        await MainActor.run {
            self.isLoadingInitial = true
            self.currentPage = 0
            self.hasMorePages = true
        }
        
        do {
            let response: HistoryPageResponse = try await HTTPClient.shared.request(
                .history(page: 0, size: pageSize)
            )
            await MainActor.run {
                self.isLoadingInitial = false
                if let items = response.content, !items.isEmpty {
                    self.historyItems = items
                    self.hasMorePages = !response.isLastPage && (items.count == self.pageSize)
                } else {
                    // Fall back to sample items in preview/offline mode (first page of 5 items)
                    self.historyItems = Array(HistoryItem.samples.prefix(self.pageSize))
                    self.hasMorePages = HistoryItem.samples.count > self.pageSize
                }
            }
        } catch {
            await MainActor.run {
                self.isLoadingInitial = false
                print("Failed to fetch history from backend: \(error). Using fallback.")
                if self.historyItems.isEmpty {
                    self.historyItems = Array(HistoryItem.samples.prefix(self.pageSize))
                    self.hasMorePages = HistoryItem.samples.count > self.pageSize
                } else {
                    self.hasMorePages = false
                }
            }
        }
    }
    
    private func loadNextPage() async {
        guard !isLoadingMore && hasMorePages else { return }
        
        await MainActor.run {
            self.isLoadingMore = true
        }
        
        let nextPage = currentPage + 1
        
        do {
            let response: HistoryPageResponse = try await HTTPClient.shared.request(
                .history(page: nextPage, size: pageSize)
            )
            await MainActor.run {
                self.isLoadingMore = false
                if let newItems = response.content, !newItems.isEmpty {
                    // Deduplicate by ID to prevent duplicates if new records were inserted
                    let existingIds = Set(self.historyItems.map { $0.id })
                    let uniqueNewItems = newItems.filter { !existingIds.contains($0.id) }
                    self.historyItems.append(contentsOf: uniqueNewItems)
                    self.currentPage = nextPage
                    self.hasMorePages = !response.isLastPage && (newItems.count == self.pageSize)
                } else {
                    self.hasMorePages = false
                }
            }
        } catch {
            await MainActor.run {
                self.isLoadingMore = false
                // Check if offline/sample pagination applies
                let startIndex = nextPage * self.pageSize
                if startIndex < HistoryItem.samples.count {
                    let endIndex = min(startIndex + self.pageSize, HistoryItem.samples.count)
                    let newItems = Array(HistoryItem.samples[startIndex..<endIndex])
                    let existingIds = Set(self.historyItems.map { $0.id })
                    let uniqueNewItems = newItems.filter { !existingIds.contains($0.id) }
                    self.historyItems.append(contentsOf: uniqueNewItems)
                    self.currentPage = nextPage
                    self.hasMorePages = endIndex < HistoryItem.samples.count
                } else {
                    self.hasMorePages = false
                }
                print("Failed to fetch next history page from network: \(error). Used local pagination if available.")
            }
        }
    }
}

// MARK: - Spring Boot Paged Response DTO
struct HistoryPageMetadata: Codable {
    let size: Int?
    let number: Int?
    let totalElements: Int?
    let totalPages: Int?
}

struct HistoryPageResponse: Codable {
    let content: [HistoryItem]?
    let page: HistoryPageMetadata?
    let totalPages: Int?
    let totalElements: Int?
    let last: Bool?
    let numberOfElements: Int?
    
    var isLastPage: Bool {
        if let l = last {
            return l
        }
        if let p = page, let num = p.number, let tp = p.totalPages {
            return num >= (tp - 1)
        }
        if let tp = totalPages, let num = page?.number {
            return num >= (tp - 1)
        }
        if let items = content {
            return items.isEmpty
        }
        return true
    }
}

#Preview {
    ActivityView()
        .environment(AppState.shared)
}
