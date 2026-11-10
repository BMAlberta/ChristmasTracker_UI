//
//  Child.swift
//  ChristmasTracker
//
//  Domain model of a child the user manages. Built from the generated child shapes at the
//  repository boundary (see mapChild). Names are personal data and must never be logged.
//

import Foundation

nonisolated enum ChildRelationship: String, Equatable, Sendable, CaseIterable {
    case parent = "PARENT"
    case guardian = "GUARDIAN"
    case caretaker = "CARETAKER"

    var title: String {
        switch self {
        case .parent: return "Parent"
        case .guardian: return "Guardian"
        case .caretaker: return "Caretaker"
        }
    }
}

nonisolated struct Child: Identifiable, Equatable, Sendable {
    let id: String
    let firstName: String
    let lastName: String
    let displayName: String?
    let relationship: ChildRelationship

    /// The display name when it is not blank, otherwise first and last name.
    var shownName: String {
        if let displayName, !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return displayName
        }
        return "\(firstName) \(lastName)"
    }
}

/// What the app sends to create a child. The repository builds the wire body.
nonisolated struct CreateChildInput: Equatable, Sendable {
    let firstName: String
    let lastName: String
    let displayName: String?
    let relationship: ChildRelationship
}
