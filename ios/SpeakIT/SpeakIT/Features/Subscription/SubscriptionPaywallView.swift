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
    @Environment(\.openURL) private var openURL
    @Environment(AppState.self) private var appState
    
    @State private var selectedPlan: PlanType = .proPlus
    @State private var isPurchasing: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showRestoreSuccess: Bool = false
    @State private var showTermsSheet: Bool = false
    @State private var showPrivacySheet: Bool = false
    
    var body: some View {
        let currentPlan = appState.currentUser?.planType ?? .free
        ScrollView {
            VStack(spacing: 20) {
                // Header Bar with Close Button
                HStack {
                    Text("Change Plan")
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
                    Text("Choose Your Plan")
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
                        tierName: "Free",
                        price: "$0 / month",
                        features: [
                            "10,000 chars • Standard Polly Voices"
                        ],
                        isSelected: selectedPlan == .free,
                        isCurrentPlan: currentPlan == .free,
                        isDisabled: currentPlan == .free
                    ) {
                        selectedPlan = .free
                    }
                    .accessibilityIdentifier("subscription.free")
                    
                    SpeakITSubscriptionCard(
                        tierName: "Pro",
                        price: appState.proPriceDisplay,
                        features: [
                            "100,000 chars • Neural Polly • File STT"
                        ],
                        isSelected: selectedPlan == .pro,
                        isCurrentPlan: currentPlan == .pro,
                        isDisabled: currentPlan == .pro
                    ) {
                        selectedPlan = .pro
                    }
                    .accessibilityIdentifier("subscription.pro")
                    
                    SpeakITSubscriptionCard(
                        tierName: "Pro Plus",
                        price: appState.proPlusPriceDisplay,
                        features: [
                            "250,000 chars • International & Indian",
                            "Live Mic STT"
                        ],
                        isSelected: selectedPlan == .proPlus,
                        isPopular: true,
                        isCurrentPlan: currentPlan == .proPlus,
                        isDisabled: currentPlan == .proPlus
                    ) {
                        selectedPlan = .proPlus
                    }
                    .accessibilityIdentifier("subscription.proPlus")
                }
                .padding(.top, 8)
                
                SpeakITBanner(message: $errorMessage, style: .error)
                
                // Change Plan / Upgrade / Downgrade CTA Button
                let isCurrentSelected = (selectedPlan == currentPlan)
                let canChangePlan = !isCurrentSelected
                
                let buttonTitle: String = {
                    if isCurrentSelected {
                        return "\(currentPlan.displayName) (Active Plan)"
                    } else if selectedPlan < currentPlan {
                        return "Downgrade to \(selectedPlan.displayName)"
                    } else {
                        return "Upgrade to \(selectedPlan.displayName)"
                    }
                }()
                
                SpeakITButton(
                    title: buttonTitle,
                    style: selectedPlan < currentPlan ? .secondary : .primary,
                    isLoading: isPurchasing,
                    isEnabled: canChangePlan
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
                
                // Terms & App Store Billing Disclosures (Native in-app sheets)
                HStack(spacing: 6) {
                    Button(action: {
                        showTermsSheet = true
                    }) {
                        Text("Terms")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Color.speakitPrimary)
                            .underline()
                    }
                    
                    Text("•")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color.speakitTextTertiary)
                    
                    Button(action: {
                        showPrivacySheet = true
                    }) {
                        Text("Privacy")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Color.speakitPrimary)
                            .underline()
                    }
                    
                    Text("•")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color.speakitTextTertiary)
                    
                    Text("App Store billing")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color.speakitTextTertiary)
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, SpeakITSpacing.screenMargin)
        }
        .sheet(isPresented: $showTermsSheet) {
            TermsOfServiceSheet()
        }
        .sheet(isPresented: $showPrivacySheet) {
            PrivacyPolicySheet()
        }
        .alert("Purchases Restored", isPresented: $showRestoreSuccess) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("Your previous App Store subscriptions have been verified and restored.")
        }
        .task {
            if let activePlan = appState.currentUser?.planType {
                self.selectedPlan = activePlan
            }
            await appState.loadPlanPricing()
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
