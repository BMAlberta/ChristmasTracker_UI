//
//  ChildMapping.swift
//  ChristmasTracker
//
//  Pure mapping of the generated child shapes to the domain Child. The generated child types are
//  inline and differ between the list and create responses, so the repository passes the plain
//  fields in. An unknown relationship gives nil: the repository reports an invalid response.
//

import Foundation

nonisolated func mapChild(
    id: String,
    firstName: String,
    lastName: String,
    displayName: String?,
    relationshipRaw: String
) -> Child? {
    guard let relationship = ChildRelationship(rawValue: relationshipRaw) else { return nil }
    return Child(
        id: id,
        firstName: firstName,
        lastName: lastName,
        displayName: displayName,
        relationship: relationship
    )
}
