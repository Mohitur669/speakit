//
//  User.swift
//  SpeakIT
//
//  User domain model matching Spring Boot UserResponse / AuthResponse DTO.
//

import Foundation

struct User: Codable, Identifiable {
    let id: Int64
    let username: String
    let email: String
    let fullName: String
    let role: String?
    let planType: PlanType
    let status: String?
    let subscriptionStatus: String?
    let planExpiry: Date?
    let characterLimit: Int
    let charactersUsed: Int
    let phoneNumber: String?
    let dailyCount: Int
    let dailyLimit: Int
    let emailVerified: Bool
    
    init(
        id: Int64 = 1,
        username: String,
        email: String,
        fullName: String? = nil,
        role: String? = "ROLE_USER",
        planType: PlanType = .free,
        status: String? = "ACTIVE",
        subscriptionStatus: String? = "ACTIVE",
        planExpiry: Date? = nil,
        characterLimit: Int? = nil,
        charactersUsed: Int = 0,
        phoneNumber: String? = nil,
        dailyCount: Int = 0,
        dailyLimit: Int = 20,
        emailVerified: Bool = true
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.fullName = fullName ?? username.capitalized
        self.role = role
        self.planType = planType
        self.status = status
        self.subscriptionStatus = subscriptionStatus
        self.planExpiry = planExpiry
        self.characterLimit = characterLimit ?? planType.monthlyQuota
        self.charactersUsed = charactersUsed
        self.phoneNumber = phoneNumber
        self.dailyCount = dailyCount
        self.dailyLimit = dailyLimit
        self.emailVerified = emailVerified
    }
    
    enum CodingKeys: String, CodingKey {
        case id, username, email, fullName, role, planType, status, subscriptionStatus, planExpiry, characterLimit, charactersUsed
        case phoneNumber, dailyCount, dailyLimit, emailVerified
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(Int64.self, forKey: .id)) ?? 1
        let uname = (try? container.decode(String.self, forKey: .username)) ?? "user"
        self.username = uname
        self.email = (try? container.decode(String.self, forKey: .email)) ?? ""
        self.fullName = (try? container.decode(String.self, forKey: .fullName)) ?? uname.capitalized
        self.role = try? container.decode(String.self, forKey: .role)
        
        if let rawPlan = try? container.decode(PlanType.self, forKey: .planType) {
            self.planType = rawPlan
        } else if let planStr = try? container.decode(String.self, forKey: .planType),
                  let resolvedPlan = PlanType(rawValue: planStr.uppercased()) {
            self.planType = resolvedPlan
        } else {
            self.planType = .free
        }
        
        self.status = (try? container.decode(String.self, forKey: .status)) ?? "ACTIVE"
        self.subscriptionStatus = try? container.decode(String.self, forKey: .subscriptionStatus)
        
        if let dateStr = try? container.decode(String.self, forKey: .planExpiry) {
            self.planExpiry = User.parseDate(dateStr)
        } else if let timestamp = try? container.decode(Double.self, forKey: .planExpiry) {
            self.planExpiry = Date(timeIntervalSince1970: timestamp > 10000000000 ? timestamp / 1000 : timestamp)
        } else {
            self.planExpiry = nil
        }
        
        let limit = try? container.decode(Int.self, forKey: .characterLimit)
        self.characterLimit = limit ?? self.planType.monthlyQuota
        self.charactersUsed = (try? container.decode(Int.self, forKey: .charactersUsed)) ?? 0
        self.phoneNumber = try? container.decode(String.self, forKey: .phoneNumber)
        self.dailyCount = (try? container.decode(Int.self, forKey: .dailyCount)) ?? 0
        self.dailyLimit = (try? container.decode(Int.self, forKey: .dailyLimit)) ?? 20
        self.emailVerified = (try? container.decode(Bool.self, forKey: .emailVerified)) ?? true
    }
    
    private static func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: dateString) { return d }
        formatter.formatOptions = [.withInternetDateTime]
        if let d = formatter.date(from: dateString) { return d }
        
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        if let d = df.date(from: dateString) { return d }
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = df.date(from: dateString) { return d }
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: dateString)
    }
    
    var formattedExpiry: String? {
        guard let planExpiry = planExpiry else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: planExpiry)
    }
    
    var daysRemaining: Int? {
        guard let planExpiry = planExpiry else { return nil }
        let diff = Calendar.current.dateComponents([.day], from: Date(), to: planExpiry).day ?? 0
        return max(0, diff)
    }
    
    var isSubscriptionActive: Bool {
        if planType == .free { return true }
        if let expiry = planExpiry, expiry < Date() {
            return false
        }
        return (subscriptionStatus ?? "ACTIVE").uppercased() == "ACTIVE"
    }
    
    var remainingCharacters: Int {
        max(0, characterLimit - charactersUsed)
    }
    
    var usagePercentage: Double {
        guard characterLimit > 0 else { return 0 }
        return min(1.0, Double(charactersUsed) / Double(characterLimit))
    }
    
    var initials: String {
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "U"
        }
        let parts = trimmed.split(separator: " ")
        if parts.count >= 2 {
            let first = parts[0].prefix(1)
            let second = parts[1].prefix(1)
            return "\(first)\(second)".uppercased()
        }
        return String(trimmed.prefix(1)).uppercased()
    }
    
    // Sample mockup user for previews & offline
    static var sample: User {
        User(
            id: 1,
            username: "mohit",
            email: "mohit@example.com",
            fullName: "Mohit Sharma",
            role: "ROLE_USER",
            planType: .pro,
            status: "ACTIVE",
            characterLimit: 25000,
            charactersUsed: 14250
        )
    }
}
