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
    @State private var showCancelAlert: Bool = false
    @State private var showContactSheet: Bool = false
    @State private var activeOrder: PaymentOrderResponse? = nil
    @State private var prorationQuote: ProrationQuoteResponse? = nil
    
    var body: some View {
        let currentPlan = appState.currentUser?.planType ?? .free
        ScrollView {
            VStack(spacing: 20) {
                // Header Bar with Close Button
                HStack {
                    Text("Manage Subscription")
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
                        price: appState.freePriceDisplay,
                        features: [
                            "\(appState.formattedMaxCharacters(for: .free)) characters per request",
                            "\(appState.formattedMonthlyQuota(for: .free)) monthly character quota",
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
                            "\(appState.formattedMaxCharacters(for: .pro)) characters per request",
                            "\(appState.formattedMonthlyQuota(for: .pro)) monthly character quota",
                            "Neural Polly AI Voices • File STT"
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
                            "\(appState.formattedMaxCharacters(for: .proPlus)) characters per request",
                            "\(appState.formattedMonthlyQuota(for: .proPlus)) monthly character quota",
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
                    
                    SpeakITSubscriptionCard(
                        tierName: "Enterprise",
                        price: "Contact Us",
                        features: [
                            "\(appState.formattedMaxCharacters(for: .enterprise)) characters per request",
                            "\(appState.formattedMonthlyQuota(for: .enterprise)) monthly character quota",
                            "Dedicated support • Custom models & all engines"
                        ],
                        isSelected: selectedPlan == .enterprise,
                        isCurrentPlan: currentPlan == .enterprise,
                        isDisabled: currentPlan == .enterprise
                    ) {
                        selectedPlan = .enterprise
                    }
                    .accessibilityIdentifier("subscription.enterprise")
                }
                .padding(.top, 8)
                
                // Change Plan / Upgrade / Downgrade CTA Button
                let isCurrentSelected = (selectedPlan == currentPlan)
                let canChangePlan = !isCurrentSelected
                
                let buttonTitle: String = {
                    if isCurrentSelected {
                        return "\(currentPlan.displayName) (Active Plan)"
                    } else if selectedPlan == .enterprise {
                        return "Contact Us for Enterprise"
                    } else if selectedPlan < currentPlan {
                        return "Downgrade to \(selectedPlan.displayName)"
                    } else {
                        if let quote = prorationQuote, quote.isUpgrade, quote.unusedCredit > 0 {
                            let currSymbol = quote.currency.uppercased() == "INR" ? "₹" : "$"
                            return "Upgrade to \(selectedPlan.displayName) • Pay \(currSymbol)\(Int(quote.amountToPay)) today"
                        }
                        let price: String
                        switch selectedPlan {
                        case .pro: price = appState.proPriceDisplay
                        case .proPlus: price = appState.proPlusPriceDisplay
                        default: price = ""
                        }
                        return price.isEmpty ? "Select \(selectedPlan.displayName)" : "Upgrade to \(selectedPlan.displayName) • \(price)"
                    }
                }()
                
                // Credit adjustment banner for active upgrades
                if let quote = prorationQuote, quote.isUpgrade, quote.unusedCredit > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.speakitPrimary)
                        
                        let currSymbol = quote.currency.uppercased() == "INR" ? "₹" : "$"
                        Text("\(currSymbol)\(Int(quote.unusedCredit)) credit applied from your \(currentPlan.displayName) plan (\(quote.remainingDays) days remaining).")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.speakitTextPrimary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.speakitPrimary.opacity(0.08))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.speakitPrimary.opacity(0.2), lineWidth: 1)
                    )
                }
                
                SpeakITButton(
                    title: buttonTitle,
                    icon: selectedPlan == .enterprise ? "envelope.fill" : (selectedPlan < currentPlan ? nil : "sparkles"),
                    style: .primary,
                    isLoading: isPurchasing,
                    isEnabled: canChangePlan
                ) {
                    handlePlanAction()
                }
                .accessibilityIdentifier("subscription.purchase")
                .padding(.top, 12)
                
                // Secondary Option: Manage on Web — hidden for Enterprise (uses Contact Us flow instead)
                // Passes selected plan as query param so Angular can auto-trigger the correct checkout.
                if selectedPlan != .enterprise {
                    Button(action: {
                        HapticManager.shared.light()
                        let planParam = selectedPlan.rawValue.uppercased() // e.g. "PRO", "PRO_PLUS", "FREE"
                        let urlString = "\(appState.managePlanUrlWeb)?plan=\(planParam)"
                        if let url = URL(string: urlString) {
                            openURL(url)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "globe")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Prefer Web Checkout? Manage on Web")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(Color.speakitPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.speakitBadgeBackground)
                        .cornerRadius(SpeakITSpacing.buttonRadius)
                    }
                    .accessibilityIdentifier("subscription.manageOnWeb")
                }
                
                // Cancel Subscription Option (Inside Manage Subscription for active paid tiers)
                if currentPlan != .free {
                    Button(action: {
                        HapticManager.shared.light()
                        showCancelAlert = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Cancel Subscription")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(Color.speakitError)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.speakitError.opacity(0.08))
                        .cornerRadius(SpeakITSpacing.buttonRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: SpeakITSpacing.buttonRadius)
                                .stroke(Color.speakitError.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .accessibilityIdentifier("subscription.cancel")
                }
                
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
        .sheet(isPresented: $showContactSheet) {
            ContactSupportSheet(initialTopicKey: "enterprise")
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
        .alert(selectedPlan == .free ? "Downgrade to Free Tier" : "Downgrade to \(selectedPlan.displayName)", isPresented: $showDowngradeAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Downgrade", role: .destructive) {
                executeDowngrade(to: selectedPlan)
            }
        } message: {
            if selectedPlan == .free {
                Text("Are you sure you want to downgrade to Free? You will lose access to neural and Indian AI voices immediately.")
            } else {
                Text("Are you sure you want to downgrade to \(selectedPlan.displayName)? Your \(currentPlan.displayName) features remain active until \(appState.currentUser?.formattedExpiry ?? "the end of your billing cycle").")
            }
        }
        .alert("Cancel Subscription?", isPresented: $showCancelAlert) {
            Button("Keep Subscription", role: .cancel) {}
            Button("Cancel Auto-Renewal", role: .destructive) {
                executeCancelSubscription()
            }
        } message: {
            let planName = currentPlan.displayName
            let expiry = appState.currentUser?.formattedExpiry ?? "the end of your current period"
            Text("Are you sure you want to turn off auto-renewal for your \(planName) plan? You will retain all your paid benefits until \(expiry).")
        }
        .task {
            if let activePlan = appState.currentUser?.planType {
                self.selectedPlan = activePlan
            }
            await appState.loadPlanPricing()
            await StoreKitService.shared.loadProducts()
            fetchProrationQuote(for: selectedPlan)
        }
        .onChange(of: selectedPlan) { _, newPlan in
            fetchProrationQuote(for: newPlan)
        }
        .speakITToast(message: $errorMessage, style: .error, bottomPadding: 20)
    }
    
    // MARK: - Plan Change Handler
    private func handlePlanAction() {
        errorMessage = nil
        let currentPlan = appState.currentUser?.planType ?? .free
        
        if selectedPlan == .enterprise {
            HapticManager.shared.selection()
            showContactSheet = true
            return
        }
        
        if selectedPlan < currentPlan {
            showDowngradeAlert = true
            return
        }
        
        // Primary: In-App Purchase via StoreKit 2
        executeStoreKitPurchase(for: selectedPlan)
    }
    
    private func fetchProrationQuote(for plan: PlanType) {
        let currentPlan = appState.currentUser?.planType ?? .free
        guard plan > currentPlan, currentPlan != .free else {
            self.prorationQuote = nil
            return
        }
        Task {
            do {
                let quote = try await PaymentService.shared.getProrationQuote(targetPlan: plan, currency: "INR")
                await MainActor.run {
                    self.prorationQuote = quote
                }
            } catch {
                print("Notice: Could not fetch proration quote: \(error)")
            }
        }
    }
    
    private func executeStoreKitPurchase(for plan: PlanType) {
        isPurchasing = true
        errorMessage = nil
        
        Task {
            do {
                if let product = StoreKitService.shared.product(for: plan) {
                    _ = try await StoreKitService.shared.purchase(product)
                    await appState.loadCurrentUser()
                    await MainActor.run {
                        self.isPurchasing = false
                        HapticManager.shared.success()
                        self.dismiss()
                    }
                } else {
                    // Try to reload products once
                    await StoreKitService.shared.loadProducts()
                    if let product = StoreKitService.shared.product(for: plan) {
                        _ = try await StoreKitService.shared.purchase(product)
                        await appState.loadCurrentUser()
                        await MainActor.run {
                            self.isPurchasing = false
                            HapticManager.shared.success()
                            self.dismiss()
                        }
                    } else {
                        await MainActor.run {
                            self.isPurchasing = false
                            self.errorMessage = "StoreKit product not found. You can also manage your plan on the web."
                            HapticManager.shared.error()
                        }
                    }
                }
            } catch StoreKitError.userCancelled {
                await MainActor.run {
                    self.isPurchasing = false
                }
            } catch {
                await MainActor.run {
                    self.isPurchasing = false
                    self.errorMessage = error.localizedDescription
                    HapticManager.shared.error()
                }
            }
        }
    }
    
    private func executeDowngrade(to plan: PlanType) {
        isPurchasing = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await PaymentService.shared.downgrade(to: plan)
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
    
    private func executeCancelSubscription() {
        isPurchasing = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await PaymentService.shared.cancelSubscription()
                await appState.loadCurrentUser()
                
                await MainActor.run {
                    self.isPurchasing = false
                    HapticManager.shared.success()
                    self.dismiss()
                }
            } catch {
                await MainActor.run {
                    self.isPurchasing = false
                    self.errorMessage = (error as? APIError)?.errorDescription ?? "Failed to cancel subscription."
                    HapticManager.shared.error()
                }
            }
        }
    }
    
    private func restorePurchases() {
        Task {
            do {
                try await StoreKitService.shared.restorePurchases()
                await appState.loadCurrentUser()
                await MainActor.run {
                    self.showRestoreSuccess = true
                    HapticManager.shared.success()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to restore StoreKit purchases."
                    HapticManager.shared.error()
                }
            }
        }
    }
}

#Preview {
    SubscriptionPaywallView()
        .environment(AppState.shared)
}
