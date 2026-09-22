//
//  VoiceCatalogSheet.swift
//  SpeakIT
//
//  Voice selection catalog modal matching 03_Voice_Catalog.svg.
//

import SwiftUI

struct VoiceCatalogSheet: View {
    @Binding var selectedVoice: Voice
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    @State private var searchText: String = ""
    @State private var selectedCategory: VoiceCategory = .all
    @State private var voices: [Voice] = Voice.samples
    @State private var tempSelectedVoice: Voice
    
    init(selectedVoice: Binding<Voice>) {
        self._selectedVoice = selectedVoice
        self._tempSelectedVoice = State(initialValue: selectedVoice.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color.speakitTextPrimary)
                        .frame(width: 44, height: 44)
                }
                
                Spacer()
                
                Text("Select Voice")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.speakitTextPrimary)
                
                Spacer()
                
                Button(action: {
                    selectedVoice = tempSelectedVoice
                    dismiss()
                }) {
                    Text("Done")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.speakitPrimary)
                        .frame(height: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.speakitTextTertiary)
                
                TextField("Search voices…", text: $searchText)
                    .font(.system(size: 15))
                    .foregroundColor(Color.speakitTextPrimary)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.speakitTextTertiary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color.speakitCard)
            .cornerRadius(12)
            .padding(.horizontal, SpeakITSpacing.screenMargin)
            .padding(.top, 10)
            
            // Filter Chips Horizontal Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(VoiceCategory.allCases) { category in
                        let isSelected = selectedCategory == category
                        Button(action: {
                            UISelectionFeedbackGenerator().selectionChanged()
                            selectedCategory = category
                        }) {
                            Text(category.rawValue)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(isSelected ? .white : Color.speakitTextSecondary)
                                .padding(.horizontal, 14)
                                .frame(height: 30)
                                .background(isSelected ? Color.speakitPrimary : Color(hex: "E9E9EF"))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
            }
            .padding(.vertical, 12)
            
            // Voice List
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filteredVoices) { voice in
                        let isLocked = (appState.currentUser?.planType ?? .free) < voice.requiresPlan
                        SpeakITVoiceRow(
                            voice: voice,
                            isSelected: tempSelectedVoice.id == voice.id,
                            isLocked: isLocked,
                            onSelect: {
                                if isLocked {
                                    appState.showPaywallSheet = true
                                } else {
                                    tempSelectedVoice = voice
                                }
                            },
                            onPreview: {
                                AudioPlayerManager.shared.loadAndPlay(
                                    url: URL(string: voice.previewURL ?? "https://example.com") ?? URL(fileURLWithPath: ""),
                                    title: voice.name,
                                    subtitle: voice.engineDisplayName
                                )
                            }
                        )
                    }
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
                .padding(.bottom, 16)
            }
            
            // Bottom Action Button
            SpeakITButton(
                title: "Use This Voice",
                style: .primary
            ) {
                selectedVoice = tempSelectedVoice
                dismiss()
            }
            .padding(.horizontal, SpeakITSpacing.screenMargin)
            .padding(.bottom, 24)
            .padding(.top, 8)
        }
        .task {
            await loadVoicesFromBackend()
        }
    }
    
    private var filteredVoices: [Voice] {
        voices.filter { voice in
            let matchesCategory = voice.matchesCategory(selectedCategory)
            let matchesSearch = searchText.isEmpty ||
                voice.name.localizedCaseInsensitiveContains(searchText) ||
                voice.languageName.localizedCaseInsensitiveContains(searchText) ||
                voice.engine.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }
    
    private func loadVoicesFromBackend() async {
        do {
            let fetchedVoices: [Voice] = try await HTTPClient.shared.request(.voices)
            if !fetchedVoices.isEmpty {
                await MainActor.run {
                    self.voices = fetchedVoices
                }
            }
        } catch {
            print("Failed to load voices from backend: \(error). Using design pack defaults.")
        }
    }
}

#Preview {
    VoiceCatalogSheet(selectedVoice: .constant(Voice.samples[0]))
        .environment(AppState.shared)
}
