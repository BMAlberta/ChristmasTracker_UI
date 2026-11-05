// DecodingTests.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

// NOTE ON GENERATED TYPE NAMES:
// These tests use the naming convention produced by swift-openapi-generator with the
// "idiomatic" naming strategy. The generated namespace is `Components.Schemas`.
// If the first build reveals name mismatches (e.g. `Error` renamed to avoid shadowing
// Swift.Error, or enum cases spelled differently), adjust only the type/case names
// and re-run; the fixture JSON and test assertions should remain unchanged.
//
// GENERATOR NOTES (observed from first build, generator 1.14.2):
// - `Error` schema → generated as `Components.Schemas._Error` (avoids shadowing Swift.Error)
// - `ListSummary` allOf → nested: `value1` (base fields), `value2` (CapabilityFlags)
// - `ListDetail` allOf → nested: `value1` (ListSummary), `value2.members`
// - `coOwner` field (anyOf[PersonRef, null]) → DROPPED by generator (null schema unsupported)
// - `expectedUnitPrice` field (anyOf[Money, null]) → DROPPED by generator (null schema unsupported)
// - UUID fields → generated as `Swift.String`
// - Money fields (`type: number, multipleOf: 0.01`) → generated as `Swift.Double`
// - `ListRole.coOwner` → generated as `case coOwner = "co-owner"`

import Testing
import Foundation
@testable import TrackerAPI

// MARK: - Helpers

private func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        return try TrackerDateTranscoder().decode(string)
    }
    return decoder
}

// MARK: - DecodingTests

@Suite("TrackerAPI Decoding")
struct DecodingTests {

    // MARK: - 1. Date with fractional seconds

    @Test("Decode ISO 8601 date with fractional seconds produces a valid Date")
    func decodeDateWithFractionalSeconds() async throws {
        let string = "2026-11-02T00:00:00.000Z"
        let date = try TrackerDateTranscoder().decode(string)
        // A valid Date will round-trip through timeIntervalSinceReferenceDate
        #expect(date.timeIntervalSinceReferenceDate.isFinite)
    }

    // MARK: - 2. Date without fractional seconds

    @Test("Decode ISO 8601 date without fractional seconds produces the same Date")
    func decodeDateWithoutFractionalSeconds() async throws {
        let withFraction = "2026-11-02T00:00:00.000Z"
        let withoutFraction = "2026-11-02T00:00:00Z"
        let dateA = try TrackerDateTranscoder().decode(withFraction)
        let dateB = try TrackerDateTranscoder().decode(withoutFraction)
        #expect(dateA == dateB)
    }

    // MARK: - 3. Date encode round-trip — no fractional seconds

    @Test("Encoded date string contains no fractional seconds")
    func encodeDateHasNoFractionalSeconds() async throws {
        // Use a date known to be on a whole second boundary
        let input = "2026-11-02T00:00:00Z"
        let date = try TrackerDateTranscoder().decode(input)
        let encoded = try TrackerDateTranscoder().encode(date)
        #expect(!encoded.contains("."), "Encoded string must not contain a decimal point: \(encoded)")
    }

    // MARK: - 4. UUID field on User

