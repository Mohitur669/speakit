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

struct ProrationQuoteResponse: Codable {
    let currentPlan: String
    let targetPlan: String
    let currentPlanPrice: Double
    let targetPlanPrice: Double
    let remainingDays: Int
    let totalDays: Int
    let unusedCredit: Double
    let amountToPay: Double
    let currency: String
    let isUpgrade: Bool
    let description: String
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
    
    enum CodingKeys: String, CodingKey {
        case id, planName, amount, currency, status, razorpayOrderId, createdAt
        case paymentProvider, paymentMethod, transactionId, invoiceNote
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        planName = try container.decode(String.self, forKey: .planName)
        amount = try container.decode(Double.self, forKey: .amount)
        currency = try container.decode(String.self, forKey: .currency)
        status = try container.decode(String.self, forKey: .status)
        razorpayOrderId = try container.decodeIfPresent(String.self, forKey: .razorpayOrderId)
        paymentProvider = try container.decodeIfPresent(String.self, forKey: .paymentProvider)
        paymentMethod = try container.decodeIfPresent(String.self, forKey: .paymentMethod)
        transactionId = try container.decodeIfPresent(String.self, forKey: .transactionId)
        invoiceNote = try container.decodeIfPresent(String.self, forKey: .invoiceNote)
        
        if let str = try? container.decodeIfPresent(String.self, forKey: .createdAt) {
            createdAt = str
        } else if let arr = try? container.decodeIfPresent([Int].self, forKey: .createdAt), arr.count >= 3 {
            let y = arr[0]
            let m = arr[1]
            let d = arr[2]
            let h = arr.count > 3 ? arr[3] : 0
            let min = arr.count > 4 ? arr[4] : 0
            let sec = arr.count > 5 ? arr[5] : 0
            createdAt = String(format: "%04d-%02d-%02dT%02d:%02d:%02d", y, m, d, h, min, sec)
        } else {
            createdAt = nil
        }
    }
    
    var isAppleStoreKit: Bool {
        (paymentProvider?.uppercased() == "APPLE_STOREKIT") ||
        (razorpayOrderId?.hasPrefix("apple_") == true)
    }
    
    var isDowngrade: Bool {
        paymentMethod?.localizedCaseInsensitiveContains("Downgrade") == true ||
        razorpayOrderId?.hasPrefix("dwn_") == true
    }
    
    var isCancellation: Bool {
        paymentMethod?.localizedCaseInsensitiveContains("Cancellation") == true ||
        razorpayOrderId?.hasPrefix("cancel_") == true
    }
    
    var isUpgrade: Bool {
        invoiceNote?.localizedCaseInsensitiveContains("Upgrade") == true
    }
    
    var displayPaymentMethod: String {
        if isCancellation {
            return "Subscription Cancellation"
        }
        if isDowngrade {
            return "Plan Downgrade"
        }
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
        if isCancellation {
            return "CAN-\(String(format: "%06d", id))"
        }
        if isDowngrade {
            return "DWN-\(String(format: "%06d", id))"
        }
        return "REC-\(String(format: "%06d", id))"
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
        if isCancellation { return "Auto-Renewal Cancelled" }
        if isDowngrade { return "Plan Downgraded" }
        if isUpgrade { return "Plan Upgraded" }
        if isSuccess { return "Payment Successful" }
        if isPending { return "Payment Pending" }
        if isFailed { return "Payment Failed" }
        if isRefunded { return "Payment Refunded" }
        return "Payment \(status.capitalized)"
    }
    
    var statusDescription: String {
        if isCancellation { return "Cancelled on \(formattedDate) • Active until period end" }
        if isDowngrade { return "Downgraded on \(formattedDate)" }
        if isUpgrade { return "Upgraded on \(formattedDate) • Credit applied" }
        if isSuccess { return "Paid on \(formattedDate)" }
        if isPending { return "Pending confirmation • Initiated on \(formattedDate)" }
        if isFailed { return "Failed on \(formattedDate) • Not charged" }
        if isRefunded { return "Refunded on \(formattedDate)" }
        return "\(status.capitalized) on \(formattedDate)"
    }
    
    var formattedAmount: String {
        if isCancellation || (isDowngrade && amount == 0) {
            return "₹0"
        }
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
