//
//  AppState.swift
//  SpeakIT
//
//  Global Observable application state managing authentication, user profile, and session eviction.
//

import SwiftUI

@MainActor
@Observable
final class AppState {
    static let shared = AppState()
    
    var isAuthenticated: Bool = false
    var currentUser: User? = nil
    var selectedTab: Int = 0
    var showSessionEvictedAlert: Bool = false
    var showPaywallSheet: Bool = false
    var errorMessage: String? = nil
    var isLoadingUser: Bool = false
    var isHistoryDirty: Bool = false
    
    // Dynamic Pricing from Backend System Parameters
    var freePriceDisplay: String = "$0 / month"
    var proPriceDisplay: String = "$9.99 / month"
    var proPlusPriceDisplay: String = "$19.99 / month"
    var proAmountINR: Double = 499.0
    var proPlusAmountINR: Double = 999.0
    
    // Dynamic Monthly Character Quotas from Backend System Parameters
    var monthlyFreeCharacters: Int = 3000
    var monthlyProCharacters: Int = 5000
    var monthlyProPlusCharacters: Int = 10000
    var monthlyEnterpriseCharacters: Int = 1000000
    
    // Dynamic Max Request Characters from Backend System Parameters
    var maxFreeCharacters: Int = 100
    var maxProCharacters: Int = 200
    var maxProPlusCharacters: Int = 500
    var maxEnterpriseCharacters: Int = 2000
    
    // Web host URL for plan management & billing.
    // - Simulator: always http://localhost:4200 (Angular dev server)
    // - Physical device: reads WEB_HOST_URL from xcconfig → Info.plist,
    //   falls back to https://speakit.mohitur.com if unresolved.
    // Override per build target in Local.xcconfig: WEB_HOST_URL = https://your-host.com
    var webHostUrl: String = {
        #if targetEnvironment(simulator)
        return "http://localhost:4200"
        #else
        if let url = Bundle.main.object(forInfoDictionaryKey: "WEB_HOST_URL") as? String,
           !url.isEmpty,
           url != "$(WEB_HOST_URL)" {
            return url.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        }
        return "https://speakit.mohitur.com"
        #endif
    }()
    
    // Manage Plan URL constructed with /settings/plan in code
    var managePlanUrlWeb: String {
        let base = webHostUrl
            .replacingOccurrences(of: "/settings/plan", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        if base.isEmpty {
            return "http://localhost:4200/settings/plan"
        }
        return "\(base)/settings/plan"
    }
    
    private init() {
        // Support UI test / automation argument
        if ProcessInfo.processInfo.arguments.contains("-mockAuth") ||
           ProcessInfo.processInfo.arguments.contains("-screen") {
            self.isAuthenticated = true
            self.currentUser = User.sample
        } else if let token = KeychainHelper.shared.getToken(), !token.isEmpty {
            self.isAuthenticated = true
            Task {
                await self.loadCurrentUser()
            }
        } else {
            // Default active guest profile with 1,450 / 1,500 initial quota matching Figma 02_TTS_Studio.svg
            self.currentUser = User(
                id: 1,
                username: "guest",
                email: "guest@speakit.local",
                fullName: "Guest User",
                role: "ROLE_USER",
                planType: .free,
                status: "ACTIVE",
                characterLimit: 1500,
                charactersUsed: 50 // 1,450 remaining
            )
        }
        
        // Listen for 401 session eviction from HTTPClient
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionInvalidation),
            name: .speakitSessionInvalidated,
            object: nil
        )
        
