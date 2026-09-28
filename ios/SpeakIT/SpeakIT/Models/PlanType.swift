//
//  PlanType.swift
//  SpeakIT
//
//  Subscription tiers matching backend PlanType enum.
//

import SwiftUI

enum PlanType: String, Codable, CaseIterable, Comparable {
    case free = "FREE"
    case pro = "PRO"
    case proPlus = "PRO_PLUS"
    case enterprise = "ENTERPRISE"
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .proPlus: return "Pro Plus"
        case .enterprise: return "Enterprise"
        }
    }
    
    var characterLimitPerRequest: Int {
        switch self {
        case .free: return 100
        case .pro: return 200
        case .proPlus: return 500
        case .enterprise: return 2000
        }
    }
    
    var monthlyQuota: Int {
        switch self {
        case .free: return 3000
        case .pro: return 5000
        case .proPlus: return 10000
        case .enterprise: return 1000000
        }
    }
    
    var allowsLiveSTT: Bool {
        self >= .proPlus
    }
    
    var allowsFileSTT: Bool {
        self >= .pro
    }
    
    private var sortOrder: Int {
        switch self {
        case .free: return 0
        case .pro: return 1
        case .proPlus: return 2
        case .enterprise: return 3
        }
    }
    
    static func < (lhs: PlanType, rhs: PlanType) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}
