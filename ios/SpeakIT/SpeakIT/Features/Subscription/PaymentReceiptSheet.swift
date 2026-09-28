//
//  PaymentReceiptSheet.swift
//  SpeakIT
//
//  Native Apple-style payment receipt and invoice viewer for subscription transactions with single PDF export.
//

import SwiftUI
import PDFKit

struct PaymentReceiptSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    let item: PaymentHistoryItem
    
    @State private var copiedOrderId: Bool = false
    @State private var pdfURL: URL? = nil
    @State private var showPDFPreview: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Brand & Status Pill
                    receiptHeader
                    
                    // Main Invoice Card
                    receiptCard
                    
                    // Share / Export PDF Section
                    shareSection
                }
                .padding(.horizontal, SpeakITSpacing.screenMargin)
                .padding(.top, 16)
                .padding(.bottom, 36)
            }
            .background(Color.speakitScreenBackground.ignoresSafeArea())
            .navigationTitle("Payment Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        HapticManager.shared.selection()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.speakitPrimary)
                }
            }
            .task {
                preparePDF()
            }
            .sheet(isPresented: $showPDFPreview) {
                if let url = pdfURL {
                    NavigationStack {
                        PDFKitView(url: url)
                            .navigationTitle(item.receiptNumber)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Close") {
                                        showPDFPreview = false
                                    }
                                }
                                ToolbarItem(placement: .confirmationAction) {
                                    ShareLink(
                                        item: url,
                                        preview: SharePreview("SpeakIT Receipt \(item.receiptNumber)", image: Image(systemName: "doc.text.fill"))
                                    ) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(Color.speakitPrimary)
                                    }
                                }
                            }
                    }
                }
            }
        }
    }
    
    // MARK: - Header
    @ViewBuilder
    private var receiptHeader: some View {
        let statusColor: Color = item.isSuccess ? Color.speakitSuccess : (item.isPending ? Color.speakitWarning : Color.speakitError)
        let statusIcon: String = item.isSuccess ? "checkmark.seal.fill" : (item.isPending ? "clock.fill" : "xmark.seal.fill")
        
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.14))
                    .frame(width: 64, height: 64)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 32))
                    .foregroundColor(statusColor)
            }
            
            Text(item.statusTitle)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.speakitTextPrimary)
            
            Text(item.formattedAmount)
                .font(.system(size: 34, weight: .heavy))
                .foregroundColor(Color.speakitTextPrimary)
            
            Text(item.statusDescription)
                .font(.system(size: 12))
                .foregroundColor(Color.speakitTextSecondary)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Receipt Details Card
    @ViewBuilder
    private var receiptCard: some View {
        VStack(spacing: 16) {
            // Receipt Number & Status Banner
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RECEIPT NUMBER")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.speakitTextTertiary)
                    Text(item.receiptNumber)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.speakitTextPrimary)
                }
                
                Spacer()
                
                let statusColor: Color = item.isSuccess ? Color.speakitSuccess : (item.isPending ? Color.speakitWarning : Color.speakitError)
                Text(item.status)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12))
                    .cornerRadius(8)
            }
            
            Divider()
                .background(Color.speakitBorder)
            
            // Transaction Details Grid
            VStack(spacing: 12) {
                receiptRow(title: "Plan", value: "\(item.displayPlanName) Subscription")
                
                if let name = appState.currentUser?.fullName, !name.isEmpty {
                    receiptRow(title: "Billed To", value: name)
                }
                
                if let email = appState.currentUser?.email, !email.isEmpty {
                    receiptRow(title: "Account Email", value: email)
                }
                
                receiptRow(title: "Billing Cycle", value: "1 Month (Auto-Renewable)")
                
                if let orderId = item.razorpayOrderId {
                    HStack(alignment: .top) {
                        Text("Order Reference")
                            .font(.system(size: 13))
                            .foregroundColor(Color.speakitTextSecondary)
                        Spacer()
                        Button(action: {
                            UIPasteboard.general.string = orderId
                            HapticManager.shared.success()
                            copiedOrderId = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copiedOrderId = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(orderId)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(Color.speakitTextPrimary)
                                    .lineLimit(1)
                                
                                Image(systemName: copiedOrderId ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 11))
                                    .foregroundColor(copiedOrderId ? Color.speakitSuccess : Color.speakitPrimary)
                            }
                        }
                    }
                }
                
                receiptRow(title: "Payment Method", value: "Secure Payment Gateway")
            }
            
            Divider()
                .background(Color.speakitBorder)
            
            // Line Items Breakdown
            VStack(spacing: 8) {
                HStack {
                    Text("\(item.displayPlanName) Plan Membership")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.speakitTextPrimary)
                    Spacer()
                    Text(item.formattedAmount)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.speakitTextPrimary)
                }
                
                HStack {
                    Text("Taxes & Fees")
                        .font(.system(size: 12))
                        .foregroundColor(Color.speakitTextSecondary)
                    Spacer()
                    Text("Included")
                        .font(.system(size: 12))
                        .foregroundColor(Color.speakitTextSecondary)
                }
                
                Divider()
                    .background(Color.speakitBorder.opacity(0.5))
                
                HStack {
                    Text(item.isSuccess ? "Total Paid" : (item.isPending ? "Amount Due" : "Amount"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.speakitTextPrimary)
                    Spacer()
                    Text(item.formattedAmount)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color.speakitPrimary)
                }
                .padding(.top, 4)
            }
        }
        .padding(18)
        .background(Color.speakitCardSurface)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.speakitBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
    }
    
    // MARK: - Share Section (Single PDF Export)
    @ViewBuilder
    private var shareSection: some View {
        VStack(spacing: 12) {
            if let url = pdfURL {
                ShareLink(
                    item: url,
                    preview: SharePreview("SpeakIT Receipt \(item.receiptNumber)", image: Image(systemName: "doc.text.fill"))
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Export PDF Receipt")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.speakitPrimary)
                    .cornerRadius(14)
                    .shadow(color: Color.speakitPrimary.opacity(0.3), radius: 8, y: 3)
                }
                
                Button(action: {
                    HapticManager.shared.selection()
                    showPDFPreview = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Preview PDF Document")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(Color.speakitPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.speakitBadgeBackground)
                    .cornerRadius(12)
                }
            } else {
                ProgressView("Generating PDF...")
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            
            Text("Exports a single, official vector PDF invoice document matching your transaction details.")
                .font(.system(size: 11))
                .foregroundColor(Color.speakitTextTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
    }
    
    @ViewBuilder
    private func receiptRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(Color.speakitTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.speakitTextPrimary)
        }
    }
    
    private func preparePDF() {
        if pdfURL == nil {
            pdfURL = PaymentReceiptPDFGenerator.generatePDF(item: item, user: appState.currentUser)
        }
    }
}

// MARK: - In-App PDF Viewer
struct PDFKitView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.backgroundColor = UIColor.systemGroupedBackground
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}