        // Pre-fetch live plan pricing from system parameters
        Task {
            await self.loadPlanPricing()
        }
    }
    
    @objc private func handleSessionInvalidation() {
        Task { @MainActor in
            self.logout()
            self.showSessionEvictedAlert = true
        }
    }
    
    // MARK: - Auth Actions
    func login(token: String, user: User) {
        KeychainHelper.shared.saveToken(token)
        self.currentUser = user
        self.isAuthenticated = true
        self.showSessionEvictedAlert = false
        Task {
            await self.loadCurrentUser()
        }
    }
    
    func logout() {
        KeychainHelper.shared.deleteToken()
        self.currentUser = nil
        self.isAuthenticated = false
        self.selectedTab = 0
        AudioPlayerManager.shared.stop()
        _ = AudioRecordingManager.shared.stopRecording()
    }
    
    // MARK: - User Profile
    @MainActor
    func loadCurrentUser() async {
        guard isAuthenticated else { return }
        isLoadingUser = true
        defer { isLoadingUser = false }
        
        do {
            let user: User = try await HTTPClient.shared.request(.userProfile)
            // Ensure we never regress to an older character count due to server async write latency
            if let current = self.currentUser, current.id == user.id {
                let resolvedCharactersUsed = max(current.charactersUsed, user.charactersUsed)
                self.currentUser = User(
                    id: user.id,
                    username: user.username,
                    email: user.email,
                    fullName: user.fullName,
                    role: user.role,
                    planType: user.planType,
                    status: user.status,
                    subscriptionStatus: user.subscriptionStatus,
                    planExpiry: user.planExpiry,
                    characterLimit: user.characterLimit,
                    charactersUsed: resolvedCharactersUsed,
                    phoneNumber: user.phoneNumber,
                    avatarUrl: user.avatarUrl,
                    dailyCount: user.dailyCount,
                    dailyLimit: user.dailyLimit,
                    emailVerified: user.emailVerified
                )
            } else {
                self.currentUser = user
            }
        } catch {
            print("Failed to load user profile: \(error)")
            // If offline, use cached or mock user so app remains functional for testing
            if self.currentUser == nil {
                self.currentUser = User.sample
            }
        }
    }
    
    // MARK: - Character Usage / Quota Tracking
    @MainActor
    func recordCharacterUsage(_ count: Int) {
        self.isHistoryDirty = true
        let current = currentUser ?? User(
            id: 1,
            username: "guest",
            email: "guest@speakit.local",
            fullName: "Guest User",
            role: "ROLE_USER",
            planType: .free,
            status: "ACTIVE",
            characterLimit: 1500,
            charactersUsed: 50
        )
        let newUsed = current.charactersUsed + count
        withAnimation(.easeInOut(duration: 0.25)) {
                self.currentUser = User(
                    id: current.id,
                    username: current.username,
                    email: current.email,
                    fullName: current.fullName,
                    role: current.role,
                    planType: current.planType,
                    status: current.status,
                    subscriptionStatus: current.subscriptionStatus,
                    planExpiry: current.planExpiry,
                    characterLimit: current.characterLimit,
                    charactersUsed: newUsed,
                    phoneNumber: current.phoneNumber,
                    avatarUrl: current.avatarUrl,
                    dailyCount: current.dailyCount,
                    dailyLimit: current.dailyLimit,
                    emailVerified: current.emailVerified
                )
        }
        
        if isAuthenticated {
            Task {
                // Short debounce to ensure backend history transaction is committed before refreshing
                try? await Task.sleep(nanoseconds: 600_000_000) // 600ms
                await self.loadCurrentUser()
            }
        }
    }
    
    // MARK: - Dynamic Plan Pricing & Character Quotas
    @MainActor
    func loadPlanPricing() async {
        do {
            let params: [String: String] = try await HTTPClient.shared.request(
                .systemParametersBulk(names: [
                    "IOS_FREE_PLAN_PRICE",
                    "IOS_PRO_PLAN_PRICE",
                    "IOS_PRO_PLUS_PLAN_PRICE",
                    "PRO_PLAN_PRICE_INR",
                    "PRO_PLUS_PLAN_PRICE_INR",
                    "ENTERPRISE_PLAN_PRICE_INR",
                    "MONTHLY_FREE_CHARACTERS",
                    "MONTHLY_PRO_CHARACTERS",
                    "MONTHLY_PRO_PLUS_CHARACTERS",
                    "MONTHLY_ENTERPRISE_CHARACTERS",
                    "MAX_FREE_CHARACTERS",
                    "MAX_PRO_CHARACTERS",
                    "MAX_PRO_PLUS_CHARACTERS",
                    "MAX_ENTERPRISE_CHARACTERS",
                    "MANAGE_PLAN_URL_WEB"
                ])
            )
            
            if let hostParam = params["MANAGE_PLAN_URL_WEB"], !hostParam.trimmingCharacters(in: .whitespaces).isEmpty {
                let cleanHost = hostParam
                    .replacingOccurrences(of: "/settings/plan", with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
                if !cleanHost.isEmpty {
                    self.webHostUrl = cleanHost
                }
            }
            
            if let freePrice = params["IOS_FREE_PLAN_PRICE"], !freePrice.trimmingCharacters(in: .whitespaces).isEmpty {
                self.freePriceDisplay = formatPrice(freePrice)
            }
            
            if let proPrice = params["IOS_PRO_PLAN_PRICE"], !proPrice.trimmingCharacters(in: .whitespaces).isEmpty {
                self.proPriceDisplay = formatPrice(proPrice)
            } else if let proInr = params["PRO_PLAN_PRICE_INR"], !proInr.trimmingCharacters(in: .whitespaces).isEmpty {
                if let val = Double(proInr.trimmingCharacters(in: .whitespacesAndNewlines)), val > 0 {
                    self.proAmountINR = val
                }
                self.proPriceDisplay = "₹\(proInr) / month"
            }
            
            if let proPlusPrice = params["IOS_PRO_PLUS_PLAN_PRICE"], !proPlusPrice.trimmingCharacters(in: .whitespaces).isEmpty {
                self.proPlusPriceDisplay = formatPrice(proPlusPrice)
            } else if let proPlusInr = params["PRO_PLUS_PLAN_PRICE_INR"], !proPlusInr.trimmingCharacters(in: .whitespaces).isEmpty {
                if let val = Double(proPlusInr.trimmingCharacters(in: .whitespacesAndNewlines)), val > 0 {
                    self.proPlusAmountINR = val
                }
                self.proPlusPriceDisplay = "₹\(proPlusInr) / month"
            }
            
            // Monthly character limits from system parameters
            if let freeMonthly = params["MONTHLY_FREE_CHARACTERS"], let val = Int(freeMonthly.trimmingCharacters(in: .whitespacesAndNewlines)) {
                self.monthlyFreeCharacters = val
            }
            if let proMonthly = params["MONTHLY_PRO_CHARACTERS"], let val = Int(proMonthly.trimmingCharacters(in: .whitespacesAndNewlines)) {
                self.monthlyProCharacters = val
            }
            if let proPlusMonthly = params["MONTHLY_PRO_PLUS_CHARACTERS"], let val = Int(proPlusMonthly.trimmingCharacters(in: .whitespacesAndNewlines)) {
                self.monthlyProPlusCharacters = val
            }
            if let entMonthly = params["MONTHLY_ENTERPRISE_CHARACTERS"], let val = Int(entMonthly.trimmingCharacters(in: .whitespacesAndNewlines)) {
                self.monthlyEnterpriseCharacters = val
            }
            
            // Per-request maximum character limits from system parameters
            if let freeMax = params["MAX_FREE_CHARACTERS"], let val = Int(freeMax.trimmingCharacters(in: .whitespacesAndNewlines)) {
                self.maxFreeCharacters = val
            }
            if let proMax = params["MAX_PRO_CHARACTERS"], let val = Int(proMax.trimmingCharacters(in: .whitespacesAndNewlines)) {
                self.maxProCharacters = val
            }
            if let proPlusMax = params["MAX_PRO_PLUS_CHARACTERS"], let val = Int(proPlusMax.trimmingCharacters(in: .whitespacesAndNewlines)) {
                self.maxProPlusCharacters = val
            }
            if let entMax = params["MAX_ENTERPRISE_CHARACTERS"], let val = Int(entMax.trimmingCharacters(in: .whitespacesAndNewlines)) {
                self.maxEnterpriseCharacters = val
            }
        } catch {
            // Keep existing defaults on network error
        }
    }
    
    func getMonthlyCharacterLimit(for plan: PlanType) -> Int {
        switch plan {
        case .free: return monthlyFreeCharacters
        case .pro: return monthlyProCharacters
        case .proPlus: return monthlyProPlusCharacters
        case .enterprise: return monthlyEnterpriseCharacters
        }
    }
    
    func getMaxCharacters(for plan: PlanType) -> Int {
        switch plan {
        case .free: return maxFreeCharacters
        case .pro: return maxProCharacters
        case .proPlus: return maxProPlusCharacters
        case .enterprise: return maxEnterpriseCharacters
        }
    }
    
    func formattedMonthlyQuota(for plan: PlanType) -> String {
        let quota = getMonthlyCharacterLimit(for: plan)
        return NumberFormatter.localizedString(from: NSNumber(value: quota), number: .decimal)
    }
    
    func formattedMaxCharacters(for plan: PlanType) -> String {
        let maxChars = getMaxCharacters(for: plan)
        return NumberFormatter.localizedString(from: NSNumber(value: maxChars), number: .decimal)
    }
    
    private func formatPrice(_ rawPrice: String) -> String {
        let trimmed = rawPrice.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased() == "free" {
            return "Free"
        }
        if trimmed == "0" || trimmed == "0.00" {
            return "$0 / month"
        }
        if trimmed.hasPrefix("$") || trimmed.hasPrefix("₹") {
            return trimmed.contains("/") ? trimmed : "\(trimmed) / month"
        }
        if Double(trimmed) != nil {
            return "$\(trimmed) / month"
        }
        return trimmed.contains("/") ? trimmed : "\(trimmed) / month"
    }
}
