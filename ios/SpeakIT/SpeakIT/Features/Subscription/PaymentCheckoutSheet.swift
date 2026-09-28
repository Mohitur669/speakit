//
//  PaymentCheckoutSheet.swift
//  SpeakIT
//
//  Native payment checkout and verification sheet matching backend payment orchestration.
//

import SwiftUI

struct PaymentCheckoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    let plan: PlanType
    let order: PaymentOrderResponse
    let onSuccess: () -> Void
    
    @State private var selectedPaymentMethod: String = "UPI"
    @State private var isProcessing: Bool = false
    @State private var isCompleted: Bool = false
    @State private var errorMessage: String? = nil
    
    private var validityStartDate: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df.string(from: Date())
    }
    
    private var validityEndDate: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        return df.string(from: nextMonth)
    }
    
    private var displayAmount: String {
        if order.currency.uppercased() == "INR" {
            return "₹\(order.amount / 100)"
        }
        return "\(order.currency) \(order.amount / 100)"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isCompleted {
                        successView
                    } else {
                        checkoutContent
                    }
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
                .padding(.vertical, 16)
            }
            .background(Color.speakitScreenBackground.ignoresSafeArea())
            .navigationTitle(isCompleted ? "Payment Complete" : "Checkout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !isProcessing && !isCompleted {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(Color.speakitTextSecondary)
                    }
                }
            }
            .speakITToast(message: $errorMessage, style: .error, bottomPadding: 20)
        }
    }
    
    // MARK: - Checkout Form
    @ViewBuilder
    private var checkoutContent: some View {
        // Order Summary Card
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ORDER SUMMARY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.speakitTextTertiary)
                    
                    Text("\(plan.displayName) Plan")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.speakitTextPrimary)
                }
                
                Spacer()
                
                Text(displayAmount)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(Color.speakitPrimary)
            }
            
            Divider()
                .background(Color.speakitBorder)
            
            // Validity Calculation Preview
            VStack(spacing: 8) {
                HStack {
                    Label("Billing Period", systemImage: "calendar")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.speakitTextSecondary)
                    Spacer()
                    Text("1 Month (Monthly)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.speakitTextPrimary)
                }
                
                HStack {
                    Label("Subscription Validity", systemImage: "clock.badge.checkmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.speakitTextSecondary)
                    Spacer()
                    Text("\(validityStartDate) – \(validityEndDate)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.speakitSuccess)
                }
                
                HStack {
                    Label("Monthly Quota", systemImage: "waveform")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.speakitTextSecondary)
                    Spacer()
                    Text("\(appState.formattedMonthlyQuota(for: plan)) chars")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.speakitTextPrimary)
                }
                
                HStack {
                    Label("Order Ref", systemImage: "number")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.speakitTextSecondary)
                    Spacer()
                    Text(order.subscriptionId)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(Color.speakitTextTertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(18)
        .background(Color.speakitCardSurface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.speakitBorder, lineWidth: 1)
        )
        
        // Payment Method Selector
        VStack(alignment: .leading, spacing: 12) {
            Text("SELECT PAYMENT METHOD")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.speakitTextTertiary)
                .padding(.leading, 4)
            
            VStack(spacing: 8) {
                paymentMethodRow(id: "UPI", title: "UPI (Google Pay, PhonePe, Paytm)", icon: "qrcode")
                paymentMethodRow(id: "CARD", title: "Credit or Debit Card", icon: "creditcard.fill")
                paymentMethodRow(id: "NETBANKING", title: "Net Banking", icon: "building.columns.fill")
            }
        }
        
        // Security Trust Badge
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 14))
                .foregroundColor(Color.speakitSuccess)
            
            Text("256-Bit SSL Encrypted • Verified by SpeakIT Payment Gateway")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.speakitTextTertiary)
        }
        .padding(.vertical, 4)
        
        // Confirm & Pay Button
        SpeakITButton(
            title: "Pay \(displayAmount) & Activate",
            icon: "checkmark.circle.fill",
            style: .primary,
            isLoading: isProcessing,
            isEnabled: !isProcessing
        ) {
            processPayment()
        }
        .padding(.top, 6)
    }
    
    // MARK: - Success View
    @ViewBuilder
    private var successView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.speakitSuccess.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Color.speakitSuccess)
            }
            .padding(.top, 24)
            
            VStack(spacing: 6) {
                Text("Subscription Activated!")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color.speakitTextPrimary)
                
                Text("Your account has been upgraded to \(plan.displayName).")
                    .font(.system(size: 14))
                    .foregroundColor(Color.speakitTextSecondary)
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("Plan Tier")
                        .foregroundColor(Color.speakitTextSecondary)
                    Spacer()
                    Text(plan.displayName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.speakitTextPrimary)
                }
                
                HStack {
                    Text("Amount Paid")
                        .foregroundColor(Color.speakitTextSecondary)
                    Spacer()
                    Text(displayAmount)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.speakitTextPrimary)
                }
                
                HStack {
                    Text("Valid Until")
                        .foregroundColor(Color.speakitTextSecondary)
                    Spacer()
                    Text(validityEndDate)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.speakitSuccess)
                }
                
                HStack {
                    Text("Status")
                        .foregroundColor(Color.speakitTextSecondary)
                    Spacer()
                    Text("ACTIVE")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.speakitSuccess)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.speakitSuccess.opacity(0.12))
                        .cornerRadius(6)
                }
            }
            .font(.system(size: 13))
            .padding(16)
            .background(Color.speakitCardSurface)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.speakitBorder, lineWidth: 1)
            )
            
            SpeakITButton(
                title: "Done",
                style: .primary,
                isLoading: false,
                isEnabled: true
            ) {
                dismiss()
            }
            .padding(.top, 10)
        }
    }
    
    // MARK: - Payment Method Row
    @ViewBuilder
    private func paymentMethodRow(id: String, title: String, icon: String) -> some View {
        Button(action: {
            selectedPaymentMethod = id
            HapticManager.shared.light()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(selectedPaymentMethod == id ? Color.speakitPrimary : Color.speakitTextSecondary)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.speakitTextPrimary)
                
                Spacer()
                
                Image(systemName: selectedPaymentMethod == id ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(selectedPaymentMethod == id ? Color.speakitPrimary : Color.speakitTextTertiary)
            }
            .padding(14)
            .background(Color.speakitCardSurface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedPaymentMethod == id ? Color.speakitPrimary : Color.speakitBorder, lineWidth: selectedPaymentMethod == id ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Process Payment & Verify
    private func processPayment() {
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                // Short simulation of payment gateway authorization
                try? await Task.sleep(nanoseconds: 800_000_000)
                
                let simulatedPaymentId = "pay_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(14)
                let simulatedSignature = "sig_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16)
                
                // 1. Verify Payment on Backend
                _ = try await PaymentService.shared.verifyPayment(
                    orderId: order.orderId,
                    subscriptionId: order.subscriptionId,
                    paymentId: simulatedPaymentId,
                    signature: simulatedSignature
                )
                
                // 2. Refresh current user profile (picks up planType, subscriptionStatus, and newly calculated planExpiry)
                await appState.loadCurrentUser()
                
                await MainActor.run {
                    self.isProcessing = false
                    self.isCompleted = true
                    HapticManager.shared.success()
                    self.onSuccess()
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = (error as? APIError)?.errorDescription ?? "Payment verification failed. Please try again."
                    HapticManager.shared.error()
                }
            }
        }
    }
}