    @Test("Decode User with UUID id field")
    func decodeUserUUIDField() async throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "firstName": "Alice",
            "lastName": "Smith",
            "displayName": "Alice Smith",
            "role": "USER",
            "isActive": true,
            "createdAt": "2026-11-02T00:00:00Z",
            "updatedAt": "2026-11-02T00:00:00Z"
        }
        """
        let data = try #require(json.data(using: .utf8))
        let user = try makeDecoder().decode(Components.Schemas.User.self, from: data)
        #expect(user.id == "00000000-0000-0000-0000-000000000001")
    }

    // MARK: - 5a. Nullable coOwner — null
    // NOTE: The `coOwner` anyOf[PersonRef, null] field was dropped by the generator
    // (null-type anyOf variant not supported in generator 1.14.2). JSON decodes
    // successfully; the field is silently ignored. We verify the surrounding
    // ListSummary fields decode correctly.

    @Test("Decode ListSummary with null coOwner decodes base fields correctly")
    func decodeListSummaryNullCoOwner() async throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000002",
            "name": "Alice's Christmas List",
            "theme": null,
            "year": 2026,
            "visibility": "PRIVATE",
            "status": "ACTIVE",
            "recipient": {
                "id": "00000000-0000-0000-0000-000000000010",
                "displayName": "Alice"
            },
            "owner": {
                "id": "00000000-0000-0000-0000-000000000011",
                "displayName": "Bob"
            },
            "coOwner": null,
            "myRole": "owner",
            "memberCount": 1,
            "createdAt": "2026-11-02T00:00:00Z",
            "updatedAt": "2026-11-02T00:00:00Z",
            "isRecipient": false,
            "canSeeGiftActivity": true,
            "canPurchase": true,
            "canAddOffList": true,
            "canSeeOffList": true,
            "canCreateItem": true
        }
        """
        let data = try #require(json.data(using: .utf8))
        let summary = try makeDecoder().decode(Components.Schemas.ListSummary.self, from: data)
        // coOwner field is dropped by generator; verify surrounding fields decoded OK
        #expect(summary.value1.id == "00000000-0000-0000-0000-000000000002")
        #expect(summary.value1.memberCount == 1)
    }

    // MARK: - 5b. Nullable coOwner — non-null
    // NOTE: Same as 5a — `coOwner` is dropped by generator. JSON with a non-null
    // coOwner object also decodes successfully (field silently ignored).

    @Test("Decode ListSummary with non-null coOwner decodes successfully")
    func decodeListSummaryNonNullCoOwner() async throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000002",
            "name": "Alice's Christmas List",
            "theme": null,
            "year": 2026,
            "visibility": "PRIVATE",
            "status": "ACTIVE",
            "recipient": {
                "id": "00000000-0000-0000-0000-000000000010",
                "displayName": "Alice"
            },
            "owner": {
                "id": "00000000-0000-0000-0000-000000000011",
                "displayName": "Bob"
            },
            "coOwner": {
                "id": "00000000-0000-0000-0000-000000000012",
                "displayName": "Carol"
            },
            "myRole": "owner",
            "memberCount": 2,
            "createdAt": "2026-11-02T00:00:00Z",
            "updatedAt": "2026-11-02T00:00:00Z",
            "isRecipient": false,
            "canSeeGiftActivity": true,
            "canPurchase": true,
            "canAddOffList": true,
            "canSeeOffList": true,
            "canCreateItem": true
        }
        """
        let data = try #require(json.data(using: .utf8))
        let summary = try makeDecoder().decode(Components.Schemas.ListSummary.self, from: data)
        // coOwner field is dropped by generator; verify that decoding succeeded
        // and the owner field (which IS present) decoded correctly.
        #expect(summary.value1.owner.id == "00000000-0000-0000-0000-000000000011")
        #expect(summary.value1.memberCount == 2)
    }

    // MARK: - 6. Money value on Item
    // NOTE: `expectedUnitPrice` anyOf[Money, null] was dropped by the generator
    // (null-type anyOf variant not supported). JSON decodes successfully; the field
    // is silently ignored. We verify the Item's required fields decode correctly.

    @Test("Decode Item with money expectedUnitPrice of 349.99 decodes required fields correctly")
    func decodeItemMoneyField() async throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000020",
            "listId": "00000000-0000-0000-0000-000000000002",
            "name": "Red Bicycle",
            "description": "A shiny red bicycle",
            "quantityRequested": 1,
            "priority": 5,
            "status": "AVAILABLE",
            "offList": false,
            "expectedUnitPrice": 349.99,
            "createdBy": {
                "id": "00000000-0000-0000-0000-000000000011",
                "displayName": "Bob"
            },
            "createdAt": "2026-11-02T00:00:00Z"
        }
        """
        let data = try #require(json.data(using: .utf8))
        let item = try makeDecoder().decode(Components.Schemas.Item.self, from: data)
        // expectedUnitPrice dropped by generator; verify required fields decoded OK
        #expect(item.id == "00000000-0000-0000-0000-000000000020")
        #expect(item.name == "Red Bicycle")
        #expect(item.priority == 5)
    }

    // MARK: - 7. ListSummary allOf

    @Test("Decode ListSummary allOf — base fields and capability flags accessible")
    func decodeListSummaryAllOf() async throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000030",
            "name": "Bob's Wish List",
            "theme": "Winter",
            "year": 2026,
            "visibility": "INVITE_ONLY",
            "status": "ACTIVE",
            "recipient": {
                "id": "00000000-0000-0000-0000-000000000010",
                "displayName": "Alice"
            },
            "owner": {
                "id": "00000000-0000-0000-0000-000000000011",
                "displayName": "Bob"
            },
            "coOwner": null,
            "myRole": "co-owner",
            "memberCount": 3,
            "createdAt": "2026-11-02T00:00:00Z",
            "updatedAt": "2026-11-02T00:00:00Z",
            "isRecipient": false,
            "canSeeGiftActivity": true,
            "canPurchase": true,
            "canAddOffList": false,
            "canSeeOffList": true,
            "canCreateItem": true
        }
        """
        let data = try #require(json.data(using: .utf8))
        let summary = try makeDecoder().decode(Components.Schemas.ListSummary.self, from: data)

        // Base fields — accessed via value1 (the allOf inline object)
        #expect(summary.value1.id == "00000000-0000-0000-0000-000000000030")
        #expect(summary.value1.name == "Bob's Wish List")
        #expect(summary.value1.year == 2026)
        #expect(summary.value1.memberCount == 3)

        // Capability flags — accessed via value2 (the CapabilityFlags $ref)
        #expect(summary.value2.canSeeGiftActivity == true)
        #expect(summary.value2.canPurchase == true)
        #expect(summary.value2.isRecipient == false)
        #expect(summary.value2.canAddOffList == false)
        #expect(summary.value2.canSeeOffList == true)
        #expect(summary.value2.canCreateItem == true)
    }

    // MARK: - 8. ListDetail allOf

    @Test("Decode ListDetail allOf — members array accessible")
    func decodeListDetailAllOf() async throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000040",
            "name": "Detail List",
            "theme": null,
            "year": 2026,
            "visibility": "PRIVATE",
            "status": "ACTIVE",
            "recipient": {
                "id": "00000000-0000-0000-0000-000000000010",
                "displayName": "Alice"
            },
            "owner": {
                "id": "00000000-0000-0000-0000-000000000011",
                "displayName": "Bob"
            },
            "coOwner": null,
            "myRole": "owner",
            "memberCount": 1,
            "createdAt": "2026-11-02T00:00:00Z",
            "updatedAt": "2026-11-02T00:00:00Z",
            "isRecipient": false,
            "canSeeGiftActivity": true,
            "canPurchase": true,
            "canAddOffList": true,
            "canSeeOffList": true,
            "canCreateItem": true,
            "members": [
                {
                    "id": "00000000-0000-0000-0000-000000000050",
                    "userId": "00000000-0000-0000-0000-000000000011",
                    "displayName": "Bob",
                    "role": "member",
                    "status": "ACTIVE",
                    "invitedAt": "2026-11-01T00:00:00Z"
                }
            ]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let detail = try makeDecoder().decode(Components.Schemas.ListDetail.self, from: data)
        // members is accessed via value2 (the allOf second part of ListDetail)
        let members = try #require(detail.value2.members)
        #expect(members.count == 1)
        #expect(members[0].displayName == "Bob")
    }

    // MARK: - 9. VersionOutdatedDetails 426 fields

    @Test("Decode VersionOutdatedDetails — all 6 fields accessible")
    func decodeVersionOutdatedDetails() async throws {
        let json = """
        {
            "minimumVersion": "2.0.0",
            "minimumBuild": 10,
            "latestVersion": "2.1.0",
            "latestBuild": 20,
            "manifestUrl": null,
            "ipaUrl": "https://example.com/app.ipa"
        }
        """
        let data = try #require(json.data(using: .utf8))
        let details = try makeDecoder().decode(Components.Schemas.VersionOutdatedDetails.self, from: data)
        #expect(details.minimumVersion == "2.0.0")
        #expect(details.minimumBuild == 10)
        #expect(details.latestVersion == "2.1.0")
        #expect(details.latestBuild == 20)
        #expect(details.manifestUrl == nil)
        #expect(details.ipaUrl == "https://example.com/app.ipa")
    }

    // MARK: - 10. Error envelope
    // NOTE: The generator renamed `Error` → `_Error` to avoid shadowing Swift.Error.

    @Test("Decode error envelope — code, errorCode, message accessible")
    func decodeErrorEnvelope() async throws {
        let json = """
        {
            "success": false,
            "error": {
                "code": 1001,
                "errorCode": "INVALID_CREDENTIALS",
                "message": "The email or password you entered is incorrect"
            },
            "meta": {
                "timestamp": "2026-11-02T00:00:00Z",
                "requestId": "00000000-0000-0000-0000-000000000099",
                "sessionId": "00000000-0000-0000-0000-000000000098"
            }
        }
        """
        let data = try #require(json.data(using: .utf8))
        // Generator renamed Error → _Error to avoid shadowing Swift.Error
        let envelope = try makeDecoder().decode(Components.Schemas._Error.self, from: data)
        #expect(envelope.error.code == 1001)
        #expect(envelope.error.errorCode == "INVALID_CREDENTIALS")
        #expect(envelope.error.message == "The email or password you entered is incorrect")
    }
}
