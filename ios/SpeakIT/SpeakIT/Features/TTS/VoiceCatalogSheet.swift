//
//  VoiceCatalogSheet.swift
//  SpeakIT
//
//  Voice selection catalog modal matching 03_Voice_Catalog.svg
//  with high-contrast, fully adaptive language, gender, and engine filtering.
//  Pinned bottom action button and visible reset controls.
//

import SwiftUI

struct VoiceCatalogSheet: View {
    @Binding var selectedVoice: Voice
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    @State private var searchText: String = ""
    @State private var selectedCategory: VoiceCategory = .all
    @State private var selectedGender: String = "ALL" // "ALL", "FEMALE", "MALE"
    @State private var selectedLanguage: String = "ALL"
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
                        .font(.system(size: 18, weight: .bold))
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
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.speakitPrimary)
                        .frame(height: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.speakitTextTertiary)
                
                TextField("Search by name, language or dialect…", text: $searchText)
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
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.speakitBorder, lineWidth: 1)
            )
            .padding(.horizontal, SpeakITSpacing.screenMargin)
            .padding(.top, 8)
            
            // Primary Engine Filter Chips Horizontal Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(VoiceCategory.allCases) { category in
                        let isSelected = selectedCategory == category
                        Button(action: {
                            UISelectionFeedbackGenerator().selectionChanged()
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedCategory = category
                                validateLanguageSelection()
                            }
                        }) {
                            Text(category.rawValue)
                                .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                                .foregroundColor(isSelected ? .white : Color.speakitTextPrimary)
                                .padding(.horizontal, 16)
                                .frame(height: 34)
                                .background(isSelected ? Color.speakitPrimary : Color.speakitCard)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(isSelected ? Color.speakitPrimary : Color.speakitBorder, lineWidth: 1)
                                )
                                .shadow(color: isSelected ? Color.speakitPrimary.opacity(0.3) : .clear, radius: 4, y: 2)
                        }
                    }
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
            }
            .padding(.top, 10)
            .padding(.bottom, 6)
            
            // Secondary Visual Filter Bar: Gender, Language, and Reset Icon
            HStack(spacing: 8) {
                // Gender Filter Segmented Capsule
                HStack(spacing: 2) {
                    ForEach(["ALL", "FEMALE", "MALE"], id: \.self) { g in
                        let isSelected = selectedGender == g
                        Button(action: {
                            UISelectionFeedbackGenerator().selectionChanged()
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedGender = g
                            }
                        }) {
                            HStack(spacing: 3) {
                                if g == "FEMALE" {
                                    Text("♀")
                                        .font(.system(size: 11, weight: .bold))
                                } else if g == "MALE" {
                                    Text("♂")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                Text(g == "ALL" ? "All" : (g == "FEMALE" ? "Female" : "Male"))
                                    .font(.system(size: 11, weight: isSelected ? .bold : .semibold))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .frame(height: 30)
                            .background(
                                isSelected
                                    ? (g == "FEMALE" ? Color(hex: "E85D75") : (g == "MALE" ? Color(hex: "2563EB") : Color.speakitPrimary))
                                    : Color.clear
                            )
                            .foregroundColor(isSelected ? .white : Color.speakitTextPrimary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(Color.speakitCard)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.speakitBorder, lineWidth: 1)
                )
                .fixedSize(horizontal: true, vertical: false)
                
                // Language Dropdown Menu (directly adjacent to Gender, zero gap margin)
                Menu {
                    Button(action: {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedLanguage = "ALL"
                        }
                    }) {
                        HStack {
                            Text("All Languages")
                            if selectedLanguage == "ALL" {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Divider()
                    
                    ForEach(availableLanguages, id: \.self) { lang in
                        Button(action: {
                            UISelectionFeedbackGenerator().selectionChanged()
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedLanguage = lang
                            }
                        }) {
                            HStack {
                                Text(lang)
                                if selectedLanguage == lang {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(selectedLanguage == "ALL" ? Color.speakitPrimary : .white)
                        Text(selectedLanguage == "ALL" ? "Language" : selectedLanguage)
                            .font(.system(size: 11, weight: isSelectedLanguageActive ? .bold : .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 88)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(selectedLanguage == "ALL" ? Color.speakitTextTertiary : .white)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(selectedLanguage == "ALL" ? Color.speakitCard : Color.speakitPrimary)
                    .foregroundColor(selectedLanguage == "ALL" ? Color.speakitTextPrimary : .white)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(selectedLanguage == "ALL" ? Color.speakitBorder : Color.speakitPrimary, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
                
                Spacer()
            }
            .padding(.horizontal, SpeakITSpacing.screenMargin)
            .padding(.top, 4)
            .padding(.bottom, 8)
            
            // Sub-header with Results Count and Clear Button
            HStack {
                Text("\(filteredVoices.count) voices")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.speakitTextSecondary)
                    .textCase(.uppercase)
                
                if hasActiveFilters {
                    Text("• Filter Active")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.speakitPrimary)
                }
                
                Spacer()
                
                if hasActiveFilters {
                    Button(action: {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            resetFilters()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10, weight: .bold))
                            Text("Reset")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(Color.speakitPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.speakitBadgeBackground)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, SpeakITSpacing.screenMargin)
            .padding(.bottom, 6)
            
            // Middle Content: Expanding List or Empty State
            if filteredVoices.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "speaker.slash")
                        .font(.system(size: 44))
                        .foregroundColor(Color.speakitTextTertiary)
                    Text("No matching voices")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color.speakitTextPrimary)
                    Text("Try adjusting your filters or search keywords.")
                        .font(.system(size: 14))
                        .foregroundColor(Color.speakitTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            resetFilters()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 12, weight: .bold))
                            Text("Reset All Filters")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(Color.speakitPrimary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.speakitBadgeBackground)
                        .clipShape(Capsule())
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
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
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                }
            }
            
            // Bottom Action Button (matching other screens button style coding)
            SpeakITButton(
                title: "Select Voice",
                style: .primary
            ) {
                selectedVoice = tempSelectedVoice
                dismiss()
            }
            .accessibilityIdentifier("voices.useVoice")
            .padding(.horizontal, SpeakITSpacing.screenMargin)
            .padding(.bottom, 24)
            .padding(.top, 8)
        }
        .background(Color.speakitBackground)
        .task {
            await loadVoicesFromBackend()
        }
    }
    
    private var isSelectedLanguageActive: Bool {
        selectedLanguage != "ALL"
    }
    
    private var hasActiveFilters: Bool {
        selectedCategory != .all || selectedGender != "ALL" || selectedLanguage != "ALL" || !searchText.isEmpty
    }
    
    private func resetFilters() {
        selectedCategory = .all
        selectedGender = "ALL"
        selectedLanguage = "ALL"
        searchText = ""
    }
    
    private func validateLanguageSelection() {
        if selectedLanguage != "ALL" && !availableLanguages.contains(selectedLanguage) {
            selectedLanguage = "ALL"
        }
    }
    
    private var availableLanguages: [String] {
        let baseVoices: [Voice]
        switch selectedCategory {
        case .all:
            baseVoices = voices
        default:
            baseVoices = voices.filter { $0.matchesCategory(selectedCategory) }
        }
        let list = Set(baseVoices.map { voice in
            voice.languageName.isEmpty ? voice.languageCode : voice.languageName
        })
        return list.sorted()
    }
    
    private var filteredVoices: [Voice] {
        voices.filter { voice in
            let matchesCategory = voice.matchesCategory(selectedCategory)
            
            let matchesSearch = searchText.isEmpty ||
                voice.name.localizedCaseInsensitiveContains(searchText) ||
                voice.languageName.localizedCaseInsensitiveContains(searchText) ||
                voice.languageCode.localizedCaseInsensitiveContains(searchText) ||
                voice.engineDisplayName.localizedCaseInsensitiveContains(searchText)
            
            let matchesGender: Bool
            if selectedGender == "ALL" {
                matchesGender = true
            } else {
                let g = voice.gender.trimmingCharacters(in: .whitespaces).uppercased()
                matchesGender = (g == selectedGender)
            }
            
            let matchesLanguage: Bool
            if selectedLanguage == "ALL" {
                matchesLanguage = true
            } else {
                matchesLanguage = voice.languageName.caseInsensitiveCompare(selectedLanguage) == .orderedSame ||
                                  voice.languageCode.caseInsensitiveCompare(selectedLanguage) == .orderedSame
            }
            
            return matchesCategory && matchesSearch && matchesGender && matchesLanguage
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
