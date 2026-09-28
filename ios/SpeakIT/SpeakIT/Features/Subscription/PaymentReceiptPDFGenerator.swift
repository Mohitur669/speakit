//
//  PaymentReceiptPDFGenerator.swift
//  SpeakIT
//
//  Renders a single, high-fidelity vector PDF receipt for subscription payments.
//

import UIKit

enum PaymentReceiptPDFGenerator {
    static func generatePDF(item: PaymentHistoryItem, user: User?) -> URL? {
        let pageWidth: CGFloat = 595.2 // A4 standard width in points
        let pageHeight: CGFloat = 841.8 // A4 standard height in points
        let margin: CGFloat = 48.0
        let contentWidth = pageWidth - (margin * 2)
        
        let rendererFormat = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: rendererFormat)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            let cgContext = context.cgContext
            
            var currentY: CGFloat = margin
            
            // --- 1. Top Header ---
            let brandName = "SpeakIT"
            let brandFont = UIFont.systemFont(ofSize: 28, weight: .bold)
            let brandColor = UIColor(red: 124/255, green: 58/255, blue: 237/255, alpha: 1.0) // Speakit Primary Purple
            
            let brandAttributes: [NSAttributedString.Key: Any] = [
                .font: brandFont,
                .foregroundColor: brandColor
            ]
            brandName.draw(at: CGPoint(x: margin, y: currentY), withAttributes: brandAttributes)
            
