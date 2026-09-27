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
    @State private var showDowngradeAlert: Bool = false
    @State private var activeOrder: PaymentOrderResponse? = nil
    
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
                
                // Current Plan Validity Card (if active subscription exists)
                if currentPlan != .free, let expiry = appState.currentUser?.formattedExpiry {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 20))
                            .foregroundColor(Color.speakitPrimary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current: \(currentPlan.displayName) Plan")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.speakitTextPrimary)
                            
                            Text("Valid until \(expiry) • \(appState.currentUser?.daysRemaining ?? 0) days remaining")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.speakitSuccess)
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.speakitPrimary.opacity(0.08))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.speakitPrimary.opacity(0.2), lineWidth: 1)
                    )
                }
                
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
                            "100 chars/request • 10,000 monthly chars",
                            "5 daily syntheses • Standard Polly Voices"
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
                            "200 chars/request • 100,000 monthly chars",
                            "Neural Polly • File STT"
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
                            "500 chars/request • 250,000 monthly chars",
                            "ElevenLabs & Indian Voices • Live Mic STT"
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
                
                // Change Plan / Upgrade / Downgrade CTA Button
                let isCurrentSelected = (selectedPlan == currentPlan)
                let canChangePlan = !isCurrentSelected
                
                let buttonTitle: String = {
                    if isCurrentSelected {
                        return "\(currentPlan.displayName) (Active Plan)"
                    } else if selectedPlan < currentPlan {
                        return "Downgrade to \(selectedPlan.displayName)"
                    } else {
                        let price = selectedPlan == .pro ? appState.proPriceDisplay : appState.proPlusPriceDisplay
                        return "Upgrade to \(selectedPlan.displayName) • \(price)"
                    }
                }()
                
                SpeakITButton(
                    title: buttonTitle,
                    style: selectedPlan < currentPlan ? .secondary : .primary,
                    isLoading: isPurchasing,
                    isEnabled: canChangePlan
                ) {
                    handlePlanAction()
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
        .background(Color.speakitScreenBackground.ignoresSafeArea())
        .sheet(isPresented: $showTermsSheet) {
            TermsOfServiceSheet()
        }
        .sheet(isPresented: $showPrivacySheet) {
            PrivacyPolicySheet()
        }
        .sheet(item: $activeOrder) { order in
            PaymentCheckoutSheet(plan: selectedPlan, order: order) {
                dismiss()
            }
        }
        .alert("Purchases Restored", isPresented: $showRestoreSuccess) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("Your previous subscriptions and plan validity have been verified and restored from backend.")
        }
        .alert("Downgrade to Free Tier", isPresented: $showDowngradeAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Downgrade", role: .destructive) {
                executeDowngrade()
            }
        } message: {
            Text("Are you sure you want to downgrade to Free? You will lose access to neural and Indian AI voices immediately.")
        }
        .task {
            if let activePlan = appState.currentUser?.planType {
                self.selectedPlan = activePlan
            }
            await appState.loadPlanPricing()
        }
        .speakITToast(message: $errorMessage, style: .error, bottomPadding: 20)
    }
    
    // MARK: - Plan Change Handler
    private func handlePlanAction() {
        errorMessage = nil
        let currentPlan = appState.currentUser?.planType ?? .free
        
        if selectedPlan == .free && currentPlan != .free {
            showDowngradeAlert = true
            return
        }
        
        // Upgrade flow: Create order on backend first
        executeCreateOrder()
    }
    
    private func executeCreateOrder() {
        isPurchasing = true
        errorMessage = nil
        
        Task {
            do {
                let amount = selectedPlan == .pro ? appState.proAmountINR : appState.proPlusAmountINR
                let orderResponse = try await PaymentService.shared.createOrder(
                    plan: selectedPlan,
                    amount: amount,
                    currency: "INR"
                )
                
                await MainActor.run {
                    self.isPurchasing = false
                    self.activeOrder = orderResponse
                }
            } catch {
                await MainActor.run {
                    self.isPurchasing = false
                    self.errorMessage = (error as? APIError)?.errorDescription ?? "Failed to initialize payment order. Please try again."
                    HapticManager.shared.error()
                }
            }
        }
    }
    
    private func executeDowngrade() {
        isPurchasing = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await PaymentService.shared.downgradeToFree()
                await appState.loadCurrentUser()
                
                await MainActor.run {
                    self.isPurchasing = false
                    HapticManager.shared.success()
                    self.dismiss()
                }
            } catch {
                await MainActor.run {
                    self.isPurchasing = false
                    self.errorMessage = (error as? APIError)?.errorDescription ?? "Failed to downgrade plan."
                    HapticManager.shared.error()
                }
            }
        }
    }
    
    private func restorePurchases() {
        Task {
            await appState.loadCurrentUser()
            await MainActor.run {
                self.showRestoreSuccess = true
                HapticManager.shared.success()
            }
        }
    }
}

#Preview {
    SubscriptionPaywallView()
        .environment(AppState.shared)
}
