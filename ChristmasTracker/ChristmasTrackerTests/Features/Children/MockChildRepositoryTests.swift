//
//  MockChildRepositoryTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M2: the pinned behaviors of MockChildRepository and of MockListRepository.createList
//  for a child recipient (the two share ONE MockListRepository instance).
//
//  Tommy's id is not pinned by the addendum, so the tests find him by his display name
//  "Tommy D." and find his list by the recipient id, never by a literal id.
//
//  Delay: only MockListRepository exposes `delay` (set to 0 through its test helper). See the
//  report about a delay on the child mock itself.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("MockChildRepository", .timeLimit(.minutes(1)))
struct MockChildRepositoryTests {

    private struct SUT {
        let lists: MockListRepository
        let children: MockChildRepository
    }

    private func makeSUT() async -> SUT {
        let lists = MockListRepository(withMockData: true, includeAllScenarios: false)
        await lists.setDelay(0)
        return SUT(lists: lists, children: MockChildRepository(listRepository: lists))
    }

    private func tommy(_ sut: SUT) async throws -> Child {
        let all = try await sut.children.fetchChildren()
        return try #require(all.first(where: { $0.displayName == "Tommy D." }))
    }

    private let newInput = CreateChildInput(firstName: "Eli", lastName: "Example", displayName: nil, relationship: .caretaker)

    // MARK: - Seed

    @Test("the mock starts with exactly one child, Tommy D.")
    func seedIsTommy() async throws {
        let sut = await makeSUT()

        let all = try await sut.children.fetchChildren()

        #expect(all.count == 1)
        #expect(all.first?.displayName == "Tommy D.")
    }

    @Test("Tommy has a list in the shared list repository (a list whose recipient id is his id)")
    func tommyHasAList() async throws {
        let sut = await makeSUT()
        let child = try await tommy(sut)

        let lists = try await sut.lists.fetchLists()

        #expect(lists.contains(where: { $0.recipient.id == child.id }))
    }

    // MARK: - createChild

    @Test("createChild adds a child with a deterministic new id, kept by fetchChildren")
    func createAddsChild() async throws {
        let sut = await makeSUT()

        let created = try await sut.children.createChild(newInput)

        #expect(created.firstName == "Eli")
        #expect(created.lastName == "Example")
        #expect(created.displayName == nil)
        #expect(created.relationship == .caretaker)
        let all = try await sut.children.fetchChildren()
        #expect(all.count == 2)
        #expect(all.contains(created))
    }

    @Test("createChild ids are deterministic across fresh mocks and distinct within one")
    func createIdsDeterministic() async throws {
        let first = await makeSUT()
        let second = await makeSUT()

        let a1 = try await first.children.createChild(newInput)
        let a2 = try await first.children.createChild(newInput)
        let b1 = try await second.children.createChild(newInput)

        #expect(a1.id == b1.id, "the same sequence gives the same id")
        #expect(a1.id != a2.id)
        #expect(a1.id.isEmpty == false)
    }

    // MARK: - deleteChild

    @Test("deleting a child that has a list throws childHasLists and keeps the child")
    func deleteChildWithListFails() async throws {
        let sut = await makeSUT()
        let child = try await tommy(sut)

        await #expect(throws: ChildError.childHasLists) {
            try await sut.children.deleteChild(id: child.id)
        }

        let all = try await sut.children.fetchChildren()
        #expect(all.contains(child))
    }

    @Test("deleting a new child (no list) removes it")
    func deleteNewChildSucceeds() async throws {
        let sut = await makeSUT()
        let created = try await sut.children.createChild(newInput)

        try await sut.children.deleteChild(id: created.id)

        let all = try await sut.children.fetchChildren()
        #expect(all.contains(created) == false)
        #expect(all.count == 1)
    }

    @Test("deleting an unknown child throws childNotFound")
    func deleteUnknownChild() async {
        let sut = await makeSUT()

        await #expect(throws: ChildError.childNotFound) {
            try await sut.children.deleteChild(id: "mock-child-missing")
        }
    }

    @Test("deleting the same child twice throws childNotFound the second time")
    func deleteTwice() async throws {
        let sut = await makeSUT()
        let created = try await sut.children.createChild(newInput)
        try await sut.children.deleteChild(id: created.id)

        await #expect(throws: ChildError.childNotFound) {
            try await sut.children.deleteChild(id: created.id)
        }
    }

    @Test("a child that gets a list through the shared list repository can no longer be deleted")
    func childWithNewListCannotBeDeleted() async throws {
        let sut = await makeSUT()
        let created = try await sut.children.createChild(newInput)
        _ = try await sut.lists.createList(
            CreateListInput(recipientId: created.id, year: 2031, name: "Eli's Wishes", theme: nil, visibility: .private)
        )

        await #expect(throws: ChildError.childHasLists) {
            try await sut.children.deleteChild(id: created.id)
        }
    }

    // MARK: - createList for a child recipient

    @Test("createList for the seed child is NOT blind for the creator: counts and gift activity are visible")
    func createListForSeedChildIsNotBlind() async throws {
        let sut = await makeSUT()
        let child = try await tommy(sut)

        let detail = try await sut.lists.createList(
            CreateListInput(recipientId: child.id, year: 2031, name: "Tommy's Wishes", theme: nil, visibility: .private)
        )

        #expect(detail.capabilities.isRecipient == false)
        #expect(detail.capabilities.canSeeGiftActivity)
        #expect(detail.itemCount != nil)
        #expect(detail.purchasedCount != nil)
        #expect(detail.recipient.id == child.id)
    }

    @Test("createList for a newly created child is NOT blind for the creator")
    func createListForNewChildIsNotBlind() async throws {
        let sut = await makeSUT()
        let created = try await sut.children.createChild(newInput)

        let detail = try await sut.lists.createList(
            CreateListInput(recipientId: created.id, year: 2031, name: "Eli's Wishes", theme: nil, visibility: .private)
        )

        #expect(detail.capabilities.canSeeGiftActivity)
        #expect(detail.capabilities.isRecipient == false)
        #expect(detail.itemCount != nil)
        #expect(detail.purchasedCount != nil)
        #expect(detail.recipient.id == created.id)
    }

    @Test("createList for the current user is still blind (counts absent)")
    func createListForSelfIsStillBlind() async throws {
        let sut = await makeSUT()

        let detail = try await sut.lists.createList(
            CreateListInput(recipientId: MockListData.currentUser.id, year: 2031, name: "Mine", theme: nil, visibility: .private)
        )

        #expect(detail.capabilities.isRecipient)
        #expect(detail.capabilities.canSeeGiftActivity == false)
        #expect(detail.itemCount == nil)
        #expect(detail.purchasedCount == nil)
    }
}
