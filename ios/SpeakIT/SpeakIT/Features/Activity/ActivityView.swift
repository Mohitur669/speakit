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
    
    enum ActivityFilter: String, CaseIterable, Identifiable {
        case all = "ALL"
        case translate = "TRANSLATE"
        case transcribe = "TRANSCRIBE"
        case liveChat = "LIVE"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .all: return "All"
            case .translate: return "Translate"
            case .transcribe: return "Transcribe"
            case .liveChat: return "Live Chat"
            }
        }
    }
    
    @State private var selectedFilter: ActivityFilter = .all
    @State private var selectedLiveChatItem: HistoryItem? = nil
    
    @State private var selectedHistoryItem: HistoryItem? = nil
    @State private var isSelectionMode: Bool = false
    @State private var selectedItemIds: Set<Int64> = []
    @State private var showDeleteSelectedConfirmation: Bool = false
    @State private var isDeletingSelected: Bool = false
    @State private var usageAnalytics: UsageAnalytics? = nil
    
    // Audio Playback Tracking (Lazy-loading on click)
    @State private var playerManager = AudioPlayerManager.shared
    @State private var playingItemId: Int64? = nil
    @State private var loadingItemId: Int64? = nil
    @State private var errorMessage: String? = nil
    
    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header Row
                    HStack {
                        Text("Activity")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(Color.speakitTextPrimary)
                        
                        Spacer()
                        
                        Button(action: {
                            HapticManager.shared.selection()
                            appState.selectedTab = 4
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
                                    .fill(Color.speakitBorder)
                                    .frame(height: 10)
                                
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.speakitPrimary)
                                    .frame(width: geo.size.width * CGFloat(user.usagePercentage), height: 10)
                            }
                        }
                        .frame(height: 10)
                        
                        HStack {
                            Text("\(user.remainingCharacters.formatted()) remaining")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.speakitTextSecondary)
                            
                            Spacer()
                            
                            Text("\(Int(user.usagePercentage * 100))% used")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.speakitPrimary)
                        }
                        
                        // Daily Burn Rate
                        if let analytics = usageAnalytics {
                            Divider()
                                .background(Color.speakitBorder)
                                .padding(.vertical, 4)
                            
                            HStack {
                                Label("Avg. Usage: \(Int(analytics.burnRatePerDay).formatted()) chars/day", systemImage: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.orange)
                                
                                Spacer()
                                
                                if analytics.daysRemainingInMonth > 0 {
                                    Text("Renews in \(analytics.daysRemainingInMonth)d")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Color.speakitTextSecondary)
                                }
                            }
                        }
                    }
                    .padding(18)
                    .background(Color.speakitCardSurface)
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.speakitBorder, lineWidth: 1)
                    )
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
                                HapticManager.shared.selection()
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
                                HapticManager.shared.selection()
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
                                    HapticManager.shared.selection()
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
                    
                    // Filter Segmented Control: [All, TTS, STT]
                    Picker("Filter Activity", selection: $selectedFilter) {
                        ForEach(ActivityFilter.allCases) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedFilter) { _, _ in
                        HapticManager.shared.selection()
                    }
                    
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
                    } else if filteredHistoryItems.isEmpty {
                        SpeakITEmptyState(
                            icon: emptyStateIcon,
                            title: emptyStateTitle,
                            description: emptyStateDescription
                        )
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredHistoryItems) { item in
                                if item.isLiveChat {
                                    liveChatHistoryCard(item)
                                } else {
                                    SpeakITHistoryRow(
                                        item: item,
                                        isPlaying: (playingItemId == item.id) && playerManager.isPlaying,
                                        isLoading: loadingItemId == item.id,
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
                                        HapticManager.shared.light()
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
            .background(Color.speakitScreenBackground.ignoresSafeArea())
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
            .sheet(item: $selectedLiveChatItem) { item in
                LiveChatDetailView(item: item)
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
            .task(id: selectedFilter) {
                historyItems.removeAll()
                await loadInitialHistory()
                await appState.loadCurrentUser()
                await loadUsageAnalytics()
                appState.isHistoryDirty = false
            }
            .onAppear {
                Task {
                    await loadUsageAnalytics()
                }
                if appState.isHistoryDirty {
                    Task {
                        await loadInitialHistory()
                        await appState.loadCurrentUser()
                        appState.isHistoryDirty = false
                    }
                }
            }
            .speakITToast(message: $errorMessage, style: .error, bottomPadding: 20)
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
        .background(Color.speakitCardSurface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.speakitBorder, lineWidth: 1)
        )
        .padding(.horizontal, SpeakITSpacing.screenMargin)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - Page Size Selector Menu
    private var pageSizeMenu: some View {
        SpeakITDropdownMenu(
            selection: Binding(
                get: { pageSize },
                set: { changePageSize(to: $0) }
            ),
            options: pageSizeOptions,
            title: { "\($0) items" },
            accentColor: Color.speakitPrimary,
            minWidth: 140
        ) {
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
        .accessibilityIdentifier("activity.pageSizeSelector")
    }
    
    // MARK: - Filtered Items & Empty States
    private var filteredHistoryItems: [HistoryItem] {
        switch selectedFilter {
        case .all:
            return historyItems
        case .translate:
            return historyItems.filter { $0.isTTS }
        case .transcribe:
            return historyItems.filter { $0.isSTT }
        case .liveChat:
            return historyItems.filter { $0.isLiveChat }
        }
    }
    
    private var emptyStateIcon: String {
        switch selectedFilter {
        case .all: return "clock.arrow.circlepath"
        case .translate: return "waveform"
        case .transcribe: return "mic.fill"
        case .liveChat: return "bubble.left.and.bubble.right.fill"
        }
    }
    
    private var emptyStateTitle: String {
        switch selectedFilter {
        case .all: return "No Activity Yet"
        case .translate: return "No Translations"
        case .transcribe: return "No Transcriptions"
        case .liveChat: return "No Live Sessions"
        }
    }
    
    private var emptyStateDescription: String {
        switch selectedFilter {
        case .all: return "Your generated speech, transcriptions, and live conversations will appear here."
        case .translate: return "Synthesize speech in the Translate tab to view your generation history."
        case .transcribe: return "Transcribe audio files or speech in the Transcribe tab to see records."
        case .liveChat: return "Start a Face-to-Face conversation in Live mode to save dialogue logs."
        }
    }
    
    // MARK: - Live Chat History Card (SpeakIT Design System Aligned)
    private func liveChatHistoryCard(_ item: HistoryItem) -> some View {
        let isSelected = selectedItemIds.contains(item.id)
        let turns = item.liveChatTurnCount
        
        return HStack(spacing: 14) {
            if isSelectionMode {
                // Multiselect Checkbox
                Button(action: {
                    HapticManager.shared.selection()
                    toggleSelection(for: item.id)
                }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(isSelected ? Color.speakitPrimary : Color.speakitTextTertiary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSelected ? "Selected" : "Not selected")
            } else {
                // Live Chat Icon Badge
                Button(action: {
                    HapticManager.shared.light()
                    selectedLiveChatItem = item
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.speakitBadgeBackground)
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.speakitPrimary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View Live Conversation \(item.liveChatTitle)")
            }
            
            // Title & Subtitle Info
            VStack(alignment: .leading, spacing: 3) {
                Text(item.liveChatTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.speakitTextPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text("\(turns) \(turns == 1 ? "turn" : "turns")")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.speakitTextSecondary)
                    
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(Color.speakitTextTertiary)
                    
                    Text("Live Session")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.speakitPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.speakitBadgeBackground)
                        .clipShape(Capsule())
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelectionMode {
                    HapticManager.shared.selection()
                    toggleSelection(for: item.id)
                } else {
                    HapticManager.shared.light()
                    selectedLiveChatItem = item
                }
            }
            
            Spacer()
            
            // Timestamp (Date & Time in AM/PM directly stamped) and optional chevron
            HStack(spacing: 6) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.formattedDate)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.speakitTextSecondary)
                    
                    Text(item.formattedTime)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(Color.speakitTextTertiary)
                }
                
                if !isSelectionMode {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.speakitTextTertiary.opacity(0.7))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelectionMode {
                    HapticManager.shared.selection()
                    toggleSelection(for: item.id)
                } else {
                    HapticManager.shared.light()
                    selectedLiveChatItem = item
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 70)
        .background(isSelected ? Color.speakitBadgeBackground.opacity(0.7) : Color.speakitCardSurface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.speakitPrimary : Color.speakitBorder, lineWidth: isSelected ? 1.5 : 1)
        )
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
                HapticManager.shared.success()
            }
        }
    }
    
    private func playHistoryItem(_ item: HistoryItem) {
        // 1. Toggle Play / Pause if this item is already active
        if playingItemId == item.id {
            if playerManager.isPlaying {
                playerManager.pause()
            } else {
                playerManager.play()
            }
            return
        }
        
        // 2. If already loading this item, prevent duplicate network requests
        if loadingItemId == item.id {
            return
        }
        
        // 3. Check for local memory URL (e.g. freshly synthesized in this session)
        if let localURL = item.localAudioURL, FileManager.default.fileExists(atPath: localURL.path) {
            playingItemId = item.id
            playerManager.loadAndPlay(url: localURL, title: item.textSnippet, subtitle: item.subtitle)
            return
        }
        
        // 4. Two-Tier Audio Cache: Check persistent local disk cache (<Caches>/AudioHistory/history_{id}.mp3)
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AudioHistory", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let cachedFileURL = cacheDir.appendingPathComponent("history_\(item.id).mp3")
        
        if FileManager.default.fileExists(atPath: cachedFileURL.path),
           let attrs = try? FileManager.default.attributesOfItem(atPath: cachedFileURL.path),
           let fileSize = attrs[.size] as? Int64, fileSize > 0 {
            // Fast Path: Already cached on disk -> Instant 0ms playback!
            playingItemId = item.id
            playerManager.loadAndPlay(url: cachedFileURL, title: item.textSnippet, subtitle: item.subtitle)
            return
        }
        
        // 5. On-Demand Lazy Download (Never pre-loaded in list view for maximum 120Hz performance)
        loadingItemId = item.id
        Task {
            do {
                var data: Data? = nil
                
                // Tier A: Direct zero-egress Cloudflare R2 CDN download if public URL is present
                if let urlStr = item.audioUrl, urlStr.hasPrefix("http"), let remoteURL = URL(string: urlStr) {
                    data = try? await HTTPClient.shared.downloadBinaryFromURL(remoteURL)
                }
                
                // Tier B: Fallback to authenticated backend streaming endpoint (/api/history/{id}/audio)
                if data == nil || data?.isEmpty == true {
                    data = try await HTTPClient.shared.downloadBinaryGet(.historyAudio(id: item.id))
                }
                
                guard let finalData = data, !finalData.isEmpty else {
                    throw APIError.missingData
                }
                
                // Persist to local disk cache for instant offline and future replay
                try finalData.write(to: cachedFileURL, options: .atomic)
                
                await MainActor.run {
                    if self.loadingItemId == item.id {
                        self.loadingItemId = nil
                        self.playingItemId = item.id
                        self.playerManager.loadAndPlay(
                            url: cachedFileURL,
                            title: item.textSnippet,
                            subtitle: item.subtitle
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    if self.loadingItemId == item.id {
                        self.loadingItemId = nil
                    }
                    print("Failed to load on-demand audio for history item \(item.id): \(error)")
                    self.errorMessage = "Unable to play audio: \(error.localizedDescription)"
                    HapticManager.shared.error()
                }
            }
        }
    }
    
    private func changePageSize(to newSize: Int) {
        guard pageSize != newSize else { return }
        HapticManager.shared.selection()
        pageSize = newSize
        historyItems.removeAll()
        Task {
            await loadInitialHistory()
        }
    }
    
    private func refreshAll() async {
        // Refresh history, user profile and usage analytics concurrently
        async let userTask: Void = appState.loadCurrentUser()
        async let historyTask: Void = loadInitialHistory()
        async let analyticsTask: Void = loadUsageAnalytics()
        _ = await (userTask, historyTask, analyticsTask)
        appState.isHistoryDirty = false
    }

    private func loadUsageAnalytics() async {
        do {
            let analytics: UsageAnalytics = try await HTTPClient.shared.request(.usageAnalytics)
            await MainActor.run {
                self.usageAnalytics = analytics
            }
        } catch {
            print("Failed to load usage analytics: \(error)")
        }
    }
    
    private func loadInitialHistory() async {
        await MainActor.run {
            self.isLoadingInitial = true
            self.currentPage = 0
            self.hasMorePages = true
        }
        
        do {
            let response: HistoryPageResponse = try await HTTPClient.shared.request(
                .history(page: 0, size: pageSize, type: selectedFilter.rawValue)
            )
            await MainActor.run {
                self.isLoadingInitial = false
                if let items = response.content {
                    self.historyItems = items
                    self.hasMorePages = !response.isLastPage && (items.count == self.pageSize)
                } else {
                    if self.historyItems.isEmpty {
                        self.historyItems = []
                    }
                    self.hasMorePages = false
                }
            }
        } catch {
            await MainActor.run {
                self.isLoadingInitial = false
                if !(error is CancellationError) && (error as? URLError)?.code != .cancelled {
                    print("Failed to fetch history from backend: \(error)")
                }
                // Never clear existing history items on refresh error or gesture cancellation
                if self.historyItems.isEmpty {
                    self.historyItems = []
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
                .history(page: nextPage, size: pageSize, type: selectedFilter.rawValue)
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
                self.hasMorePages = false
                print("Failed to fetch next history page from network: \(error)")
            }
        }
    }
}

private struct ActivityDummyCodable: Codable {}

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
    
    enum CodingKeys: String, CodingKey {
        case content, page, totalPages, totalElements, last, numberOfElements
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.page = try? container.decode(HistoryPageMetadata.self, forKey: .page)
        self.totalPages = try? container.decode(Int.self, forKey: .totalPages)
        self.totalElements = try? container.decode(Int.self, forKey: .totalElements)
        self.last = try? container.decode(Bool.self, forKey: .last)
        self.numberOfElements = try? container.decode(Int.self, forKey: .numberOfElements)
        
        // Resilient array decoding: if any single item has unexpected structure, preserve all other items!
        if var contentArray = try? container.nestedUnkeyedContainer(forKey: .content) {
            var items: [HistoryItem] = []
            while !contentArray.isAtEnd {
                if let item = try? contentArray.decode(HistoryItem.self) {
                    items.append(item)
                } else {
                    _ = try? contentArray.decode(ActivityDummyCodable.self)
                }
            }
            self.content = items
        } else {
            self.content = try? container.decode([HistoryItem].self, forKey: .content)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(page, forKey: .page)
        try container.encodeIfPresent(totalPages, forKey: .totalPages)
        try container.encodeIfPresent(totalElements, forKey: .totalElements)
        try container.encodeIfPresent(last, forKey: .last)
        try container.encodeIfPresent(numberOfElements, forKey: .numberOfElements)
    }
    
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
