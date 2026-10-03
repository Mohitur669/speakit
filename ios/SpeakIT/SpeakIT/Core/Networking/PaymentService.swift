//
//  PaymentService.swift
//  SpeakIT
//
//  Service handling backend payment creation, verification, subscription lifecycle, and billing history.
//

import Foundation

final class PaymentService {
    static let shared = PaymentService()
    private let client = HTTPClient.shared
    
    private init() {}
    
    // MARK: - Create Order
    func createOrder(plan: PlanType, amount: Double, currency: String = "INR") async throws -> PaymentOrderResponse {
        let req = PaymentOrderRequest(
            planType: plan.rawValue.uppercased(),
            amount: amount,
            currency: currency
        )
        let body = try JSONEncoder().encode(req)
        return try await client.request(.createPaymentOrder, method: "POST", body: body)
    }
    
    // MARK: - Verify Payment
    func verifyPayment(
        orderId: String?,
        subscriptionId: String,
        paymentId: String,
        signature: String
    ) async throws -> String {
        let req = PaymentVerificationRequest(
            razorpayOrderId: orderId,
            razorpaySubscriptionId: subscriptionId,
            razorpayPaymentId: paymentId,
            razorpaySignature: signature
        )
        let body = try JSONEncoder().encode(req)
        return try await client.requestString(.verifyPayment, method: "POST", body: body)
    }
    
    // MARK: - Proration Quotation
    func getProrationQuote(targetPlan: PlanType, currency: String = "INR") async throws -> ProrationQuoteResponse {
        return try await client.request(
            .prorationQuote(targetPlan: targetPlan.rawValue.uppercased(), currency: currency),
            method: "GET"
        )
    }
    
    // MARK: - Downgrade Plan
    func downgrade(to targetPlan: PlanType) async throws -> String {
        if targetPlan == .free {
            return try await downgradeToFree()
        }
        return try await client.requestString(
            .downgradePlan(targetPlan: targetPlan.rawValue.uppercased()),
            method: "POST"
        )
    }
    
    // MARK: - Downgrade to Free
    func downgradeToFree() async throws -> String {
        return try await client.requestString(.downgradeToFree, method: "POST")
    }
    
    // MARK: - Cancel Subscription
    func cancelSubscription() async throws -> String {
        return try await client.requestString(.cancelSubscription, method: "POST")
    }
    
    // MARK: - Payment History
    func getPaymentHistory(page: Int = 0, size: Int = 20) async throws -> [PaymentHistoryItem] {
        let response: PaginatedPaymentHistory = try await client.request(.paymentHistory(page: page, size: size))
        return response.content
    }
}
