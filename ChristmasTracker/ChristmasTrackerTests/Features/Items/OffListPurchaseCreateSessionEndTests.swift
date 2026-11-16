//
//  OffListPurchaseCreateSessionEndTests.swift
//  ChristmasTrackerTests
//
//  Story OL1-O2 (decision 9): a session end while the create is in flight applies nothing and shows
//  nothing. The Add flow's step is driven as AddItemView drives it: beginCreate, then createFailed
//  when createItem throws.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Off-list purchase create session end Tests", .timeLimit(.minutes(1)))
@MainActor
struct OffListPurchaseCreateSessionEndTests {

    private func makeSUT() async -> ItemServiceSUT {
        await makeItemServiceSUT()
    }

    @Test("clearForSession during the create: CancellationError, nothing published or cached, no error")
    func clearDuringCreate() async throws {
        let sut = await makeSUT()
        sut.repo.enqueueCreateItem(.success(ItemServiceFix.item("item-new")), held: true)
        let task = startOutcome { _ = try await sut.service.createItem(listId: "list-1", ItemServiceFix.input()) }
        await sut.repo.gate.nextHeldCall()

        try await sut.service.clearForSession()
        sut.repo.gate.releaseAll()
        let error = await task.value

        #expect(error is CancellationError)
        #expect(!(error is ItemError))
        #expect(sut.service.items.isEmpty)
        #expect(sut.service.currentItem == nil)
        #expect(sut.service.listLoadError == nil)
        #expect(sut.service.detailLoadError == nil)
        #expect(sut.service.goneItemId == nil)
        #expect(sut.service.isMutating == false)
        let cached = await sut.store.getItems(listId: "list-1")
        #expect(cached.isEmpty)
    }

    @Test("the step driven as the Add flow drives it ends idle after the cancelled create and allows a new create")
    func stepReturnsToIdleAfterCancelledCreate() async throws {
        let sut = await makeSUT()
        sut.repo.enqueueCreateItem(.success(ItemServiceFix.item("item-new")), held: true)
        var step = OffListPurchaseStep.idle
        #expect(step.beginCreate() == true)
        let task = startOutcome { _ = try await sut.service.createItem(listId: "list-1", ItemServiceFix.input()) }
        await sut.repo.gate.nextHeldCall()

        try await sut.service.clearForSession()
        sut.repo.gate.releaseAll()
        let error = await task.value
        if error != nil { step.createFailed() }

        #expect(error is CancellationError)
        #expect(step == .idle)
        #expect(step.pendingItem == nil)
        #expect(step.allowsCreate == true)
        #expect(step.beginCreate() == true)
        #expect(step == .creating)
    }

    @Test("a failing create released after the session ended also throws CancellationError and sets no error",
          arguments: [ItemError.server, .network, .forbidden])
    func failingCreateAfterClear(failure: ItemError) async throws {
        let sut = await makeSUT()
        sut.repo.enqueueCreateItem(.failure(failure), held: true)
        let task = startOutcome { _ = try await sut.service.createItem(listId: "list-1", ItemServiceFix.input()) }
        await sut.repo.gate.nextHeldCall()

        try await sut.service.clearForSession()
        sut.repo.gate.releaseAll()
        let error = await task.value

        #expect(error is CancellationError)
        #expect(sut.service.items.isEmpty)
        #expect(sut.service.listLoadError == nil)
        #expect(sut.service.detailLoadError == nil)
    }
}
