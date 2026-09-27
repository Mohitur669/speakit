//
//  AvatarResponse.swift
//  SpeakIT
//
//  Minimal response model for avatar upload and deletion endpoints.
//

import Foundation

public struct AvatarResponse: Codable {
    public let avatarUrl: String?
    public let storageKey: String?
    public let action: String?
    public let dailyLimit: Int
    public let remainingChangesToday: Int
    public let updatedAt: String?
    
    public init(
        avatarUrl: String? = nil,
        storageKey: String? = nil,
        action: String? = nil,
        dailyLimit: Int = 2,
        remainingChangesToday: Int = 2,
        updatedAt: String? = nil
    ) {
        self.avatarUrl = avatarUrl
        self.storageKey = storageKey
        self.action = action
        self.dailyLimit = dailyLimit
        self.remainingChangesToday = remainingChangesToday
        self.updatedAt = updatedAt
    }
}