            let subtitle = "AI Voice Studio & Speech-to-Text Platform"
            let subtitleFont = UIFont.systemFont(ofSize: 11, weight: .medium)
            let subtitleColor = UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1.0)
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: subtitleColor
            ]
            subtitle.draw(at: CGPoint(x: margin, y: currentY + 34), withAttributes: subtitleAttributes)
            
            // Right Header: OFFICIAL RECEIPT
            let docType = "OFFICIAL RECEIPT"
            let docTypeFont = UIFont.systemFont(ofSize: 16, weight: .heavy)
            let docTypeColor = UIColor(red: 30/255, green: 41/255, blue: 59/255, alpha: 1.0)
            let docTypeAttributes: [NSAttributedString.Key: Any] = [
                .font: docTypeFont,
                .foregroundColor: docTypeColor
            ]
            let docTypeSize = (docType as NSString).size(withAttributes: docTypeAttributes)
            docType.draw(at: CGPoint(x: pageWidth - margin - docTypeSize.width, y: currentY + 2), withAttributes: docTypeAttributes)
            
            let recNum = item.receiptNumber
            let recNumFont = UIFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
            let recNumAttributes: [NSAttributedString.Key: Any] = [
                .font: recNumFont,
                .foregroundColor: brandColor
            ]
            let recNumSize = (recNum as NSString).size(withAttributes: recNumAttributes)
            recNum.draw(at: CGPoint(x: pageWidth - margin - recNumSize.width, y: currentY + 26), withAttributes: recNumAttributes)
            
            currentY += 70
            
            // --- Divider Line ---
            cgContext.setStrokeColor(UIColor(red: 226/255, green: 232/255, blue: 240/255, alpha: 1.0).cgColor)
            cgContext.setLineWidth(1.0)
            cgContext.move(to: CGPoint(x: margin, y: currentY))
            cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: currentY))
            cgContext.strokePath()
            
            currentY += 24
            
            // --- 2. Two-Column Metadata (Billed To & Payment Summary) ---
            let columnWidth = (contentWidth - 24) / 2
            let col1X = margin
            let col2X = margin + columnWidth + 24
            
            // Column 1: Customer Details
            drawSectionHeader("BILLED TO", at: CGPoint(x: col1X, y: currentY))
            let customerName = (user?.fullName.isEmpty == false) ? user!.fullName : (user?.username ?? "Valued Customer")
            let customerEmail = user?.email.isEmpty == false ? user!.email : "Registered Account"
            
            drawMetaField(label: "Customer Name", value: customerName, x: col1X, y: currentY + 22, width: columnWidth)
            drawMetaField(label: "Account Email", value: customerEmail, x: col1X, y: currentY + 56, width: columnWidth)
            drawMetaField(label: "Platform", value: "iOS Mobile Application", x: col1X, y: currentY + 90, width: columnWidth)
            
            // Column 2: Transaction Details
            drawSectionHeader("PAYMENT DETAILS", at: CGPoint(x: col2X, y: currentY))
            drawMetaField(label: "Billing Date", value: item.formattedDate, x: col2X, y: currentY + 22, width: columnWidth)
            let pdfStatusText: String
            let pdfStatusColor: UIColor
            if item.isSuccess {
                pdfStatusText = "PAID / SUCCESS"
                pdfStatusColor = UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1.0)
            } else if item.isPending {
                pdfStatusText = "PENDING CONFIRMATION"
                pdfStatusColor = UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 1.0)
            } else if item.isFailed {
                pdfStatusText = "FAILED / UNPAID"
                pdfStatusColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0)
            } else {
                pdfStatusText = item.status.uppercased()
                pdfStatusColor = UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1.0)
            }
            drawMetaField(label: "Payment Status", value: pdfStatusText, x: col2X, y: currentY + 56, width: columnWidth, valueColor: pdfStatusColor)
            drawMetaField(label: "Order Reference", value: item.razorpayOrderId ?? "TXN-\(item.id)", x: col2X, y: currentY + 90, width: columnWidth)
            
            currentY += 136
            
            // --- 3. Items Table ---
            let tableHeaderY = currentY
            let tableHeaderHeight: CGFloat = 28
            let tableHeaderRect = CGRect(x: margin, y: tableHeaderY, width: contentWidth, height: tableHeaderHeight)
            
            cgContext.setFillColor(UIColor(red: 248/255, green: 250/255, blue: 252/255, alpha: 1.0).cgColor)
            let path = UIBezierPath(roundedRect: tableHeaderRect, cornerRadius: 6)
            cgContext.addPath(path.cgPath)
            cgContext.fillPath()
            
            let thAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1.0)
            ]
            
            "DESCRIPTION".draw(at: CGPoint(x: margin + 12, y: tableHeaderY + 8), withAttributes: thAttributes)
            "PERIOD".draw(at: CGPoint(x: margin + contentWidth - 170, y: tableHeaderY + 8), withAttributes: thAttributes)
            let amtTitle = "AMOUNT"
            let amtTitleSize = (amtTitle as NSString).size(withAttributes: thAttributes)
            amtTitle.draw(at: CGPoint(x: margin + contentWidth - 12 - amtTitleSize.width, y: tableHeaderY + 8), withAttributes: thAttributes)
            
            currentY += tableHeaderHeight + 14
            
            // Item Row
            let itemName = "\(item.displayPlanName) Subscription"
            let itemDesc = "1 Month Access to SpeakIT Studio, AI Voice Synthesis & STT Services"
            
            let itemAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1.0)
            ]
            itemName.draw(at: CGPoint(x: margin + 12, y: currentY), withAttributes: itemAttributes)
            
            let descAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1.0)
            ]
            itemDesc.draw(at: CGPoint(x: margin + 12, y: currentY + 18), withAttributes: descAttributes)
            
            let periodText = "1 Month"
            let periodAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor(red: 71/255, green: 85/255, blue: 105/255, alpha: 1.0)
            ]
            periodText.draw(at: CGPoint(x: margin + contentWidth - 170, y: currentY + 6), withAttributes: periodAttributes)
            
            let amountText = item.formattedAmount
            let amountAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1.0)
            ]
            let amountSize = (amountText as NSString).size(withAttributes: amountAttributes)
            amountText.draw(at: CGPoint(x: margin + contentWidth - 12 - amountSize.width, y: currentY + 6), withAttributes: amountAttributes)
            
            currentY += 46
            
            // Table Bottom Line
            cgContext.setStrokeColor(UIColor(red: 226/255, green: 232/255, blue: 240/255, alpha: 1.0).cgColor)
            cgContext.setLineWidth(1.0)
            cgContext.move(to: CGPoint(x: margin, y: currentY))
            cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: currentY))
            cgContext.strokePath()
            
            currentY += 18
            
            // Summary Totals
            let totalsX = margin + contentWidth - 230
            drawSummaryRow(label: "Subtotal:", value: item.formattedAmount, at: CGPoint(x: totalsX, y: currentY), width: 230)
            currentY += 20
            drawSummaryRow(label: "Taxes & Fees:", value: "Included", at: CGPoint(x: totalsX, y: currentY), width: 230)
            currentY += 24
            
            // Total Card Box
            let totalBoxRect = CGRect(x: totalsX, y: currentY, width: 230, height: 40)
            cgContext.setFillColor(UIColor(red: 243/255, green: 244/255, blue: 246/255, alpha: 1.0).cgColor)
            let totalPath = UIBezierPath(roundedRect: totalBoxRect, cornerRadius: 8)
            cgContext.addPath(totalPath.cgPath)
            cgContext.fillPath()
            
            let totalLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .bold),
                .foregroundColor: UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1.0)
            ]
            "Total Amount Paid:".draw(at: CGPoint(x: totalsX + 12, y: currentY + 11), withAttributes: totalLabelAttributes)
            
            let totalValAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .heavy),
                .foregroundColor: brandColor
            ]
            let totalValSize = (item.formattedAmount as NSString).size(withAttributes: totalValAttributes)
            item.formattedAmount.draw(at: CGPoint(x: totalsX + 230 - 12 - totalValSize.width, y: currentY + 9), withAttributes: totalValAttributes)
            
            currentY += 72
            
            // --- 4. Verified Paid Seal ---
            let sealRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 44)
            cgContext.setFillColor(UIColor(red: 236/255, green: 253/255, blue: 245/255, alpha: 1.0).cgColor)
            cgContext.setStrokeColor(UIColor(red: 167/255, green: 243/255, blue: 208/255, alpha: 1.0).cgColor)
            cgContext.setLineWidth(1.0)
            let sealPath = UIBezierPath(roundedRect: sealRect, cornerRadius: 8)
            cgContext.addPath(sealPath.cgPath)
            cgContext.fillPath()
            cgContext.addPath(sealPath.cgPath)
            cgContext.strokePath()
            
            let sealText = "✓  PAYMENT VERIFIED & PROCESSED BY SPEAKIT GATEWAY"
            let sealAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: UIColor(red: 5/255, green: 150/255, blue: 105/255, alpha: 1.0)
            ]
            let sealSize = (sealText as NSString).size(withAttributes: sealAttributes)
            sealText.draw(at: CGPoint(x: margin + (contentWidth - sealSize.width) / 2, y: currentY + 16), withAttributes: sealAttributes)
            
            // --- 5. Footer ---
            let footerY = pageHeight - margin - 32
            let footerText = "Thank you for using SpeakIT AI Voice Studio. This electronic receipt serves as official proof of purchase."
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .regular),
                .foregroundColor: UIColor(red: 148/255, green: 163/255, blue: 184/255, alpha: 1.0)
            ]
            let footerSize = (footerText as NSString).size(withAttributes: footerAttributes)
            footerText.draw(at: CGPoint(x: margin + (contentWidth - footerSize.width) / 2, y: footerY), withAttributes: footerAttributes)
            
            let contactText = "Questions or billing support: support@mohitur.com  •  https://speakit.mohitur.com"
            let contactAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .semibold),
                .foregroundColor: UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1.0)
            ]
            let contactSize = (contactText as NSString).size(withAttributes: contactAttributes)
            contactText.draw(at: CGPoint(x: margin + (contentWidth - contactSize.width) / 2, y: footerY + 14), withAttributes: contactAttributes)
        }
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpeakIT_Receipt_\(item.receiptNumber).pdf")
        
        do {
            try data.write(to: outputURL)
            return outputURL
        } catch {
            print("Failed to write PDF receipt: \(error)")
            return nil
        }
    }
    
    // MARK: - Private Drawing Helpers
    
    private static func drawSectionHeader(_ title: String, at point: CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1.0)
        ]
        title.draw(at: point, withAttributes: attributes)
    }
    
    private static func drawMetaField(
        label: String,
        value: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        valueColor: UIColor? = nil
    ) {
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1.0)
        ]
        label.draw(at: CGPoint(x: x, y: y), withAttributes: labelAttributes)
        
        let valAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: valueColor ?? UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1.0)
        ]
        value.draw(at: CGPoint(x: x, y: y + 14), withAttributes: valAttributes)
    }
    
    private static func drawSummaryRow(
        label: String,
        value: String,
        at point: CGPoint,
        width: CGFloat
    ) {
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1.0)
        ]
        label.draw(at: point, withAttributes: labelAttributes)
        
        let valAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor(red: 30/255, green: 41/255, blue: 59/255, alpha: 1.0)
        ]
        let valSize = (value as NSString).size(withAttributes: valAttributes)
        value.draw(at: CGPoint(x: point.x + width - valSize.width, y: point.y), withAttributes: valAttributes)
    }
}
