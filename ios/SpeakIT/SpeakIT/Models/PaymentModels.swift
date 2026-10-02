//
//  PaymentModels.swift
//  SpeakIT
//
//  Payment and Subscription DTOs matching backend PaymentController and RazorpayService.
//

import Foundation

struct PaymentOrderRequest: Codable {
    let planType: String
    let amount: Double
    let currency: String
}

struct PaymentOrderResponse: Codable, Identifiable {
    var id: String { subscriptionId }
    let orderId: String?
    let subscriptionId: String
    let currency: String
    let amount: Int // in paise (e.g. 49900 = ₹499.00)
    let keyId: String?
}

struct PaymentVerificationRequest: Codable {
    let razorpayOrderId: String?
    let razorpaySubscriptionId: String
    let razorpayPaymentId: String
    let razorpaySignature: String
}

struct PaymentHistoryItem: Codable, Identifiable {
    let id: Int64
    let planName: String
    let amount: Double
    let currency: String
    let status: String
    let razorpayOrderId: String?
    let createdAt: String?
    let paymentProvider: String?
    let paymentMethod: String?
    let transactionId: String?
    let invoiceNote: String?
    
    var isAppleStoreKit: Bool {
        (paymentProvider?.uppercased() == "APPLE_STOREKIT") ||
        (razorpayOrderId?.hasPrefix("apple_") == true)
    }
    
    var displayPaymentMethod: String {
        if isAppleStoreKit {
            return "In-App Purchase (Apple ID)"
        }
        return paymentMethod ?? "Secure Payment Gateway"
    }
    
    var displayTransactionId: String {
        if let tx = transactionId, !tx.isEmpty {
            return tx
        }
        if let order = razorpayOrderId {
            return order.replacingOccurrences(of: "apple_", with: "")
        }
        return "N/A"
    }
    
    var displayPlanName: String {
        switch planName.uppercased() {
        case "PRO":
            return "Pro"
        case "PRO_PLUS", "PRO PLUS", "PROPLUS":
            return "Pro Plus"
        case "FREE":
            return "Free"
        case "ENTERPRISE":
            return "Enterprise"
        default:
            return planName
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }
    
    var receiptNumber: String {
        "REC-\(String(format: "%06d", id))"
    }
    
    var isSuccess: Bool {
        status.uppercased() == "SUCCESS"
    }
    
    var isPending: Bool {
        status.uppercased() == "PENDING"
    }
    
    var isFailed: Bool {
        status.uppercased() == "FAILED"
    }
    
    var isRefunded: Bool {
        status.uppercased() == "REFUNDED"
    }
    
    var statusTitle: String {
        if isSuccess { return "Payment Successful" }
        if isPending { return "Payment Pending" }
        if isFailed { return "Payment Failed" }
        if isRefunded { return "Payment Refunded" }
        return "Payment \(status.capitalized)"
    }
    
    var statusDescription: String {
        if isSuccess { return "Paid on \(formattedDate)" }
        if isPending { return "Pending confirmation • Initiated on \(formattedDate)" }
        if isFailed { return "Failed on \(formattedDate) • Not charged" }
        if isRefunded { return "Refunded on \(formattedDate)" }
        return "\(status.capitalized) on \(formattedDate)"
    }
    
    var formattedAmount: String {
        if currency.uppercased() == "INR" {
            return "₹\(Int(amount))"
        }
        return "\(currency) \(String(format: "%.2f", amount))"
    }
    
    var formattedDate: String {
        guard let createdAt = createdAt else { return "N/A" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: createdAt) {
            let out = DateFormatter()
            out.dateStyle = .medium
            out.timeStyle = .short
            return out.string(from: d)
        }
        let fallback = DateFormatter()
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = fallback.date(from: createdAt) {
            let out = DateFormatter()
            out.dateStyle = .medium
            out.timeStyle = .short
            return out.string(from: d)
        }
        return String(createdAt.prefix(10))
    }
}

struct PaginatedPaymentHistory: Codable {
    let content: [PaymentHistoryItem]
}
