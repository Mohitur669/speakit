//
//  SpeakITLogicTests.swift
//  SpeakIT
//
//  Comprehensive test assertions verifying domain models, plan tier entitlements,
//  voice catalog categorizations, and API endpoint paths.
//

import Foundation
import UIKit

public struct SpeakITLogicTests {
    
    @MainActor
    public static func runAllTests() async -> Bool {
        print("🧪 [TEST SUITE] Starting SpeakIT Native Suite Execution...")
        var passedCount = 0
        var failedCount = 0
        
        func assert(_ condition: @autoclosure () -> Bool, _ message: String) {
            if condition() {
                passedCount += 1
                print("  ✅ PASS: \(message)")
            } else {
                failedCount += 1
                print("  ❌ FAIL: \(message)")
            }
        }
        
        // MARK: - 1. PlanType & Entitlements Tests
        print("▶️ Testing PlanType & Entitlement Gating...")
        assert(PlanType.free < PlanType.pro, "PlanType hierarchy: free < pro")
        assert(PlanType.pro < PlanType.proPlus, "PlanType hierarchy: pro < proPlus")
        assert(PlanType.proPlus < PlanType.enterprise, "PlanType hierarchy: proPlus < enterprise")
        
        assert(PlanType.free.displayName == "Free", "Free plan displayName is Free")
        assert(PlanType.pro.displayName == "Pro", "Pro plan displayName is Pro")
        assert(PlanType.proPlus.displayName == "Pro Plus", "Pro Plus plan displayName is Pro Plus")
        assert(PlanType.enterprise.displayName == "Enterprise", "Enterprise plan displayName is Enterprise")
        
        assert(PlanType.free.monthlyQuota == 3_000, "Free plan quota is 3,000")
        assert(PlanType.pro.monthlyQuota == 5_000, "Pro plan quota is 5,000")
        assert(PlanType.proPlus.monthlyQuota == 10_000, "Pro Plus plan quota is 10,000")
        
        assert(!PlanType.free.allowsLiveSTT, "Free plan does not support live mic STT")
        assert(PlanType.pro.allowsLiveSTT, "Pro plan supports live mic STT")
        assert(PlanType.proPlus.allowsLiveSTT, "Pro Plus plan supports live mic STT")
        
        assert(!PlanType.free.allowsFileSTT, "Free plan does not support file STT")
        assert(PlanType.pro.allowsFileSTT, "Pro plan supports file STT")
        assert(PlanType.proPlus.allowsFileSTT, "Pro Plus plan supports file STT")
        
        assert(PlanType.free.characterLimitPerRequest == 100, "Free char limit per request is 100")
        assert(PlanType.pro.characterLimitPerRequest == 200, "Pro char limit per request is 200")
        assert(PlanType.proPlus.characterLimitPerRequest == 500, "Pro Plus char limit per request is 500")
        
        // MARK: - 2. User Domain Model Tests
        print("▶️ Testing User Domain Model & Quota Computations...")
        let sampleUser = User.sample
        assert(sampleUser.initials == "MS", "User initials for 'Mohit Sharma' should be 'MS'")
        assert(sampleUser.remainingCharacters == 5_000, "Remaining characters for sample user should be 5,000 (5,000 - 0)")
        assert(sampleUser.usagePercentage == 0.0, "Usage percentage should be 0.0")
        
        let singleNameUser = User(id: 2, username: "solo", email: "s@example.com", fullName: "Solo", role: "USER", planType: .free, status: "ACTIVE", characterLimit: 1000, charactersUsed: 0)
        assert(singleNameUser.initials == "S", "Single name user initials should be 'S'")
        
        let emptyNameUser = User(id: 3, username: "empty", email: "e@example.com", fullName: "", role: "USER", planType: .free, status: "ACTIVE", characterLimit: 1000, charactersUsed: 0)
        assert(emptyNameUser.initials == "U", "Empty name user initials should default to 'U'")
        
        let avatarUser = User(id: 4, username: "avatarUser", email: "a@example.com", fullName: "Avatar User", role: "USER", planType: .free, status: "ACTIVE", characterLimit: 1000, charactersUsed: 0, avatarUrl: "https://cdn.speakit.com/avatars/u_4.jpg")
        assert(avatarUser.avatarUrl == "https://cdn.speakit.com/avatars/u_4.jpg", "User avatarUrl preserves configured avatar URL")
        
        // MARK: - 3. Voice Catalog Categorization Tests
        print("▶️ Testing Voice Catalog Categorization & Gating...")
        let voices = Voice.samples
        assert(!voices.isEmpty, "Voice catalog samples are non-empty")
        
        let pollyVoices = voices.filter { $0.matchesCategory(.pollyNeural) }
        assert(pollyVoices.allSatisfy { $0.engine.lowercased() == "neural" || $0.engine.lowercased() == "standard" }, "All filtered Standard voices have neural or standard engine")
        
        let internationalVoices = voices.filter { $0.matchesCategory(.international) }
        assert(internationalVoices.allSatisfy { $0.engine.lowercased() == "elevenlabs" }, "All filtered International voices have elevenlabs engine")
        
        let indianVoices = voices.filter { $0.matchesCategory(.indian) }
        assert(indianVoices.allSatisfy { $0.engine.lowercased() == "sarvam" }, "All filtered Indian voices have sarvam engine")
        
        if let aditi = voices.first(where: { $0.name == "Aditi" }) {
            assert(aditi.requiresPlan == .proPlus, "Aditi voice requires Pro Plus plan")
        }
        if let joanna = voices.first(where: { $0.name == "Joanna" }) {
            assert(joanna.requiresPlan == .free, "Joanna voice is free tier standard voice")
        }
        
        // MARK: - 4. API Endpoints Path Tests
        print("▶️ Testing API Endpoints Construction...")
        assert(APIEndpoint.login.path == "/api/auth/login", "Login endpoint matches contract (/api/auth/login)")
        assert(APIEndpoint.forgotPassword.path == "/api/auth/forgot-password", "Forgot password endpoint matches contract (/api/auth/forgot-password)")
        assert(APIEndpoint.resetPassword.path == "/api/auth/reset-password", "Reset password endpoint matches contract (/api/auth/reset-password)")
        assert(APIEndpoint.requestProfileUpdate.path == "/api/v1/users/profile/request-update", "Request profile update endpoint matches contract (/api/v1/users/profile/request-update)")
        assert(APIEndpoint.requestPasswordChangeOtp.path == "/api/v1/users/password/request-otp", "Request password change OTP matches contract (/api/v1/users/password/request-otp)")
        assert(APIEndpoint.updateProfile.path == "/api/v1/users/profile", "Update profile endpoint matches contract (/api/v1/users/profile)")
        assert(APIEndpoint.updateFullName.path == "/api/v1/users/full-name", "Update full name endpoint matches contract (/api/v1/users/full-name)")
        assert(APIEndpoint.updateUsername.path == "/api/v1/users/username", "Update username endpoint matches contract (/api/v1/users/username)")
        assert(APIEndpoint.requestEmailChangeOtp.path == "/api/v1/users/email/request-otp", "Request email change OTP matches contract (/api/v1/users/email/request-otp)")
        assert(APIEndpoint.updateEmail.path == "/api/v1/users/email", "Update email endpoint matches contract (/api/v1/users/email)")
        assert(APIEndpoint.changePassword.path == "/api/v1/users/password", "Change password endpoint matches contract (/api/v1/users/password)")
        assert(APIEndpoint.synthesize.path == "/api/tts/synthesize", "TTS synthesize endpoint matches contract (/api/tts/synthesize)")
        assert(APIEndpoint.voices.path == "/api/tts/voices", "TTS voices endpoint matches contract (/api/tts/voices)")
        assert(APIEndpoint.transcribeLive.path == "/api/stt/transcribe-live", "STT live endpoint matches contract (/api/stt/transcribe-live)")
        assert(APIEndpoint.transcribeFile.path == "/api/stt/transcribe", "STT file endpoint matches contract (/api/stt/transcribe)")
        assert(APIEndpoint.transliterate.path == "/api/stt/transliterate", "STT transliterate endpoint matches contract (/api/stt/transliterate)")
        assert(APIEndpoint.history(page: 0, size: 5).path == "/api/history?page=0&size=5", "History endpoint matches paginated contract (/api/history?page=0&size=5)")
        assert(APIEndpoint.history(page: 0, size: 10).path == "/api/history?page=0&size=10", "History endpoint matches paginated contract (/api/history?page=0&size=10)")
        assert(APIEndpoint.history(page: 0, size: 20).path == "/api/history?page=0&size=20", "History endpoint matches paginated contract (/api/history?page=0&size=20)")
        assert(APIEndpoint.history(page: 0, size: 5, type: "TTS").path == "/api/history?page=0&size=5&type=TTS", "History endpoint matches TTS filter contract (/api/history?page=0&size=5&type=TTS)")
        assert(APIEndpoint.history(page: 0, size: 5, type: "STT").path == "/api/history?page=0&size=5&type=STT", "History endpoint matches STT filter contract (/api/history?page=0&size=5&type=STT)")
        assert(APIEndpoint.clearAllHistory.path == "/api/history/clear-all", "Clear all history endpoint matches contract (/api/history/clear-all)")
        assert(APIEndpoint.deleteHistory.path == "/api/history/delete", "Delete history endpoint matches contract (/api/history/delete)")
        assert(APIEndpoint.historyAudio(id: 42).path == "/api/history/42/audio", "History audio streaming endpoint matches contract (/api/history/42/audio)")
        assert(APIEndpoint.deleteAccount.path == "/api/v1/users/me", "Account deletion endpoint matches contract (/api/v1/users/me)")
        assert(APIEndpoint.uploadAvatar.path == "/api/v1/users/avatar", "Upload avatar endpoint matches contract (/api/v1/users/avatar)")
        assert(APIEndpoint.deleteAvatar.path == "/api/v1/users/avatar", "Delete avatar endpoint matches contract (/api/v1/users/avatar)")
        
        let itemWithSnippetOnly = HistoryItem(id: 101, textSnippet: "Snippet Only")
        assert(itemWithSnippetOnly.displayText == "Snippet Only", "HistoryItem displayText returns snippet when fullText is nil")
        assert(itemWithSnippetOnly.audioUrl == nil, "HistoryItem audioUrl defaults to nil")
        let itemWithAudioUrl = HistoryItem(id: 103, textSnippet: "Snippet", audioUrl: "https://cdn.speakit.com/audio/sample.mp3")
        assert(itemWithAudioUrl.audioUrl == "https://cdn.speakit.com/audio/sample.mp3", "HistoryItem preserves remote audioUrl")
        let itemWithFullText = HistoryItem(id: 102, textSnippet: "Snippet", fullText: "This is the complete and full transcript")
        assert(itemWithFullText.displayText == "This is the complete and full transcript", "HistoryItem displayText returns fullText when available")
        
        // MARK: - 5. Transcription Result & Language Resolution Tests
        print("▶️ Testing Transcription Result & Language Resolution...")
        let sampleResult = TranscriptionResult.sample
        assert(sampleResult.wordCount == 39, "Sample transcription result word count matches design pack (39 words)")
        assert(sampleResult.durationSeconds == 12, "Sample transcription result duration is 12 seconds")
        assert(sampleResult.formattedDuration == "12 sec", "12 seconds duration formats to '12 sec'")
        
        let longerResult = TranscriptionResult(text: "Test", language: "hi-IN", durationSeconds: 75, wordCount: 1, timestamp: "Now")
        assert(longerResult.formattedDuration == "1 min 15 sec", "75 seconds duration formats to '1 min 15 sec'")
        assert(longerResult.displayLanguage == "Hindi", "Language code 'hi-IN' resolves to human-readable 'Hindi'")
        assert(LanguageHelper.displayName(for: "en") == "English", "Language code 'en' resolves to 'English'")
        assert(LanguageHelper.displayName(for: "ta-IN") == "Tamil", "Language code 'ta-IN' resolves to 'Tamil'")
        assert(LanguageHelper.displayName(for: "bn") == "Bengali", "Language code 'bn' resolves to 'Bengali'")
        
        // MARK: - 6. User Profile Decoding & TabBar Rendering Tests
        print("▶️ Testing User Profile Decoding & TabBar Avatar Rendering...")
        let jsonString = """
        {"token":"test-token","username":"mohitur","fullName":"Mohd Mohitur Rahaman","email":"mohitur669@gmail.com","phoneNumber":null,"avatarUrl":null,"role":"ROLE_USER","planType":"PRO_PLUS","subscriptionStatus":"ACTIVE","planExpiry":"2026-11-03T16:18:16.688424","sessionVersion":6,"sessionDurationMs":7200000,"idleTimeoutMs":300000,"emailVerified":true,"characterLimit":15000,"charactersUsed":494,"dailyCount":0,"dailyLimit":-1,"avatarDailyLimit":20,"avatarChangeCount":0}
        """
        do {
            let decodedUser = try JSONDecoder().decode(User.self, from: jsonString.data(using: .utf8)!)
            assert(decodedUser.username == "mohitur", "Decoded username is mohitur")
            assert(decodedUser.fullName == "Mohd Mohitur Rahaman", "Decoded fullName is Mohd Mohitur Rahaman")
            assert(decodedUser.initials == "MM", "Decoded initials are MM")
            assert(decodedUser.planType == .proPlus, "Decoded planType is PRO_PLUS")
            assert(decodedUser.planExpiry != nil, "Decoded planExpiry is non-nil")
            assert(decodedUser.formattedExpiry != nil, "Decoded formattedExpiry is non-nil")
            
            let unselectedImage = TabBarAvatarRenderer.render(image: nil, initials: decodedUser.initials, isSelected: false)
            assert(unselectedImage.size.width == 25, "TabBar unselected avatar rendered with width 25")
            
            let selectedImage = TabBarAvatarRenderer.render(image: nil, initials: decodedUser.initials, isSelected: true)
            assert(selectedImage.size.width == 25, "TabBar selected avatar rendered with width 25")
        } catch {
            assert(false, "Failed to decode User JSON: \(error)")
        }
        
        // MARK: - 7. Live Login & Profile Integration Test (mohitur / Mohitur669@)
        print("▶️ Testing Live Authentication & Profile Loading for mohitur...")
        do {
            struct LoginReq: Codable {
                let username: String
                let password: String
            }
            struct LoginResp: Codable {
                let token: String
                let username: String?
                let email: String?
                let phoneNumber: String?
                let role: String?
                let planType: String?
                let characterLimit: Int?
                let charactersUsed: Int?
            }
            let body = try JSONEncoder().encode(LoginReq(username: "mohitur", password: "Mohitur669@"))
            let resp: LoginResp = try await HTTPClient.shared.request(.login, method: "POST", body: body)
            
            let resolvedPlan = PlanType(rawValue: (resp.planType ?? "FREE").uppercased()) ?? .free
            let user = User(
                username: resp.username ?? "mohitur",
                email: resp.email ?? "",
                role: resp.role ?? "ROLE_USER",
                planType: resolvedPlan,
                characterLimit: resp.characterLimit,
                charactersUsed: resp.charactersUsed ?? 0,
                phoneNumber: resp.phoneNumber
            )
            AppState.shared.login(token: resp.token, user: user)
            
            // Verify loadCurrentUser()
            await AppState.shared.loadCurrentUser()
            
            assert(AppState.shared.currentUser?.username == "mohitur", "currentUser successfully logged in and updated to mohitur")
            assert(AppState.shared.currentUser?.planType == .proPlus, "mohitur has active PRO_PLUS plan")
            assert(AppState.shared.isAuthenticated, "AppState isAuthenticated is true")
        } catch {
            assert(false, "Live login and user profile retrieval failed for mohitur: \(error)")
        }
        
        print("\n==========================================")
        print("🏁 [TEST SUITE SUMMARY]: \(passedCount) Passed, \(failedCount) Failed")
        print("==========================================\n")
        
        return failedCount == 0
    }
}
