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
