//
//  MembersWire.swift
//  ChristmasTrackerTests
//
//  Story I3b-M2: shared wire support for the member, child and co-owner repository tests.
//
//  - `MembersWire`: literal, guide-accurate JSON (client guide 7.3, 7.4, 7.10) wrapped in the full
//    envelope with the full `meta` object, and the documented error bodies (error-codes.md).
//  - `WireHarness`: the REAL factory-built client over the recording `ListFakeTransport`.
//
//  All ids, names and addresses are fake (example.com). No real tokens.
//

import Foundation
import TrackerAPI
@testable import ChristmasTracker

nonisolated enum MembersWire {

    // MARK: Success bodies

    /// `data` text of one MemberSummary (client guide 7.3: status ACTIVE, no invitation).
    static func memberSummaryData(
        id: String = "mem-new",
        userId: String = "user-new",
        displayName: String = "Fran Friend",
        email: String? = "friend@example.com",
        role: String = "member",
        status: String = "ACTIVE"
    ) throws -> String {
        var object: [String: Any] = [
            "id": id,
            "userId": userId,
            "displayName": displayName,
            "role": role,
            "status": status,
            "invitedAt": "2026-11-02T00:00:00.000Z",
            "acceptedAt": "2026-11-02T00:00:00.000Z"
        ]
        if let email { object["email"] = email }
        return ListWire.text(try JSONSerialization.data(withJSONObject: object))
    }

    /// 201 body of POST /lists/{id}/members.
    static func addMemberJSON(role: String = "member", status: String = "ACTIVE", email: String? = "friend@example.com") throws -> String {
        ListWire.success(data: try memberSummaryData(email: email, role: role, status: status))
    }

    /// 200 body of DELETE /lists/{id}/members/{userId}: only a message.
    static let removeMemberJSON = ListWire.messageJSON("Member removed successfully")

    /// One child as the wire sends it. `displayName` nil is an explicit JSON null.
    static func childData(
        id: String,
        firstName: String,
        lastName: String,
        displayName: String?,
        relationshipType: String
    ) throws -> String {
        var object: [String: Any] = [
            "id": id,
            "firstName": firstName,
            "lastName": lastName,
            "relationshipType": relationshipType
        ]
        if let displayName {
            object["displayName"] = displayName
        } else {
            object["displayName"] = NSNull()
        }
        return ListWire.text(try JSONSerialization.data(withJSONObject: object))
    }

    /// 200 body of GET /users/me/children: two children, the second with a null displayName.
    static func childrenJSON(secondRelationship: String = "GUARDIAN") throws -> String {
        let first = try childData(id: "child-1", firstName: "Tommy", lastName: "Doe", displayName: "Tommy D.", relationshipType: "PARENT")
        let second = try childData(id: "child-2", firstName: "Dana", lastName: "Doe", displayName: nil, relationshipType: secondRelationship)
        return ListWire.success(data: "[\(first),\(second)]")
    }

    static let emptyChildrenJSON = ListWire.success(data: "[]")

    /// 201 body of POST /users/me/children (the relationship type is a plain string here).
    static func createChildJSON(
        displayName: String? = "Tommy D.",
        relationshipType: String = "PARENT"
    ) throws -> String {
        ListWire.success(data: try childData(
            id: "child-new", firstName: "Tommy", lastName: "Doe", displayName: displayName, relationshipType: relationshipType
        ))
    }

    /// 200 body of DELETE /users/me/children/{id} (client guide 7.10).
    static let deleteChildJSON = ListWire.messageJSON("Child deleted successfully")

    // MARK: Error bodies (error-codes.md)

    static let memberEmailNotFound = ListWire.errorJSON(code: 4009, errorCode: "MEMBER_EMAIL_NOT_FOUND", message: "Member email not found")
    static let membershipNotFound = ListWire.errorJSON(code: 4006, errorCode: "MEMBERSHIP_NOT_FOUND", message: "Membership not found")
    static let membershipAlreadyExists = ListWire.errorJSON(code: 5004, errorCode: "MEMBERSHIP_ALREADY_EXISTS", message: "Membership already exists")
    static let resourceNotFound = ListWire.errorJSON(code: 4001, errorCode: "RESOURCE_NOT_FOUND", message: "Resource not found")
    static let forbidden = ListWire.errorJSON(code: 2001, errorCode: "FORBIDDEN", message: "Access forbidden")
    static let cannotDeleteResource = ListWire.errorJSON(code: 6501, errorCode: "CANNOT_DELETE_RESOURCE", message: "Cannot delete resource")

    static func validation(_ message: String) -> String {
        ListWire.errorJSON(code: 3001, errorCode: "VALIDATION_ERROR", message: message)
    }
}

// MARK: - WireHarness

/// The real factory-built client over a recording fake transport, with the bearer token and the
/// four client headers configured exactly as the existing repository tests do.
struct WireHarness {
    static let accessToken = "tok-access-FAKE"

    let client: any APIProtocol
    let transport: ListFakeTransport
    let refresher: ListFakeRefresher

    static func make(token: String? = accessToken, refreshFailure: (any Error)? = nil) throws -> WireHarness {
        guard let baseURL = URL(string: "https://api.example.com") else {
            throw URLError(.badURL)
        }
        let transport = ListFakeTransport()
        let refresher = ListFakeRefresher(failure: refreshFailure)
        let client = try TrackerClientFactory.make(
            serverURL: baseURL,
            info: AppClientInfo(platform: "ios", clientPlatform: "ios", build: "1", version: "1.0.0"),
            tokenProvider: ListFakeTokenProvider(token: token),
            sessionRefresher: refresher,
            versionOutdatedHandler: ListFakeVersionHandler(),
            transport: transport
        )
        return WireHarness(client: client, transport: transport, refresher: refresher)
    }
}
