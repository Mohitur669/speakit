//
//  BillingHistorySheet.swift
//  SpeakIT
//
//  Sheet displaying past payment and subscription history matching backend payments/history endpoint.
//

import SwiftUI

struct BillingHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var items: [PaymentHistoryItem] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var selectedReceiptItem: PaymentHistoryItem? = nil
    @State private var sheetDetent: PresentationDetent = .medium
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading payment history...")
                            .font(.system(size: 13))
                            .foregroundColor(Color.speakitTextSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundColor(Color.speakitError)
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(Color.speakitTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        Button("Retry") {
                            loadHistory()
                        }
                        .foregroundColor(Color.speakitPrimary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 40))
                            .foregroundColor(Color.speakitTextTertiary)
                        Text("No Billing History")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.speakitTextPrimary)
                        Text("Your subscription payments and invoices will appear here.")
                            .font(.system(size: 13))
                            .foregroundColor(Color.speakitTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(items) { item in
                            historyRow(item)
                                .listRowBackground(Color.speakitCardSurface)
                                .listRowSeparatorTint(Color.speakitBorder)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.speakitScreenBackground.ignoresSafeArea())
            .navigationTitle("Billing History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color.speakitPrimary)
                }
            }
            .task {
                loadHistory()
            }
            .sheet(item: $selectedReceiptItem) { receiptItem in
                PaymentReceiptSheet(item: receiptItem)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .presentationDetents([.medium, .large], selection: $sheetDetent)
        .presentationDragIndicator(.visible)
    }
    
    @ViewBuilder
    private func historyRow(_ item: PaymentHistoryItem) -> some View {
        Button(action: {
            HapticManager.shared.selection()
            selectedReceiptItem = item
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(item.status == "SUCCESS" ? Color.speakitSuccess.opacity(0.12) : Color.speakitTextTertiary.opacity(0.12))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: item.status == "SUCCESS" ? "checkmark" : "clock")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(item.status == "SUCCESS" ? Color.speakitSuccess : Color.speakitTextTertiary)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(item.displayPlanName) Subscription")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.speakitTextPrimary)
                    
                    Text(item.formattedDate)
                        .font(.system(size: 11))
                        .foregroundColor(Color.speakitTextSecondary)
                    
                    if let orderId = item.razorpayOrderId {
                        Text(orderId)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color.speakitTextTertiary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(item.formattedAmount)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.speakitTextPrimary)
                    
                    HStack(spacing: 4) {
                        Text(item.status)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(item.status == "SUCCESS" ? Color.speakitSuccess : Color.speakitWarning)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color.speakitTextTertiary)
                    }
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func loadHistory() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let history = try await PaymentService.shared.getPaymentHistory()
                await MainActor.run {
                    self.items = history
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = (error as? APIError)?.errorDescription ?? "Failed to load billing history"
                    self.isLoading = false
                }
            }
        }
    }
}
