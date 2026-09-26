//
//  SpeakITLogicTests.swift
//  SpeakIT
//
//  Comprehensive test assertions verifying domain models, plan tier entitlements,
//  voice catalog categorizations, and API endpoint paths.
//

import Foundation

public struct SpeakITLogicTests {
    
    public static func runAllTests() -> Bool {
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
        
        assert(PlanType.free.monthlyQuota == 10_000, "Free plan quota is 10,000")
        assert(PlanType.pro.monthlyQuota == 100_000, "Pro plan quota is 100,000")
        assert(PlanType.proPlus.monthlyQuota == 250_000, "Pro Plus plan quota is 250,000")
        
        assert(!PlanType.free.allowsLiveSTT, "Free plan does not support live mic STT")
        assert(!PlanType.pro.allowsLiveSTT, "Pro plan does not support live mic STT")
        assert(PlanType.proPlus.allowsLiveSTT, "Pro Plus plan supports live mic STT")
        
        assert(!PlanType.free.allowsFileSTT, "Free plan does not support file STT")
        assert(PlanType.pro.allowsFileSTT, "Pro plan supports file STT")
        assert(PlanType.proPlus.allowsFileSTT, "Pro Plus plan supports file STT")
        
        assert(PlanType.free.characterLimitPerRequest == 500, "Free char limit per request is 500")
        assert(PlanType.pro.characterLimitPerRequest == 2_500, "Pro char limit per request is 2,500")
        assert(PlanType.proPlus.characterLimitPerRequest == 10_000, "Pro Plus char limit per request is 10,000")
        
        // MARK: - 2. User Domain Model Tests
        print("▶️ Testing User Domain Model & Quota Computations...")
        let sampleUser = User.sample
        assert(sampleUser.initials == "MS", "User initials for 'Mohit Sharma' should be 'MS'")
        assert(sampleUser.remainingCharacters == 10_750, "Remaining characters for sample user should be 10,750 (25,000 - 14,250)")
        assert(abs(sampleUser.usagePercentage - 0.57) < 0.01, "Usage percentage should be ~0.57")
        
        let singleNameUser = User(id: 2, username: "solo", email: "s@example.com", fullName: "Solo", role: "USER", planType: .free, status: "ACTIVE", characterLimit: 1000, charactersUsed: 0)
        assert(singleNameUser.initials == "S", "Single name user initials should be 'S'")
        
        let emptyNameUser = User(id: 3, username: "empty", email: "e@example.com", fullName: "", role: "USER", planType: .free, status: "ACTIVE", characterLimit: 1000, charactersUsed: 0)
        assert(emptyNameUser.initials == "U", "Empty name user initials should default to 'U'")
        
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
            assert(joanna.requiresPlan == .pro, "Joanna voice requires Pro plan")
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
        assert(APIEndpoint.history(page: 0, size: 5).path == "/api/history?page=0&size=5", "History endpoint matches paginated contract (/api/history?page=0&size=5)")
        assert(APIEndpoint.history(page: 0, size: 10).path == "/api/history?page=0&size=10", "History endpoint matches paginated contract (/api/history?page=0&size=10)")
        assert(APIEndpoint.history(page: 0, size: 20).path == "/api/history?page=0&size=20", "History endpoint matches paginated contract (/api/history?page=0&size=20)")
        assert(APIEndpoint.clearAllHistory.path == "/api/history/clear-all", "Clear all history endpoint matches contract (/api/history/clear-all)")
        assert(APIEndpoint.deleteHistory.path == "/api/history/delete", "Delete history endpoint matches contract (/api/history/delete)")
        assert(APIEndpoint.deleteAccount.path == "/api/v1/users/me", "Account deletion endpoint matches contract (/api/v1/users/me)")
        
        let itemWithSnippetOnly = HistoryItem(id: 101, textSnippet: "Snippet Only")
        assert(itemWithSnippetOnly.displayText == "Snippet Only", "HistoryItem displayText returns snippet when fullText is nil")
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
        
        print("\n==========================================")
        print("🏁 [TEST SUITE SUMMARY]: \(passedCount) Passed, \(failedCount) Failed")
        print("==========================================\n")
        
        return failedCount == 0
    }
}
