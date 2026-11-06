//
//  User.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/8/26.
//

import Foundation

nonisolated struct User: Codable, Identifiable, Sendable {
    let id: String
    let email: String?
    let firstName: String
    let lastName: String
    let displayName: String
    let role: UserRole
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    let lastLoginAt: Date?

    /// Backward-compatibility computed property; prefer displayName for new code.
    nonisolated var name: String { displayName }
}

// MARK: - Backward-compat init (for pre-C1 code that constructs User with name:)
extension User {
    /// Convenience init that maps the legacy `name` parameter to firstName/lastName/displayName.
    /// Used only by existing test doubles and pre-C1 code that cannot be updated.
    init(
        id: String,
        email: String? = nil,
        name: String,
        role: UserRole,
        isActive: Bool = true,
        createdAt: Date,
        updatedAt: Date,
        lastLoginAt: Date? = nil
    ) {
        self.id = id
        self.email = email
        let parts = name.components(separatedBy: " ")
        self.firstName = parts.first ?? name
        self.lastName = parts.dropFirst().joined(separator: " ")
        self.displayName = name
        self.role = role
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastLoginAt = lastLoginAt
    }
}

nonisolated enum UserRole: String, Codable, Sendable {
    case user = "USER"
    case admin = "ADMIN"
    case viewer = "viewer"
    case member = "member"
    case owner = "owner"
    case blindViewer = "blind_viewer"
}
