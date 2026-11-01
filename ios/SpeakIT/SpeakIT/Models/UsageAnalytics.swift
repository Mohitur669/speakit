//
//  UsageAnalytics.swift
//  SpeakIT
//
//  Model representing single source of truth usage ledger metrics
//  and daily burn-rate for the user observability dashboard.
//

import Foundation

public struct UsageAnalytics: Codable {
    public let plan: String
    public let monthlyLimit: Int64
    public let charactersUsed: Int64
    public let charactersRemaining: Int64
    public let usagePercentage: Double
    public let burnRatePerDay: Double
    public let projectedDaysRemaining: Double
    public let daysRemainingInMonth: Int
    
    public static var sample: UsageAnalytics {
        UsageAnalytics(
            plan: "PRO",
            monthlyLimit: 50_000,
            charactersUsed: 12_400,
            charactersRemaining: 37_600,
            usagePercentage: 24.8,
            burnRatePerDay: 413.3,
            projectedDaysRemaining: 91.0,
            daysRemainingInMonth: 19
        )
    }
}
