//
//  GeneratedClientItemRepositoryClearBodyTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P3 (decision 17): an UpdateItemInput that clears url and imageUrl reaches the wire as
//  empty strings: {"url":"","imageUrl":""}. Not null, not omitted. A nil field stays omitted.
//
//  Covers GeneratedClientItemRepository.updateItem request mapping.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("GeneratedClientItemRepository clearing body", .timeLimit(.minutes(1)))
struct GeneratedClientItemRepositoryClearBodyTests {

    private func send(_ input: UpdateItemInput) async throws -> [String: Any] {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 200, json: ItemWire.itemEnvelope(ItemWire.itemJSON()))
        _ = try await sut.repo.updateItem(id: "item-1", input)
        let recorded = try #require(await sut.transport.lastRequest())
        return try #require(recorded.jsonObject)
    }

    @Test("url and imageUrl cleared send exactly {\"url\":\"\",\"imageUrl\":\"\"}")
    func clearBothSendsEmptyStrings() async throws {
        let body = try await send(UpdateItemInput(url: "", imageUrl: ""))

        #expect(Set(body.keys) == ["url", "imageUrl"])
        #expect(body["url"] as? String == "")
        #expect(body["imageUrl"] as? String == "")
        #expect(!(body["url"] is NSNull))
        #expect(!(body["imageUrl"] is NSNull))
    }

    @Test("clearing only imageUrl sends the empty string and omits url")
    func clearImageOnly() async throws {
        let body = try await send(UpdateItemInput(imageUrl: ""))

        #expect(Set(body.keys) == ["imageUrl"])
        #expect(body["imageUrl"] as? String == "")
    }

    @Test("clearing only url sends the empty string and omits imageUrl")
    func clearUrlOnly() async throws {
        let body = try await send(UpdateItemInput(url: ""))

        #expect(Set(body.keys) == ["url"])
        #expect(body["url"] as? String == "")
    }

    @Test("a clear next to a rename sends the empty string beside the name")
    func clearNextToRename() async throws {
        let body = try await send(UpdateItemInput(name: "Renamed", imageUrl: ""))

        #expect(Set(body.keys) == ["name", "imageUrl"])
        #expect(body["imageUrl"] as? String == "")
    }
}
