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
        assert(pollyVoices.allSatisfy { $0.engine.lowercased() == "neural" }, "All filtered Polly voices have neural engine")
        
        let elevenLabsVoices = voices.filter { $0.matchesCategory(.elevenLabs) }
        assert(elevenLabsVoices.allSatisfy { $0.engine.lowercased() == "elevenlabs" }, "All filtered ElevenLabs voices have elevenlabs engine")
        
        let sarvamVoices = voices.filter { $0.matchesCategory(.sarvam) }
        assert(sarvamVoices.allSatisfy { $0.engine.lowercased() == "sarvam" }, "All filtered Sarvam voices have sarvam engine")
        
        if let aditi = voices.first(where: { $0.name == "Aditi" }) {
            assert(aditi.requiresPlan == .proPlus, "Aditi voice requires Pro Plus plan")
        }
        if let joanna = voices.first(where: { $0.name == "Joanna" }) {
            assert(joanna.requiresPlan == .pro, "Joanna voice requires Pro plan")
        }
        
        // MARK: - 4. API Endpoints Path Tests
        print("▶️ Testing API Endpoints Construction...")
        assert(APIEndpoint.login.path == "/api/auth/login", "Login endpoint matches contract (/api/auth/login)")
        assert(APIEndpoint.synthesize.path == "/api/tts/synthesize", "TTS synthesize endpoint matches contract (/api/tts/synthesize)")
        assert(APIEndpoint.voices.path == "/api/tts/voices", "TTS voices endpoint matches contract (/api/tts/voices)")
        assert(APIEndpoint.transcribeLive.path == "/api/stt/transcribe-live", "STT live endpoint matches contract (/api/stt/transcribe-live)")
        assert(APIEndpoint.transcribeFile.path == "/api/stt/transcribe", "STT file endpoint matches contract (/api/stt/transcribe)")
        assert(APIEndpoint.clearAllHistory.path == "/api/history/clear-all", "Clear all history endpoint matches contract (/api/history/clear-all)")
        assert(APIEndpoint.deleteHistory.path == "/api/history/delete", "Delete history endpoint matches contract (/api/history/delete)")
        assert(APIEndpoint.deleteAccount.path == "/api/v1/users/me", "Account deletion endpoint matches contract (/api/v1/users/me)")
        
        // MARK: - 5. Transcription Result Model Tests
        print("▶️ Testing Transcription Result Calculations...")
        let sampleResult = TranscriptionResult.sample
        assert(sampleResult.wordCount == 39, "Sample transcription result word count matches design pack (39 words)")
        assert(sampleResult.durationSeconds == 12, "Sample transcription result duration is 12 seconds")
        
        print("\n==========================================")
        print("🏁 [TEST SUITE SUMMARY]: \(passedCount) Passed, \(failedCount) Failed")
        print("==========================================\n")
        
        return failedCount == 0
    }
}
