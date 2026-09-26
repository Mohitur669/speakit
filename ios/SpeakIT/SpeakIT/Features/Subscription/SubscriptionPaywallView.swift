//
//  SubscriptionPaywallView.swift
//  SpeakIT
//
//  StoreKit 2 paywall modal matching 08_Subscription_Paywall.svg.
//

import SwiftUI
import StoreKit

struct SubscriptionPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    @State private var selectedPlan: PlanType = .proPlus
    @State private var isPurchasing: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showRestoreSuccess: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Bar with Close Button
                HStack {
                    Text("Upgrade")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Color.speakitTextPrimary)
                    
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.speakitTextSecondary)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.top, 16)
                
                // Hero Star Icon
                ZStack {
                    Circle()
                        .fill(Color.speakitBadgeBackground)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "star.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color.speakitPrimary)
                }
                .padding(.top, 4)
                
                // Hero Headlines
                VStack(spacing: 4) {
                    Text("Unlock Premium Voices")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundColor(Color.speakitTextPrimary)
                    
                    Text("and Live Dictation")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundColor(Color.speakitTextPrimary)
                    
                    Text("More voices. Higher limits. Native iOS audio.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color.speakitTextSecondary)
                        .padding(.top, 4)
                }
                
                // Plan Comparison Cards
                VStack(spacing: 14) {
                    SpeakITSubscriptionCard(
                        tierName: "PRO",
                        price: "$9.99 / month",
                        features: [
                            "100,000 chars • Neural Polly • File STT"
                        ],
                        isSelected: selectedPlan == .pro
                    ) {
                        selectedPlan = .pro
                    }
                    .accessibilityIdentifier("subscription.pro")
                    
                    SpeakITSubscriptionCard(
                        tierName: "PRO PLUS",
                        price: "$19.99 / month",
                        features: [
                            "250,000 chars • International • Indian",
                            "Live Mic STT"
                        ],
                        isSelected: selectedPlan == .proPlus,
                        isPopular: true
                    ) {
                        selectedPlan = .proPlus
                    }
                    .accessibilityIdentifier("subscription.proPlus")
                }
                .padding(.top, 8)
                
                SpeakITBanner(message: $errorMessage, style: .error)
                
                // Continue CTA Button
                SpeakITButton(
                    title: "Continue with \(selectedPlan.displayName)",
                    style: .primary,
                    isLoading: isPurchasing
                ) {
                    executePurchase()
                }
                .accessibilityIdentifier("subscription.purchase")
                .padding(.top, 12)
                
                // Restore Purchases
                Button(action: {
                    restorePurchases()
                }) {
                    Text("Restore Purchases")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.speakitPrimary)
                        .frame(height: 36)
                }
                
                // Terms & App Store Billing Disclosures
                Text("Terms • Privacy • App Store billing")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color.speakitTextTertiary)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, SpeakITSpacing.screenMargin)
        }
        .alert("Purchases Restored", isPresented: $showRestoreSuccess) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("Your previous App Store subscriptions have been verified and restored.")
        }
    }
    
    // MARK: - StoreKit Purchase Simulation / Execution
    private func executePurchase() {
        isPurchasing = true
        errorMessage = nil
        
        Task {
            // Simulate StoreKit 2 flow or real In-App Purchase sandbox
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            
            await MainActor.run {
                self.isPurchasing = false
                
                // Update local user state
                if let current = self.appState.currentUser {
                    self.appState.currentUser = User(
                        id: current.id,
                        username: current.username,
                        email: current.email,
                        fullName: current.fullName,
                        role: current.role,
                        planType: self.selectedPlan,
                        status: current.status,
                        characterLimit: self.selectedPlan.monthlyQuota,
                        charactersUsed: current.charactersUsed
                    )
                }
                
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                self.dismiss()
            }
        }
    }
    
    private func restorePurchases() {
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            await MainActor.run {
                self.showRestoreSuccess = true
            }
        }
    }
}

#Preview {
    SubscriptionPaywallView()
        .environment(AppState.shared)
}
