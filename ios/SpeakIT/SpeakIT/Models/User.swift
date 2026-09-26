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
    let characterLimit: Int
    let charactersUsed: Int
    
    init(
        id: Int64 = 1,
        username: String,
        email: String,
        fullName: String? = nil,
        role: String? = "ROLE_USER",
        planType: PlanType = .free,
        status: String? = "ACTIVE",
        characterLimit: Int? = nil,
        charactersUsed: Int = 0
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.fullName = fullName ?? username.capitalized
        self.role = role
        self.planType = planType
        self.status = status
        self.characterLimit = characterLimit ?? planType.monthlyQuota
        self.charactersUsed = charactersUsed
    }
    
    enum CodingKeys: String, CodingKey {
        case id, username, email, fullName, role, planType, status, characterLimit, charactersUsed
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
        let limit = try? container.decode(Int.self, forKey: .characterLimit)
        self.characterLimit = limit ?? self.planType.monthlyQuota
        self.charactersUsed = (try? container.decode(Int.self, forKey: .charactersUsed)) ?? 0
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
