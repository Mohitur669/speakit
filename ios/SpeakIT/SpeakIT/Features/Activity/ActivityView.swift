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
    @State private var isLoadingInitial: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var currentPage: Int = 0
    @State private var hasMorePages: Bool = true
    @State private var showClearConfirmation: Bool = false
    
    @State private var pageSize: Int = 5
    private let pageSizeOptions: [Int] = [5, 10, 20]
    
    @State private var selectedHistoryItem: HistoryItem? = nil
    @State private var isSelectionMode: Bool = false
    @State private var selectedItemIds: Set<Int64> = []
    @State private var showDeleteSelectedConfirmation: Bool = false
    @State private var isDeletingSelected: Bool = false
    
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
                            UISelectionFeedbackGenerator().selectionChanged()
                            appState.selectedTab = 3
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
                    
                    // Section Header with Edit/Select Toggle and Max History Selector Dropdown
                    HStack(spacing: 8) {
                        Text("History")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color.speakitTextPrimary)
                        
                        Spacer()
                        
                        if isSelectionMode {
                            // "Select All" / "Deselect All"
                            Button(action: {
                                UISelectionFeedbackGenerator().selectionChanged()
                                if selectedItemIds.count == historyItems.count {
                                    selectedItemIds.removeAll()
                                } else {
                                    selectedItemIds = Set(historyItems.map { $0.id })
                                }
                            }) {
                                Text(selectedItemIds.count == historyItems.count ? "Deselect All" : "Select All")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.speakitPrimary)
                            }
                            
                            // "Done" button to exit multiselect mode
                            Button(action: {
                                UISelectionFeedbackGenerator().selectionChanged()
                                withAnimation {
                                    isSelectionMode = false
                                    selectedItemIds.removeAll()
                                }
                            }) {
                                Text("Done")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color.speakitPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.speakitBadgeBackground)
                                    .clipShape(Capsule())
                            }
                        } else {
                            if !historyItems.isEmpty {
                                // "Select" button to enter multiselect mode
                                Button(action: {
                                    UISelectionFeedbackGenerator().selectionChanged()
                                    withAnimation {
                                        isSelectionMode = true
                                        selectedItemIds.removeAll()
                                    }
                                }) {
                                    Text("Select")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color.speakitPrimary)
                                }
                                
                                Button(action: {
                                    showClearConfirmation = true
                                }) {
                                    Text("Clear All")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color.speakitPrimary)
                                }
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
                                SpeakITHistoryRow(
                                    item: item,
                                    isSelectionMode: isSelectionMode,
                                    isSelected: selectedItemIds.contains(item.id),
                                    onSelect: {
                                        toggleSelection(for: item.id)
                                    },
                                    onTap: {
                                        selectedHistoryItem = item
                                    },
                                    onPlay: {
                                        playHistoryItem(item)
                                    }
                                )
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
                                HStack(spacing: 10) {
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        Task {
                                            await loadNextPage()
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "arrow.down.circle.fill")
                                                .font(.system(size: 13, weight: .semibold))
                                            Text("Load More")
                                                .font(.system(size: 13, weight: .semibold))
                                        }
                                        .foregroundColor(Color.speakitPrimary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.speakitBadgeBackground)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    
                                    // Page size selector dropdown beside Load More
                                    pageSizeMenu
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                            } else if historyItems.count >= pageSize {
                                HStack(spacing: 12) {
                                    Text("Showing all \(historyItems.count) generations")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Color.speakitTextTertiary)
                                    
                                    pageSizeMenu
                                }
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
            .safeAreaInset(edge: .bottom) {
                if isSelectionMode {
                    selectionActionBar
                }
            }
            .sheet(item: $selectedHistoryItem) { item in
                HistoryDetailView(item: item) { deletedItem in
                    withAnimation {
                        historyItems.removeAll { $0.id == deletedItem.id }
                    }
                }
            }
            .alert("Delete Selected Items", isPresented: $showDeleteSelectedConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteSelectedItems()
                }
            } message: {
                Text("Are you sure you want to permanently delete \(selectedItemIds.count) generation(s) from your history? This action cannot be undone.")
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
    
    // MARK: - Multiselect Floating Bar
    private var selectionActionBar: some View {
        HStack(spacing: 12) {
            Text("\(selectedItemIds.count) of \(historyItems.count) selected")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.speakitTextSecondary)
            
            Spacer()
            
            Button(action: {
                showDeleteSelectedConfirmation = true
            }) {
                HStack(spacing: 6) {
                    if isDeletingSelected {
                        ProgressView()
                            .scaleEffect(0.75)
                    } else {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 12))
                    }
                    Text(selectedItemIds.isEmpty ? "Delete" : "Delete (\(selectedItemIds.count))")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(selectedItemIds.isEmpty ? Color.speakitTextTertiary : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(selectedItemIds.isEmpty ? Color.gray.opacity(0.18) : Color.speakitDestructive)
                .clipShape(Capsule())
            }
            .disabled(selectedItemIds.isEmpty || isDeletingSelected)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.speakitBackground)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(hex: "E6E6EB"), lineWidth: 1)
        )
        .padding(.horizontal, SpeakITSpacing.screenMargin)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - Page Size Selector Menu
    private var pageSizeMenu: some View {
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
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                Text("\(pageSize) per page")
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(Color.speakitPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.speakitBadgeBackground)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("activity.pageSizeSelector")
    }
    
    private func toggleSelection(for itemId: Int64) {
        if selectedItemIds.contains(itemId) {
            selectedItemIds.remove(itemId)
        } else {
            selectedItemIds.insert(itemId)
        }
    }
    
    private func deleteSelectedItems() {
        guard !selectedItemIds.isEmpty else { return }
        let idsToDelete = Array(selectedItemIds)
        isDeletingSelected = true
        
        Task {
            let bodyData = try? JSONEncoder().encode(idsToDelete)
            let _: EmptyResponse? = try? await HTTPClient.shared.request(.deleteHistory, method: "DELETE", body: bodyData)
            
            await MainActor.run {
                isDeletingSelected = false
                withAnimation {
                    self.historyItems.removeAll { idsToDelete.contains($0.id) }
                    self.selectedItemIds.removeAll()
                    self.isSelectionMode = false
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
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
